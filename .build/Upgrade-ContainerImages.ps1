<#
.SYNOPSIS
    Upgrades and pushes container images to Azure Container Registry with latest security patches.

.DESCRIPTION
    Builds selected container images with --pull --no-cache to ensure fresh base images
    and OS-level security patches, then tags and pushes to ACR.
    Use this script for routine security patching of container images.

.PARAMETER AcrName
    Azure Container Registry name (without .azurecr.io suffix)

.PARAMETER SubscriptionId
    Azure subscription ID. If provided, sets the active subscription context.

.PARAMETER Images
    Comma-separated list of images to upgrade: rust-api, csharp-api, worker-service, or all (default: all)

.PARAMETER Version
    Image version tag (default: latest)

.EXAMPLE
    .\Upgrade-ContainerImages.ps1 -AcrName "myacr" -Images "csharp-api"
    Upgrade and push only the C# API image

.EXAMPLE
    .\Upgrade-ContainerImages.ps1 -AcrName "myacr" -SubscriptionId "9af68032-..." -Images "all" -Version "v2.0"
    Upgrade all images with a specific version tag
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter()]
    [string]$SubscriptionId = "",

    [Parameter()]
    [string]$Images = "all",

    [Parameter()]
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Container Image Security Upgrade" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$rootDir = Split-Path -Parent $PSScriptRoot
$acrFqdn = "$AcrName.azurecr.io"

# Parse image selection
$imageList = if ($Images -eq "all") {
    @("rust-api", "csharp-api", "worker-service")
}
else {
    $Images -split "," | ForEach-Object { $_.Trim() }
}

# Validate image names
$validImages = @("rust-api", "csharp-api", "worker-service")
foreach ($img in $imageList) {
    if ($img -notin $validImages) {
        Write-Host "✗ Invalid image name: $img" -ForegroundColor Red
        Write-Host "  Valid options: $($validImages -join ', '), or all" -ForegroundColor Yellow
        exit 1
    }
}

# Image configuration: name -> (docker image name, build context relative to root)
$imageConfig = @{
    "rust-api"       = @{ DockerName = "hello-rust-api"; Context = "src\rust-api" }
    "csharp-api"     = @{ DockerName = "hello-csharp-api"; Context = "src\csharp-api" }
    "worker-service" = @{ DockerName = "worker-service"; Context = "src\worker-service\WorkerService" }
}

Write-Host "Images to upgrade: $($imageList -join ', ')" -ForegroundColor White
Write-Host "Version tag:       $Version" -ForegroundColor White
Write-Host "ACR:               $acrFqdn" -ForegroundColor White
Write-Host ""

# Set Azure subscription if provided
if ($SubscriptionId) {
    Write-Host "Setting Azure subscription..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to set subscription" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Subscription set to $SubscriptionId" -ForegroundColor Green
    Write-Host ""
}

# Login to ACR
Write-Host "Logging into ACR: $AcrName..." -ForegroundColor Yellow
az acr login --name $AcrName
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to login to ACR" -ForegroundColor Red
    exit 1
}
Write-Host "✓ ACR login successful" -ForegroundColor Green
Write-Host ""

# Build, tag, and push each image
$total = $imageList.Count
$current = 0
$failed = @()

foreach ($img in $imageList) {
    $current++
    $config = $imageConfig[$img]
    $dockerName = $config.DockerName
    $contextPath = Join-Path $rootDir $config.Context

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  [$current/$total] Upgrading $dockerName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Build with --pull --no-cache to get fresh base images and security patches
    Write-Host "Building with fresh base images (--pull --no-cache)..." -ForegroundColor Yellow
    Push-Location $contextPath
    try {
        docker build --pull --no-cache -t "${dockerName}:${Version}" .
        if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
        Write-Host "✓ Build successful" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to build ${dockerName}: $_" -ForegroundColor Red
        $failed += $dockerName
        Pop-Location
        continue
    }
    Pop-Location

    # Tag for ACR
    Write-Host "Tagging for ACR..." -ForegroundColor Yellow
    docker tag "${dockerName}:${Version}" "${acrFqdn}/${dockerName}:${Version}"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to tag ${dockerName}" -ForegroundColor Red
        $failed += $dockerName
        continue
    }
    Write-Host "✓ Tagged: ${acrFqdn}/${dockerName}:${Version}" -ForegroundColor Green

    # Push to ACR
    Write-Host "Pushing to ACR..." -ForegroundColor Yellow
    docker push "${acrFqdn}/${dockerName}:${Version}"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to push ${dockerName}" -ForegroundColor Red
        $failed += $dockerName
        continue
    }
    Write-Host "✓ Pushed successfully" -ForegroundColor Green
    Write-Host ""
}

# Verify
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($img in $imageList) {
    if ($img -notin ($failed | ForEach-Object { $imageConfig.Keys | Where-Object { $imageConfig[$_].DockerName -eq $_ } })) {
        $dockerName = $imageConfig[$img].DockerName
        Write-Host "Tags for ${dockerName}:" -ForegroundColor Yellow
        az acr repository show-tags --name $AcrName --repository $dockerName -o table 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  (unable to verify — repository may not exist yet)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Upgrade Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failed.Count -eq 0) {
    Write-Host "✓ All $total image(s) upgraded and pushed successfully" -ForegroundColor Green
}
else {
    Write-Host "⚠ $($total - $failed.Count)/$total image(s) succeeded" -ForegroundColor Yellow
    Write-Host "✗ Failed: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host ""
