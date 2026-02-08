<#
.SYNOPSIS
    Deploys the message queue system locally using Docker Compose.

.DESCRIPTION
    Starts RabbitMQ, Rust API, and Worker Service using Docker Compose.
    Builds images if they don't exist.

.PARAMETER Build
    Force rebuild of all images before starting

.PARAMETER Down
    Stop and remove all containers

.EXAMPLE
    .\Deploy-Local.ps1
    Start all services

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
    [switch]$Down
)

$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Local Deployment (Docker Compose)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $rootDir

try {
    if ($Down) {
        Write-Host "Stopping all services..." -ForegroundColor Yellow
        docker-compose down -v
        Write-Host "✓ All services stopped and removed" -ForegroundColor Green
        Pop-Location
        exit 0
    }
    
    if ($Build) {
        Write-Host "Building images..." -ForegroundColor Yellow
        docker-compose build --no-cache
        Write-Host ""
    }
    
    Write-Host "Starting services..." -ForegroundColor Yellow
    docker-compose up -d
    
    Write-Host ""
    Write-Host "Waiting for services to be healthy..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Service Status" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    docker-compose ps
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Access URLs" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Rust API:              http://localhost:8080" -ForegroundColor White
    Write-Host "RabbitMQ Management:   http://localhost:15672" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor Gray
    Write-Host "  Password: admin123" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Testing API connectivity..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -TimeoutSec 5
        Write-Host "✓ Rust API is healthy: $($health.status)" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Could not verify API health (may still be starting): $_" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Quick Start" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Send test messages:" -ForegroundColor Yellow
    Write-Host "  .\.test\Send-TestMessages.ps1 -Count 10" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Monitor queue:" -ForegroundColor Yellow
    Write-Host "  .\.deploy\Monitor-Queue.ps1 -Continuous" -ForegroundColor Gray
    Write-Host ""
    Write-Host "View logs:" -ForegroundColor Yellow
    Write-Host "  docker-compose logs -f rust-api" -ForegroundColor Gray
    Write-Host "  docker-compose logs -f worker-service" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Stop services:" -ForegroundColor Yellow
    Write-Host "  .\.deploy\Deploy-Local.ps1 -Down" -ForegroundColor Gray
    Write-Host ""
    
} catch {
    Write-Host "✗ Deployment failed: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location
