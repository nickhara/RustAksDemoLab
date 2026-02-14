<#
.SYNOPSIS
    Builds all Docker images for the message queue lab.

.DESCRIPTION
    Builds Docker images for Rust API, C# API, and C# Worker Service.
    Optionally tags and pushes to Azure Container Registry.

.PARAMETER AcrName
    Azure Container Registry name (optional, for pushing to ACR)

.PARAMETER PushToAcr
    Push images to ACR after building

.PARAMETER Version
    Image version tag (default: latest)

.EXAMPLE
    .\Build-All.ps1
    Build all images locally

.EXAMPLE
    .\Build-All.ps1 -AcrName "myacr" -PushToAcr -Version "v1.0"
    Build and push images to ACR with version tag
#>

param(
    [Parameter()]
    [string]$AcrName = "",
    
    [Parameter()]
    [switch]$PushToAcr,
    
    [Parameter()]
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build All Components" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$rootDir = Split-Path -Parent $PSScriptRoot

# Build Rust API
Write-Host "[1/3] Building Rust API..." -ForegroundColor Yellow
Push-Location "$rootDir\src\rust-api"
try {
    docker build -t hello-rust-api:$Version .
    Write-Host "✓ Rust API built successfully" -ForegroundColor Green
    
    if ($PushToAcr -and $AcrName) {
        Write-Host "  Tagging for ACR..." -ForegroundColor Gray
        docker tag hello-rust-api:$Version "$AcrName.azurecr.io/hello-rust-api:$Version"
    }
}
catch {
    Write-Host "✗ Failed to build Rust API: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host ""

# Build C# API
Write-Host "[2/3] Building C# API..." -ForegroundColor Yellow
Push-Location "$rootDir\src\csharp-api"
try {
    docker build -t hello-csharp-api:$Version .
    Write-Host "✓ C# API built successfully" -ForegroundColor Green
    
    if ($PushToAcr -and $AcrName) {
        Write-Host "  Tagging for ACR..." -ForegroundColor Gray
        docker tag hello-csharp-api:$Version "$AcrName.azurecr.io/hello-csharp-api:$Version"
    }
}
catch {
    Write-Host "✗ Failed to build C# API: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host ""

# Build Worker Service
Write-Host "[3/3] Building Worker Service..." -ForegroundColor Yellow
Push-Location "$rootDir\src\worker-service\WorkerService"
try {
    docker build -t worker-service:$Version .
    Write-Host "✓ Worker Service built successfully" -ForegroundColor Green
    
    if ($PushToAcr -and $AcrName) {
        Write-Host "  Tagging for ACR..." -ForegroundColor Gray
        docker tag worker-service:$Version "$AcrName.azurecr.io/worker-service:$Version"
    }
}
catch {
    Write-Host "✗ Failed to build Worker Service: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host ""

# Push to ACR if requested
if ($PushToAcr -and $AcrName) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Pushing to ACR: $AcrName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Logging into ACR..." -ForegroundColor Yellow
    az acr login --name $AcrName
    
    Write-Host ""
    Write-Host "Pushing Rust API..." -ForegroundColor Yellow
    docker push "$AcrName.azurecr.io/hello-rust-api:$Version"
    Write-Host "✓ Rust API pushed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Pushing C# API..." -ForegroundColor Yellow
    docker push "$AcrName.azurecr.io/hello-csharp-api:$Version"
    Write-Host "✓ C# API pushed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Pushing Worker Service..." -ForegroundColor Yellow
    docker push "$AcrName.azurecr.io/worker-service:$Version"
    Write-Host "✓ Worker Service pushed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Verifying images in ACR..." -ForegroundColor Yellow
    az acr repository list --name $AcrName -o table
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# List local images
docker images | Select-String -Pattern "hello-rust-api|hello-csharp-api|worker-service" | ForEach-Object { Write-Host $_ -ForegroundColor White }
Write-Host ""

if ($PushToAcr -and $AcrName) {
    Write-Host "✓ All images built and pushed to $AcrName.azurecr.io" -ForegroundColor Green
}
else {
    Write-Host "✓ All images built locally" -ForegroundColor Green
    Write-Host ""
    Write-Host "To push to ACR, run:" -ForegroundColor Yellow
    Write-Host "  .\Build-All.ps1 -AcrName <your-acr-name> -PushToAcr" -ForegroundColor Gray
}
