# AnalytiX – Docker/Kubernetes image build (Windows)
# Usage:
#   powershell -ExecutionPolicy Bypass -File windows\build-k8s-image.ps1
#   powershell -ExecutionPolicy Bypass -File windows\build-k8s-image.ps1 -Tag ghcr.io/myorg/analytix:1.0.0 -Push -UpdateKustomize
param(
    [string]$Tag = $(if ($env:ANALYTX_IMAGE) { $env:ANALYTX_IMAGE } else { "analytix:latest" }),
    [switch]$Push,
    [switch]$UpdateKustomize,
    [string]$Platform = "",
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Show-Help {
    @"
AnalytiX – build container image for Kubernetes

Parameters:
  -Tag IMAGE              Image name and tag (default: analytix:latest)
  -Push                   Push image to registry after build
  -UpdateKustomize        Update k8s/kustomization.yaml (newName / newTag)
  -Platform PLATFORMS     e.g. linux/amd64 (uses docker buildx)
  -NoCache                Build without Docker layer cache

Examples:
  powershell -ExecutionPolicy Bypass -File windows\build-k8s-image.ps1
  powershell -ExecutionPolicy Bypass -File windows\build-k8s-image.ps1 -Tag registry.example.com/analytix:v1 -Push -UpdateKustomize
"@
}

if ($args -contains "-?" -or $args -contains "--help" -or $args -contains "-h") {
    Show-Help
    exit 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker not found. Install Docker Desktop or compatible CLI."
}

if (-not (Test-Path "$Root\Dockerfile")) {
    Write-Error "Dockerfile not found in $Root"
}

function Split-ImageRef([string]$Ref) {
    if ($Ref -match "@") {
        throw "Digest references are not supported for -UpdateKustomize: $Ref"
    }
    if ($Ref -match ":([^/]+)$") {
        $tag = $Matches[1]
        $repo = $Ref.Substring(0, $Ref.Length - $tag.Length - 1)
    } else {
        $repo = $Ref
        $tag = "latest"
    }
    return @{ Repo = $repo; Tag = $tag }
}

function Update-Kustomization([string]$Ref) {
    $parts = Split-ImageRef $Ref
    $kust = Join-Path $Root "k8s\kustomization.yaml"
    if (-not (Test-Path $kust)) {
        throw "k8s/kustomization.yaml not found"
    }
    $text = Get-Content $kust -Raw
    $text = $text -replace "(\r?\n    newName: ).*", "`${1}$($parts.Repo)", 1
    $text = $text -replace "(\r?\n    newTag: ).*", "`${1}$($parts.Tag)", 1
    Set-Content -Path $kust -Value $text -NoNewline
    Write-Host "Updated k8s/kustomization.yaml -> newName: $($parts.Repo), newTag: $($parts.Tag)"
}

Write-Host "AnalytiX – K8s image build"
Write-Host "Project root: $Root"
Write-Host "Image:        $Tag"

$buildArgs = @("build", "-f", "Dockerfile", "-t", $Tag)
if ($NoCache) { $buildArgs += "--no-cache" }

if ($Platform) {
    if (-not (docker buildx version 2>$null)) {
        throw "docker buildx required for -Platform"
    }
    $buildArgs = @("buildx", "build", "--platform", $Platform, "-f", "Dockerfile", "-t", $Tag)
    if ($NoCache) { $buildArgs += "--no-cache" }
    if ($Push) {
        $buildArgs += "--push"
    } else {
        $buildArgs += "--load"
    }
    $buildArgs += "."
    Write-Host "Building (buildx) …"
    & docker @buildArgs
} else {
    $buildArgs += "."
    Write-Host "Building …"
    & docker @buildArgs
    if ($Push) {
        Write-Host "Pushing $Tag …"
        docker push $Tag
    }
}

if ($UpdateKustomize) {
    Update-Kustomization $Tag
}

Write-Host ""
Write-Host "Done."
Write-Host "  Image: $Tag"
if (-not $Push) {
    Write-Host "  Test:  docker run --rm -p 8765:8765 $Tag"
}
Write-Host "  Deploy: kubectl apply -k k8s/"
