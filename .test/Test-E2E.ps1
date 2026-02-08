<#
.SYNOPSIS
    End-to-end test of the message queue system.

.DESCRIPTION
    Sends test messages, monitors queue processing, and validates results.
    Provides a comprehensive test of the entire system.

.PARAMETER ApiEndpoint
    Rust API endpoint (default: http://localhost:8080)

.PARAMETER RabbitMqManagement
    RabbitMQ Management URL (default: http://localhost:15672)

.PARAMETER MessageCount
    Number of test messages to send (default: 50)

.PARAMETER RabbitMqUsername
    RabbitMQ username (default: admin)

.PARAMETER RabbitMqPassword
    RabbitMQ password (default: admin123)

.PARAMETER Namespace
    Kubernetes namespace (default: hello-apis)

.EXAMPLE
    .\Test-E2E.ps1
    Run end-to-end test with default settings

.EXAMPLE
    .\Test-E2E.ps1 -MessageCount 100 -ApiEndpoint "http://20.123.45.67"
    Test with 100 messages on AKS
#>

param(
    [Parameter()]
    [string]$ApiEndpoint = "http://localhost:8080",
    
    [Parameter()]
    [string]$RabbitMqManagement = "http://localhost:15672",
    
    [Parameter()]
    [int]$MessageCount = 50,
    
    [Parameter()]
    [string]$RabbitMqUsername = "admin",
    
    [Parameter()]
    [string]$RabbitMqPassword = "admin123",
    
    [Parameter()]
    [string]$Namespace = "hello-apis"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  End-to-End Message Queue Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testStartTime = Get-Date

# Step 1: Test API connectivity
Write-Host "[Step 1/5] Testing API connectivity..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$ApiEndpoint/health" -Method Get -TimeoutSec 5
    Write-Host "✓ API is healthy: $($healthResponse.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ API health check failed: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Send test messages
Write-Host "[Step 2/5] Sending $MessageCount test messages..." -ForegroundColor Yellow
$sendScript = Join-Path $PSScriptRoot "Send-TestMessages.ps1"
& $sendScript -Count $MessageCount -Endpoint $ApiEndpoint -BurstMode
Write-Host ""

# Step 3: Monitor queue
Write-Host "[Step 3/5] Checking queue status..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

$pair = "${RabbitMqUsername}:${RabbitMqPassword}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$authHeader = @{ Authorization = "Basic $base64" }

try {
    $apiUrl = "$RabbitMqManagement/api/queues/%2F/task-queue"
    $queueStats = Invoke-RestMethod -Uri $apiUrl -Headers $authHeader -Method Get
    
    Write-Host "  Messages in queue: $($queueStats.messages_ready)" -ForegroundColor White
    Write-Host "  Active consumers:  $($queueStats.consumers)" -ForegroundColor White
    
    if ($queueStats.consumers -eq 0) {
        Write-Host "⚠ Warning: No active consumers found!" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Workers are consuming messages" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Could not check queue status: $_" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Wait for processing
Write-Host "[Step 4/5] Waiting for message processing..." -ForegroundColor Yellow
Write-Host "  Monitoring for up to 60 seconds..." -ForegroundColor Gray

$waitStartTime = Get-Date
$maxWaitSeconds = 60
$allProcessed = $false

while (((Get-Date) - $waitStartTime).TotalSeconds -lt $maxWaitSeconds) {
    try {
        $queueStats = Invoke-RestMethod -Uri $apiUrl -Headers $authHeader -Method Get
        
        if ($queueStats.messages_ready -eq 0 -and $queueStats.messages_unacknowledged -eq 0) {
            $allProcessed = $true
            $processingTime = ((Get-Date) - $waitStartTime).TotalSeconds
            Write-Host "✓ All messages processed in $([math]::Round($processingTime, 2)) seconds" -ForegroundColor Green
            break
        }
        
        $remaining = $queueStats.messages_ready + $queueStats.messages_unacknowledged
        Write-Host "  Remaining messages: $remaining" -ForegroundColor Gray -NoNewline
        Write-Host "`r" -NoNewline
        
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "⚠ Error checking queue: $_" -ForegroundColor Yellow
        break
    }
}

if (-not $allProcessed) {
    Write-Host ""
    Write-Host "⚠ Not all messages were processed within timeout" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Verify results
Write-Host "[Step 5/5] Verifying processing results..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

$resultsScript = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) ".deploy") "Get-ProcessingResults.ps1"
& $resultsScript -Namespace $Namespace -TailLines 200
Write-Host ""

# Summary
$testEndTime = Get-Date
$totalDuration = ($testEndTime - $testStartTime).TotalSeconds

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Messages Sent:     $MessageCount" -ForegroundColor White
Write-Host "All Processed:     $allProcessed" -ForegroundColor $(if ($allProcessed) { "Green" } else { "Yellow" })
Write-Host "Total Duration:    $([math]::Round($totalDuration, 2))s" -ForegroundColor White
Write-Host ""

if ($allProcessed) {
    Write-Host "✓ End-to-end test PASSED!" -ForegroundColor Green
} else {
    Write-Host "⚠ End-to-end test completed with warnings" -ForegroundColor Yellow
}
