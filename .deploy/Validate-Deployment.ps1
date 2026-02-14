<#
.SYNOPSIS
    Validates health of all deployed components.

.DESCRIPTION
    Performs health checks on Rust API, RabbitMQ, Worker Service, and HPA.
    Can be used for both local and AKS deployments.

.PARAMETER Environment
    Deployment environment: Local or AKS (default: Local)

.PARAMETER Namespace
    Kubernetes namespace (for AKS, default: hello-apis)

.PARAMETER RustApiUrl
    Rust API URL (for local or AKS external IP)

.PARAMETER RabbitMqManagementUrl
    RabbitMQ Management URL

.EXAMPLE
    .\Validate-Deployment.ps1 -Environment Local
    Validate local Docker Compose deployment

.EXAMPLE
    .\Validate-Deployment.ps1 -Environment AKS -Namespace hello-apis
    Validate AKS deployment
#>

param(
    [Parameter()]
    [ValidateSet("Local", "AKS")]
    [string]$Environment = "Local",
    
    [Parameter()]
    [string]$Namespace = "hello-apis",
    
    [Parameter()]
    [string]$RustApiUrl = "http://localhost:8080",
    
    [Parameter()]
    [string]$RabbitMqManagementUrl = "http://localhost:15672"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Health Check Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host ""

$checks = @()

# Check 1: Rust API Health
Write-Host "[1/5] Checking Rust API..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$RustApiUrl/health" -Method Get -TimeoutSec 5
    
    if ($health.status -eq "healthy") {
        Write-Host "✓ Rust API is healthy" -ForegroundColor Green
        $checks += @{ Name = "Rust API Health"; Status = "PASS" }
    } else {
        Write-Host "✗ Rust API returned unexpected status: $($health.status)" -ForegroundColor Red
        $checks += @{ Name = "Rust API Health"; Status = "FAIL" }
    }
} catch {
    Write-Host "✗ Failed to connect to Rust API: $_" -ForegroundColor Red
    $checks += @{ Name = "Rust API Health"; Status = "FAIL" }
}
Write-Host ""

# Check 2: RabbitMQ
Write-Host "[2/5] Checking RabbitMQ..." -ForegroundColor Yellow
try {
    $pair = "admin:admin123"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $authHeader = @{ Authorization = "Basic $base64" }
    
    $overview = Invoke-RestMethod -Uri "$RabbitMqManagementUrl/api/overview" -Headers $authHeader -Method Get -TimeoutSec 5
    
    if ($overview.rabbitmq_version) {
        Write-Host "✓ RabbitMQ is running (version: $($overview.rabbitmq_version))" -ForegroundColor Green
        $checks += @{ Name = "RabbitMQ Service"; Status = "PASS" }
    } else {
        Write-Host "✗ RabbitMQ returned unexpected response" -ForegroundColor Red
        $checks += @{ Name = "RabbitMQ Service"; Status = "FAIL" }
    }
    
    # Check queue exists
    $queueUrl = "$RabbitMqManagementUrl/api/queues/%2F/task-queue"
    $queue = Invoke-RestMethod -Uri $queueUrl -Headers $authHeader -Method Get -TimeoutSec 5
    
    if ($queue.name -eq "task-queue") {
        Write-Host "✓ task-queue exists with $($queue.consumers) consumers" -ForegroundColor Green
        $checks += @{ Name = "RabbitMQ Queue"; Status = "PASS" }
    } else {
        Write-Host "✗ task-queue not found" -ForegroundColor Red
        $checks += @{ Name = "RabbitMQ Queue"; Status = "FAIL" }
    }
} catch {
    Write-Host "✗ Failed to connect to RabbitMQ: $_" -ForegroundColor Red
    $checks += @{ Name = "RabbitMQ Service"; Status = "FAIL" }
    $checks += @{ Name = "RabbitMQ Queue"; Status = "SKIP" }
}
Write-Host ""

