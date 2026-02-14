<#
.SYNOPSIS
    Deploys the message queue system to Azure Kubernetes Service.

.DESCRIPTION
    Deploys RabbitMQ, Rust API, and Worker Service with HPA to AKS.
    Requires kubectl to be configured with AKS credentials.

.PARAMETER Namespace
    Kubernetes namespace (default: hello-apis)

.PARAMETER AcrName
    Azure Container Registry name (required for image paths)

.PARAMETER ImageVersion
    Image version tag (default: latest)

.PARAMETER SkipRabbitMQ
    Skip RabbitMQ deployment (if already deployed)

.EXAMPLE
    .\Deploy-AKS.ps1 -AcrName "myacr"
    Deploy all components to AKS

.EXAMPLE
    .\Deploy-AKS.ps1 -AcrName "myacr" -SkipRabbitMQ
    Deploy only API and workers (RabbitMQ already exists)
#>

param(
    [Parameter()]
    [string]$Namespace = "hello-apis",
    
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter()]
    [string]$ImageVersion = "latest",
    
    [Parameter()]
    [switch]$SkipRabbitMQ
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploy to Azure Kubernetes Service" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$rootDir = Split-Path -Parent $PSScriptRoot
$k8sDir = "$rootDir\src\k8s"

# Verify kubectl connectivity
Write-Host "Verifying Kubernetes connectivity..." -ForegroundColor Yellow
try {
    kubectl cluster-info | Out-Null
    Write-Host "✓ Connected to Kubernetes cluster" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to Kubernetes cluster" -ForegroundColor Red
    Write-Host "Please run: az aks get-credentials --resource-group <rg-name> --name <cluster-name>" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Create namespace if it doesn't exist
Write-Host "Checking namespace..." -ForegroundColor Yellow
$namespaceExists = kubectl get namespace $Namespace 2>&1 | Select-String -Pattern $Namespace -Quiet
if (-not $namespaceExists) {
    Write-Host "  Creating namespace '$Namespace'..." -ForegroundColor Gray
    kubectl apply -f "$k8sDir\namespace.yaml"
}
Write-Host "✓ Namespace ready" -ForegroundColor Green
Write-Host ""

# Update image names in manifests
Write-Host "Updating image references..." -ForegroundColor Yellow
$tempDir = "$env:TEMP\k8s-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy and update manifests
Get-ChildItem "$k8sDir\*.yaml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace '<your-acr-name>', $AcrName
    $content = $content -replace ':latest', ":$ImageVersion"
    $outputPath = Join-Path $tempDir $_.Name
    Set-Content -Path $outputPath -Value $content
}
Write-Host "✓ Manifests prepared" -ForegroundColor Green
Write-Host ""

# Deploy RabbitMQ
if (-not $SkipRabbitMQ) {
    Write-Host "[1/4] Deploying RabbitMQ..." -ForegroundColor Yellow
    kubectl apply -f "$tempDir\rabbitmq-deployment.yaml"
    
    Write-Host "  Waiting for RabbitMQ to be ready..." -ForegroundColor Gray
    kubectl wait --for=condition=ready pod -l app=rabbitmq -n $Namespace --timeout=180s
    Write-Host "✓ RabbitMQ deployed" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[1/4] Skipping RabbitMQ deployment" -ForegroundColor Gray
    Write-Host ""
}

# Deploy Rust API
Write-Host "[2/4] Deploying Rust API..." -ForegroundColor Yellow
kubectl apply -f "$tempDir\rust-deployment.yaml"
Write-Host "  Waiting for Rust API to be ready..." -ForegroundColor Gray
kubectl wait --for=condition=available deployment/rust-hello-api -n $Namespace --timeout=180s
Write-Host "✓ Rust API deployed" -ForegroundColor Green
Write-Host ""

# Deploy Worker Service
Write-Host "[3/4] Deploying Worker Service..." -ForegroundColor Yellow
kubectl apply -f "$tempDir\worker-deployment.yaml"
Write-Host "  Waiting for Worker Service to be ready..." -ForegroundColor Gray
kubectl wait --for=condition=available deployment/worker-service -n $Namespace --timeout=180s
Write-Host "✓ Worker Service deployed" -ForegroundColor Green
Write-Host ""

# Deploy HPA
Write-Host "[4/4] Deploying HPA..." -ForegroundColor Yellow
kubectl apply -f "$tempDir\worker-hpa.yaml"
Write-Host "✓ HPA deployed" -ForegroundColor Green
Write-Host ""

# Cleanup temp directory
Remove-Item -Path $tempDir -Recurse -Force

# Get deployment status
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Pods:" -ForegroundColor Yellow
kubectl get pods -n $Namespace
Write-Host ""

Write-Host "Services:" -ForegroundColor Yellow
kubectl get services -n $Namespace
Write-Host ""

Write-Host "HPA:" -ForegroundColor Yellow
kubectl get hpa -n $Namespace
Write-Host ""

# Get external IPs
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Access Information" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Waiting for external IPs to be assigned..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$rustIp = kubectl get svc rust-hello-api -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
$rabbitmqIp = kubectl get svc rabbitmq-management -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

if ($rustIp) {
    Write-Host "Rust API:              http://$rustIp" -ForegroundColor White
    Write-Host "  Test: curl http://$rustIp/" -ForegroundColor Gray
    Write-Host "  Send: Invoke-RestMethod -Uri http://$rustIp/send -Method Post -Body '{...}'" -ForegroundColor Gray
} else {
    Write-Host "Rust API:              <pending external IP>" -ForegroundColor Yellow
    Write-Host "  Check with: kubectl get svc rust-hello-api -n $Namespace" -ForegroundColor Gray
}

Write-Host ""

if ($rabbitmqIp) {
    Write-Host "RabbitMQ Management:   http://$rabbitmqIp" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor Gray
    Write-Host "  Password: admin123" -ForegroundColor Gray
} else {
    Write-Host "RabbitMQ Management:   <pending external IP>" -ForegroundColor Yellow
    Write-Host "  Check with: kubectl get svc rabbitmq-management -n $Namespace" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitor deployment:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n $Namespace -w" -ForegroundColor Gray
Write-Host ""
Write-Host "Watch HPA scaling:" -ForegroundColor Yellow
Write-Host "  .\.deploy\Watch-HPA.ps1 -Namespace $Namespace" -ForegroundColor Gray
Write-Host ""
Write-Host "Send test messages (once external IP is available):" -ForegroundColor Yellow
Write-Host "  .\.test\Send-TestMessages.ps1 -Endpoint http://$rustIp -Count 50" -ForegroundColor Gray
Write-Host ""
Write-Host "Run end-to-end test:" -ForegroundColor Yellow
Write-Host "  .\.test\Test-E2E.ps1 -ApiEndpoint http://$rustIp -RabbitMqManagement http://$rabbitmqIp" -ForegroundColor Gray
Write-Host ""

Write-Host "✓ Deployment complete!" -ForegroundColor Green
