#!/usr/bin/env bash
# Wrapper: build AnalytiX K8s image (see unix/build-k8s-image.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${ROOT}/unix/build-k8s-image.sh" "$@"
