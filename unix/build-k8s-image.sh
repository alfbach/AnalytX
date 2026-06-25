#!/usr/bin/env bash
# AnalytiX – Docker/Kubernetes image build
#
# Usage:
#   ./unix/build-k8s-image.sh
#   ./unix/build-k8s-image.sh -t ghcr.io/myorg/analytix:1.0.0 --push --update-kustomize
#   ./unix/build-k8s-image.sh --platform linux/amd64,linux/arm64 --push
#
# Environment (optional):
#   ANALYTX_IMAGE   default tag if -t not set (default: analytix:latest)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE="${ANALYTX_IMAGE:-analytix:latest}"
PUSH=false
UPDATE_KUST=false
PLATFORM=""
NO_CACHE=""
BUILDER="${CONTAINER_CLI}"

usage() {
  cat <<'EOF'
AnalytiX – build container image for Kubernetes

Options:
  -t, --tag IMAGE          Image name and tag (default: analytix:latest)
  --push                   Push image to registry after build
  --update-kustomize       Update k8s/kustomization.yaml (newName / newTag)
  --platform PLATFORMS     e.g. linux/amd64 or linux/amd64,linux/arm64 (uses buildx)
  --no-cache               Build without Docker layer cache
  -h, --help               Show this help

Examples:
  ./unix/build-k8s-image.sh
  ./unix/build-k8s-image.sh -t registry.example.com/analytix:v1 --push --update-kustomize
  ANALYTX_IMAGE=myrepo/analytix:dev ./unix/build-k8s-image.sh --push
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--tag)
      IMAGE="$2"
      shift 2
      ;;
    --push)
      PUSH=true
      shift
      ;;
    --update-kustomize)
      UPDATE_KUST=true
      shift
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --no-cache)
      NO_CACHE="--no-cache"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if command -v docker >/dev/null 2>&1; then
  CONTAINER_CLI=docker
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_CLI=podman
else
  echo "ERROR: docker or podman not found." >&2
  exit 1
fi

if [[ ! -f "${ROOT}/Dockerfile" ]]; then
  echo "ERROR: Dockerfile not found in ${ROOT}" >&2
  exit 1
fi

parse_image_ref() {
  local ref="$1"
  local repo tag
  if [[ "$ref" == *@* ]]; then
    echo "ERROR: digest references are not supported for --update-kustomize: ${ref}" >&2
    exit 1
  fi
  if [[ "$ref" == *":"* ]]; then
    repo="${ref%:*}"
    tag="${ref##*:}"
  else
    repo="$ref"
    tag="latest"
  fi
  printf '%s\n%s' "$repo" "$tag"
}

update_kustomization() {
  local ref="$1"
  local repo tag
  mapfile -t parts < <(parse_image_ref "$ref")
  repo="${parts[0]}"
  tag="${parts[1]}"
  local kust="${ROOT}/k8s/kustomization.yaml"
  if [[ ! -f "$kust" ]]; then
    echo "ERROR: ${kust} not found." >&2
    exit 1
  fi
  python3 - "$kust" "$repo" "$tag" <<'PY'
import re
import sys

path, repo, tag = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
text = re.sub(r"(\n    newName: ).*", rf"\1{repo}", text, count=1)
text = re.sub(r"(\n    newTag: ).*", rf"\1{tag}", text, count=1)
open(path, "w", encoding="utf-8").write(text)
PY
  echo "Updated k8s/kustomization.yaml → newName: ${repo}, newTag: ${tag}"
}

echo "AnalytiX – K8s image build"
echo "Project root: ${ROOT}"
echo "Image:        ${IMAGE}"
echo "Builder:      ${CONTAINER_CLI}"

if [[ -n "$PLATFORM" ]]; then
  if ! ${CONTAINER_CLI} buildx version >/dev/null 2>&1; then
    echo "ERROR: ${CONTAINER_CLI} buildx required for --platform" >&2
    exit 1
  fi
  BUILD_ARGS=(buildx build --platform "$PLATFORM" -f Dockerfile -t "$IMAGE" $NO_CACHE)
  if $PUSH; then
    BUILD_ARGS+=(--push)
  else
    BUILD_ARGS+=(--load)
  fi
  BUILD_ARGS+=(.)
  echo "Building (buildx) …"
  ${CONTAINER_CLI} "${BUILD_ARGS[@]}"
else
  BUILD_ARGS=(build -f Dockerfile -t "$IMAGE" $NO_CACHE .)
  echo "Building …"
  ${CONTAINER_CLI} "${BUILD_ARGS[@]}"
  if $PUSH; then
    echo "Pushing ${IMAGE} …"
    ${CONTAINER_CLI} push "$IMAGE"
  fi
fi

if $UPDATE_KUST; then
  update_kustomization "$IMAGE"
fi

echo ""
echo "Done."
echo "  Image: ${IMAGE}"
if ! $PUSH && [[ -z "$PLATFORM" || "$PLATFORM" != *","* ]]; then
  echo "  Test:  ${CONTAINER_CLI} run --rm -p 8765:8765 ${IMAGE}"
fi
echo "  Deploy: kubectl apply -k k8s/"