# Check 3: Worker Service (environment-specific)
Write-Host "[3/5] Checking Worker Service..." -ForegroundColor Yellow
if ($Environment -eq "Local") {
    try {
        $workerStatus = docker ps --filter "name=worker-service" --format "{{.Status}}"
        if ($workerStatus -match "Up") {
            Write-Host "✓ Worker Service container is running" -ForegroundColor Green
            $checks += @{ Name = "Worker Service"; Status = "PASS" }
        } else {
            Write-Host "✗ Worker Service container is not running" -ForegroundColor Red
            $checks += @{ Name = "Worker Service"; Status = "FAIL" }
        }
    } catch {
        Write-Host "✗ Failed to check Worker Service: $_" -ForegroundColor Red
        $checks += @{ Name = "Worker Service"; Status = "FAIL" }
    }
} else {
    try {
        $deployment = kubectl get deployment worker-service -n $Namespace -o json | ConvertFrom-Json
        $ready = $deployment.status.readyReplicas
        $desired = $deployment.status.replicas
        
        if ($ready -ge 1) {
            Write-Host "✓ Worker Service has $ready/$desired pods ready" -ForegroundColor Green
            $checks += @{ Name = "Worker Service"; Status = "PASS" }
        } else {
            Write-Host "✗ Worker Service has no ready pods" -ForegroundColor Red
            $checks += @{ Name = "Worker Service"; Status = "FAIL" }
        }
    } catch {
        Write-Host "✗ Failed to check Worker Service: $_" -ForegroundColor Red
        $checks += @{ Name = "Worker Service"; Status = "FAIL" }
    }
}
Write-Host ""

# Check 4: HPA (AKS only)
if ($Environment -eq "AKS") {
    Write-Host "[4/5] Checking HPA..." -ForegroundColor Yellow
    try {
        $hpa = kubectl get hpa worker-service-hpa -n $Namespace -o json | ConvertFrom-Json
        
        if ($hpa.status.currentReplicas) {
            Write-Host "✓ HPA is active ($($hpa.status.currentReplicas) replicas, min: $($hpa.spec.minReplicas), max: $($hpa.spec.maxReplicas))" -ForegroundColor Green
            $checks += @{ Name = "HPA"; Status = "PASS" }
        } else {
            Write-Host "⚠ HPA exists but no replicas reported" -ForegroundColor Yellow
            $checks += @{ Name = "HPA"; Status = "WARN" }
        }
    } catch {
        Write-Host "✗ Failed to check HPA: $_" -ForegroundColor Red
        $checks += @{ Name = "HPA"; Status = "FAIL" }
    }
    Write-Host ""
} else {
    Write-Host "[4/5] Skipping HPA check (Local environment)" -ForegroundColor Gray
    Write-Host ""
}

# Check 5: End-to-end test
Write-Host "[5/5] Running end-to-end test..." -ForegroundColor Yellow
try {
    $payload = @{
        task_type = "health-check"
        payload = @{
            test = $true
            timestamp = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$RustApiUrl/send" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10
    
    if ($response.success) {
        Write-Host "✓ Message sent successfully (ID: $($response.message_id))" -ForegroundColor Green
        $checks += @{ Name = "End-to-End"; Status = "PASS" }
        
        Write-Host "  Waiting 5 seconds for processing..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
        
        # Check queue depth
        $pair = "admin:admin123"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $authHeader = @{ Authorization = "Basic $base64" }
        
        $queueUrl = "$RabbitMqManagementUrl/api/queues/%2F/task-queue"
        $queue = Invoke-RestMethod -Uri $queueUrl -Headers $authHeader -Method Get -TimeoutSec 5
        
        Write-Host "  Queue depth: $($queue.messages_ready)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Failed to send message: $($response.message)" -ForegroundColor Red
        $checks += @{ Name = "End-to-End"; Status = "FAIL" }
    }
} catch {
    Write-Host "✗ End-to-end test failed: $_" -ForegroundColor Red
    $checks += @{ Name = "End-to-End"; Status = "FAIL" }
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Validation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passCount = ($checks | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($checks | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($checks | Where-Object { $_.Status -eq "WARN" }).Count
$totalCount = $checks.Count

foreach ($check in $checks) {
    $color = switch ($check.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    
    Write-Host "$($check.Name.PadRight(25)) [$($check.Status)]" -ForegroundColor $color
}

Write-Host ""
Write-Host "Total Checks: $totalCount" -ForegroundColor White
Write-Host "Passed:       $passCount" -ForegroundColor Green
if ($warnCount -gt 0) {
    Write-Host "Warnings:     $warnCount" -ForegroundColor Yellow
}
if ($failCount -gt 0) {
    Write-Host "Failed:       $failCount" -ForegroundColor Red
}
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "✓ All validation checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some validation checks failed" -ForegroundColor Red
    exit 1
}
