<#
.SYNOPSIS
    Deploys the message queue system locally using Docker Compose or Kubernetes.

.DESCRIPTION
    Starts RabbitMQ, Rust API, C# API, and Worker Service locally.
    Supports three deployment modes:
    1. Direct execution (apps run in dev container) - Default
    2. Full Docker Compose (all services containerized)
    3. Kubernetes mode (production-like)

.PARAMETER Build
    Force rebuild of all images before starting

.PARAMETER Down
    Stop and remove all containers

.PARAMETER UseKubernetes
    Deploy to local Kubernetes instead of Docker Compose

.PARAMETER UseDockerCompose
    Use full Docker Compose setup (all services containerized)

.EXAMPLE
    .\Deploy-Local.ps1
    Start infrastructure only and provide instructions for direct execution

.EXAMPLE
    .\Deploy-Local.ps1 -UseDockerCompose
    Start all services in full Docker Compose mode

.EXAMPLE
    .\Deploy-Local.ps1 -UseKubernetes
    Deploy all services to local Kubernetes

.EXAMPLE
    .\Deploy-Local.ps1 -Build
    Rebuild and start all services

.EXAMPLE
    .\Deploy-Local.ps1 -Down
    Stop and remove all containers
#>

param(
    [Parameter()]
    [switch]$Build,
    
    [Parameter()]
    [switch]$Down,
    
    [Parameter()]
    [switch]$UseKubernetes,
    
    [Parameter()]
    [switch]$UseDockerCompose
)

