<#
.SYNOPSIS
    Sends test messages to the Rust API message queue endpoint.

.DESCRIPTION
    This script sends a configurable number of test messages to the /send endpoint
    of the Rust API. Supports both local Docker and AKS deployments.

.PARAMETER Count
    Number of messages to send (default: 10)

.PARAMETER Endpoint
    API endpoint URL (default: http://localhost:8080)

.PARAMETER TaskType
    Type of task to send (default: "test-task")

.PARAMETER BurstMode
    Send all messages as fast as possible without delay

.PARAMETER DelayMs
    Delay in milliseconds between messages (default: 100, ignored if BurstMode is true)

.EXAMPLE
    .\Send-TestMessages.ps1 -Count 10
    Send 10 messages to local endpoint

.EXAMPLE
    .\Send-TestMessages.ps1 -Count 100 -BurstMode
    Send 100 messages in burst mode (no delay)

.EXAMPLE
    .\Send-TestMessages.ps1 -Count 50 -Endpoint "http://20.123.45.67" -TaskType "load-test"
    Send 50 messages to AKS endpoint with custom task type
#>

param(
    [Parameter()]
    [int]$Count = 10,
    
    [Parameter()]
    [string]$Endpoint = "http://localhost:8080",
    
    [Parameter()]
    [string]$TaskType = "test-task",
    
    [Parameter()]
    [switch]$BurstMode,
    
    [Parameter()]
    [int]$DelayMs = 100
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Message Queue Load Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Endpoint:    $Endpoint" -ForegroundColor White
Write-Host "Task Type:   $TaskType" -ForegroundColor White
Write-Host "Message Count: $Count" -ForegroundColor White
Write-Host "Burst Mode:  $BurstMode" -ForegroundColor White
if (-not $BurstMode) {
    Write-Host "Delay:       ${DelayMs}ms" -ForegroundColor White
}
Write-Host ""

$sendUrl = "$Endpoint/send"
$successCount = 0
$failureCount = 0
$startTime = Get-Date

try {
    # Test connectivity
    Write-Host "Testing API connectivity..." -ForegroundColor Yellow
    $healthResponse = Invoke-RestMethod -Uri "$Endpoint/health" -Method Get -TimeoutSec 5
    Write-Host "✓ API is healthy: $($healthResponse.status)" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "✗ Failed to connect to API endpoint: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Sending $Count messages..." -ForegroundColor Yellow
Write-Host ""

for ($i = 1; $i -le $Count; $i++) {
    $payload = @{
        task_type = $TaskType
        payload = @{
            message_number = $i
            timestamp = (Get-Date).ToString("o")
            data = "Test message payload #$i"
        }
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $sendUrl -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10
        
        if ($response.success) {
            $successCount++
            Write-Host "[${i}/${Count}] ✓ Message sent: $($response.message_id)" -ForegroundColor Green
        } else {
            $failureCount++
            Write-Host "[${i}/${Count}] ✗ Failed: $($response.message)" -ForegroundColor Red
        }
    } catch {
        $failureCount++
        Write-Host "[${i}/${Count}] ✗ Error: $_" -ForegroundColor Red
    }
    
    if (-not $BurstMode -and $i -lt $Count) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$throughput = [math]::Round($Count / $duration, 2)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Messages:  $Count" -ForegroundColor White
Write-Host "Successful:      $successCount" -ForegroundColor Green
Write-Host "Failed:          $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "White" })
Write-Host "Duration:        ${duration}s" -ForegroundColor White
Write-Host "Throughput:      ${throughput} msg/s" -ForegroundColor White
Write-Host ""

if ($failureCount -eq 0) {
    Write-Host "✓ All messages sent successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠ Some messages failed to send" -ForegroundColor Yellow
}