$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
if ($UseKubernetes) {
    Write-Host "  Local Deployment (Kubernetes)" -ForegroundColor Cyan
}
elseif ($UseDockerCompose) {
    Write-Host "  Local Deployment (Full Docker Compose)" -ForegroundColor Cyan
}
else {
    Write-Host "  Local Deployment (Direct Execution)" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $rootDir

try {
    if ($Down) {
        if ($UseKubernetes) {
            Write-Host "Stopping Kubernetes services..." -ForegroundColor Yellow
            kubectl delete -f "$rootDir/src/k8s/local/" --ignore-not-found=true
            Write-Host "✓ All Kubernetes services stopped" -ForegroundColor Green
        }
        elseif ($UseDockerCompose) {
            Write-Host "Stopping Full Docker Compose services..." -ForegroundColor Yellow
            docker-compose -f docker-compose.full.yml down -v
            Write-Host "✓ All containerized services stopped and removed" -ForegroundColor Green
        }
        else {
            Write-Host "Stopping Infrastructure services..." -ForegroundColor Yellow
            docker-compose down -v
            Write-Host "✓ Infrastructure services stopped and removed" -ForegroundColor Green
        }
        Pop-Location
        exit 0
    }
    
    
    if ($UseKubernetes) {
        # Kubernetes deployment mode
        if ($Build) {
            Write-Host "Building images for Kubernetes..." -ForegroundColor Yellow
            & "$rootDir\.build\Build-All.ps1"
            Write-Host ""
        }
        
        Write-Host "Deploying to local Kubernetes..." -ForegroundColor Yellow
        kubectl apply -f "$rootDir/src/k8s/local/"
        
        Write-Host ""
        Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
        kubectl wait --for=condition=ready pod -l app=rust-api -n hello-apis-local --timeout=60s
        kubectl wait --for=condition=ready pod -l app=csharp-api -n hello-apis-local --timeout=60s
        kubectl wait --for=condition=ready pod -l app=worker-service -n hello-apis-local --timeout=60s
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Service Status" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        kubectl get pods -n hello-apis-local
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Access URLs (with port forwarding)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Rust API:              http://localhost:8080" -ForegroundColor White
        Write-Host "C# API:                http://localhost:5000" -ForegroundColor White
        Write-Host "RabbitMQ Management:   http://localhost:15672" -ForegroundColor White
        Write-Host "  Username: admin" -ForegroundColor Gray
        Write-Host "  Password: admin123" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Note: Port forwarding may need to be started with:" -ForegroundColor Yellow
        Write-Host "  kubectl port-forward svc/rust-api-service 8080:80 -n hello-apis-local" -ForegroundColor Gray
        Write-Host "  kubectl port-forward svc/csharp-api-service 5000:80 -n hello-apis-local" -ForegroundColor Gray
        
    }
    elseif ($UseDockerCompose) {
        # Full Docker Compose mode - all services containerized
        if ($Build) {
            Write-Host "Building all images..." -ForegroundColor Yellow
            docker-compose -f docker-compose.full.yml build --no-cache
            Write-Host ""
        }
        
        Write-Host "Starting all services in containers..." -ForegroundColor Yellow
        docker-compose -f docker-compose.full.yml up -d
        
        Write-Host ""
        Write-Host "Waiting for services to be healthy..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Service Status" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        docker-compose -f docker-compose.full.yml ps
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Access URLs (All Services Running)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Rust API:              http://localhost:8080" -ForegroundColor White
        Write-Host "C# API:                http://localhost:5000" -ForegroundColor White
        Write-Host "RabbitMQ Management:   http://localhost:15672" -ForegroundColor White
        Write-Host "  Username: admin" -ForegroundColor Gray
        Write-Host "  Password: admin123" -ForegroundColor Gray
        Write-Host ""
        
    }
    else {
        # Direct execution mode
        if ($Build) {
            Write-Host "Building images..." -ForegroundColor Yellow
            docker-compose build --no-cache
            Write-Host ""
        }
        
        Write-Host "Starting infrastructure services..." -ForegroundColor Yellow
        docker-compose up -d
        
        Write-Host ""
        Write-Host "Waiting for RabbitMQ to be healthy..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Infrastructure Status" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        docker-compose ps
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Application Services" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "To start application services manually, run:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Rust API:" -ForegroundColor White
        Write-Host "  cd src/rust-api && cargo run" -ForegroundColor Gray
        Write-Host "  (or use VS Code task: 'Start Rust API')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "C# API:" -ForegroundColor White
        Write-Host "  cd src/csharp-api && dotnet run" -ForegroundColor Gray
        Write-Host "  (or use VS Code task: 'Start C# API')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Worker Service:" -ForegroundColor White
        Write-Host "  cd src/worker-service/WorkerService && dotnet run" -ForegroundColor Gray
        Write-Host "  (or use VS Code task: 'Start C# Worker')" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Access URLs (when services running)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Rust API:              http://localhost:8080" -ForegroundColor White
        Write-Host "C# API:                http://localhost:5000" -ForegroundColor White
        Write-Host "RabbitMQ Management:   http://localhost:15672" -ForegroundColor White
        Write-Host "  Username: admin" -ForegroundColor Gray
        Write-Host "  Password: admin123" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Testing API connectivity..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    if ($UseKubernetes) {
        Write-Host "Note: API health checks require port forwarding to be active" -ForegroundColor Yellow
    }
    elseif ($UseDockerCompose) {
        Write-Host "Testing containerized APIs..." -ForegroundColor Gray
        
        try {
            $rustHealth = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -TimeoutSec 5
            Write-Host "✓ Rust API is healthy: $($rustHealth.status)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Rust API not yet ready (may still be starting)" -ForegroundColor Yellow
        }
        
        try {
            $csharpHealth = Invoke-RestMethod -Uri "http://localhost:5000/health" -Method Get -TimeoutSec 5
            Write-Host "✓ C# API is healthy: $($csharpHealth.status)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ C# API not yet ready (may still be starting)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Note: APIs need to be started manually in direct execution mode" -ForegroundColor Yellow
        Write-Host "Run the VS Code tasks or commands shown above, then test with:" -ForegroundColor Gray
        Write-Host "  curl http://localhost:8080/health  # Rust API" -ForegroundColor Gray
        Write-Host "  curl http://localhost:5000/health  # C# API" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Quick Start" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test APIs (once running):" -ForegroundColor Yellow
    Write-Host "  curl http://localhost:8080/health  # Rust API" -ForegroundColor Gray
    Write-Host "  curl http://localhost:5000/health  # C# API" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Send test messages:" -ForegroundColor Yellow
    Write-Host "  .\.test\Send-TestMessages.ps1 -Count 10" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Monitor queue:" -ForegroundColor Yellow
    Write-Host "  .\.deploy\Monitor-Queue.ps1 -Continuous" -ForegroundColor Gray
    Write-Host ""
    if ($UseKubernetes) {
        Write-Host "View logs:" -ForegroundColor Yellow
        Write-Host "  kubectl logs -f deployment/rust-api -n hello-apis-local" -ForegroundColor Gray
        Write-Host "  kubectl logs -f deployment/csharp-api -n hello-apis-local" -ForegroundColor Gray
        Write-Host "  kubectl logs -f deployment/worker-service -n hello-apis-local" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Stop services:" -ForegroundColor Yellow
        Write-Host "  .\.deploy\Deploy-Local.ps1 -UseKubernetes -Down" -ForegroundColor Gray
    }
    elseif ($UseDockerCompose) {
        Write-Host "View logs:" -ForegroundColor Yellow
        Write-Host "  docker-compose -f docker-compose.full.yml logs -f rust-api" -ForegroundColor Gray
        Write-Host "  docker-compose -f docker-compose.full.yml logs -f csharp-api" -ForegroundColor Gray
        Write-Host "  docker-compose -f docker-compose.full.yml logs -f worker-service" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Stop services:" -ForegroundColor Yellow
        Write-Host "  .\.deploy\Deploy-Local.ps1 -UseDockerCompose -Down" -ForegroundColor Gray
    }
    else {
        Write-Host "View logs (direct execution):" -ForegroundColor Yellow
        Write-Host "  Check VS Code terminal outputs" -ForegroundColor Gray
        Write-Host "  docker-compose logs -f rabbitmq" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Stop services:" -ForegroundColor Yellow
        Write-Host "  .\.deploy\Deploy-Local.ps1 -Down" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Alternative deployment modes:" -ForegroundColor Yellow
        Write-Host "  .\.deploy\Deploy-Local.ps1 -UseDockerCompose    # Full containerized" -ForegroundColor Gray
        Write-Host "  .\.deploy\Deploy-Local.ps1 -UseKubernetes       # Local K8s" -ForegroundColor Gray
    }
    Write-Host ""
    
}
catch {
    Write-Host "✗ Deployment failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location
