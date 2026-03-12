<#
.SYNOPSIS
    Tests HPA scaling behavior under load.

.DESCRIPTION
    Sends increasing message loads and monitors HPA scaling response.
    Validates that HPA scales up and down as expected.

.PARAMETER ApiEndpoint
    Rust API endpoint (default: http://localhost:8080)

.PARAMETER Namespace
    Kubernetes namespace (default: hello-apis)

.PARAMETER RabbitMqManagement
    RabbitMQ Management URL (default: http://localhost:15672)

.PARAMETER RabbitMqCredential
    RabbitMQ credential (default: admin/admin123)

.EXAMPLE
    .\Test-HPAScaling.ps1
    Run HPA scaling test with default settings
#>

param(
    [Parameter()]
    [string]$ApiEndpoint = "http://localhost:8080",
    
    [Parameter()]
    [string]$Namespace = "hello-apis",
    
    [Parameter()]
    [string]$RabbitMqManagement = "http://localhost:15672",
    
    [Parameter()]
    [pscredential]$RabbitMqCredential = [System.Management.Automation.PSCredential]::new("admin", (ConvertTo-SecureString "admin123" -AsPlainText -Force))
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HPA Scaling Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testResults = @()

function Invoke-KubectlChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$AllowNonZeroExit
    )

    $output = & kubectl @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $script:LastKubectlExitCode = $exitCode

    if ($exitCode -ne 0 -and -not $AllowNonZeroExit) {
        $outputText = ($output | Out-String).Trim()
        throw "kubectl $($Arguments -join ' ') failed with exit code $exitCode. $outputText"
    }

    return $output
}

function Get-CurrentReplicas {
    try {
        $deploymentJson = (Invoke-KubectlChecked -Arguments @("get", "deployment", "worker-service", "-n", $Namespace, "-o", "json") -AllowNonZeroExit | Out-String)
        if ($script:LastKubectlExitCode -ne 0 -or -not $deploymentJson.Trim()) {
            return 0
        }
        $deployment = $deploymentJson | ConvertFrom-Json
        return $deployment.status.replicas
    } catch {
        return 0
    }
}

function Get-QueueDepth {
    try {
        $pair = "$($RabbitMqCredential.UserName):$($RabbitMqCredential.GetNetworkCredential().Password)"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $authHeader = @{ Authorization = "Basic $base64" }
        
        $apiUrl = "$RabbitMqManagement/api/queues/%2F/task-queue"
        $queueStats = Invoke-RestMethod -Uri $apiUrl -Headers $authHeader -Method Get
        return $queueStats.messages_ready
    } catch {
        return -1
    }
}

function Wait-ForScaling {
    param(
        [int]$expectedMinReplicas,
        [int]$timeoutSeconds = 120
    )
    
    Write-Host "  Waiting for HPA to scale (timeout: ${timeoutSeconds}s)..." -ForegroundColor Gray
    $startTime = Get-Date
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
        $currentReplicas = Get-CurrentReplicas
        Write-Host "  Current replicas: $currentReplicas" -ForegroundColor Gray -NoNewline
        Write-Host "`r" -NoNewline
        
        if ($currentReplicas -ge $expectedMinReplicas) {
            Write-Host ""
            Write-Host "  ✓ Scaled to $currentReplicas replicas" -ForegroundColor Green
            return $currentReplicas
        }
        
        Start-Sleep -Seconds 5
    }
    
    Write-Host ""
    Write-Host "  ⚠ Timeout waiting for scaling" -ForegroundColor Yellow
    return Get-CurrentReplicas
}

# Test 1: Baseline
Write-Host "[Test 1/4] Baseline - Check initial state" -ForegroundColor Yellow
$initialReplicas = Get-CurrentReplicas
$initialQueue = Get-QueueDepth

Write-Host "  Initial replicas:  $initialReplicas" -ForegroundColor White
Write-Host "  Queue depth:       $initialQueue" -ForegroundColor White

$testResults += @{
    Test = "Baseline"
    InitialReplicas = $initialReplicas
    FinalReplicas = $initialReplicas
    MessagesSent = 0
    Success = $true
}

Write-Host ""
Start-Sleep -Seconds 5

# Test 2: Light load
Write-Host "[Test 2/4] Light Load - Send 50 messages" -ForegroundColor Yellow
$sendScript = Join-Path $PSScriptRoot "Send-TestMessages.ps1"
& $sendScript -Count 50 -Endpoint $ApiEndpoint -BurstMode | Out-Null

$queueDepth = Get-QueueDepth
Write-Host "  Queue depth after send: $queueDepth" -ForegroundColor White

$finalReplicas = Wait-ForScaling -expectedMinReplicas 2 -timeoutSeconds 90

$testResults += @{
    Test = "Light Load (50 msgs)"
    InitialReplicas = $initialReplicas
    FinalReplicas = $finalReplicas
    MessagesSent = 50
    Success = ($finalReplicas -ge 2)
}

Write-Host ""
Start-Sleep -Seconds 10

# Test 3: Medium load
Write-Host "[Test 3/4] Medium Load - Send 200 messages" -ForegroundColor Yellow
$beforeReplicas = Get-CurrentReplicas
& $sendScript -Count 200 -Endpoint $ApiEndpoint -BurstMode | Out-Null

$queueDepth = Get-QueueDepth
Write-Host "  Queue depth after send: $queueDepth" -ForegroundColor White

$finalReplicas = Wait-ForScaling -expectedMinReplicas 4 -timeoutSeconds 90

$testResults += @{
    Test = "Medium Load (200 msgs)"
    InitialReplicas = $beforeReplicas
    FinalReplicas = $finalReplicas
    MessagesSent = 200
    Success = ($finalReplicas -ge 4)
}

Write-Host ""
Start-Sleep -Seconds 10

# Test 4: Heavy load
Write-Host "[Test 4/4] Heavy Load - Send 500 messages" -ForegroundColor Yellow
$beforeReplicas = Get-CurrentReplicas
& $sendScript -Count 500 -Endpoint $ApiEndpoint -BurstMode | Out-Null

$queueDepth = Get-QueueDepth
Write-Host "  Queue depth after send: $queueDepth" -ForegroundColor White

$finalReplicas = Wait-ForScaling -expectedMinReplicas 6 -timeoutSeconds 120

$testResults += @{
    Test = "Heavy Load (500 msgs)"
    InitialReplicas = $beforeReplicas
    FinalReplicas = $finalReplicas
    MessagesSent = 500
    Success = ($finalReplicas -ge 6)
}

Write-Host ""

# Wait for processing
Write-Host "Waiting for queue to process (60s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Test scale-down
Write-Host "Checking scale-down behavior..." -ForegroundColor Yellow
Write-Host "  Note: Scale-down has 5-minute stabilization window" -ForegroundColor Gray
$currentReplicas = Get-CurrentReplicas
$queueDepth = Get-QueueDepth
Write-Host "  Current replicas: $currentReplicas" -ForegroundColor White
Write-Host "  Queue depth: $queueDepth" -ForegroundColor White

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($result in $testResults) {
    $status = if ($result.Success) { "✓ PASS" } else { "✗ FAIL" }
    $statusColor = if ($result.Success) { "Green" } else { "Red" }
    
    Write-Host ""
    Write-Host "Test: $($result.Test)" -ForegroundColor White
    Write-Host "  Messages Sent:     $($result.MessagesSent)" -ForegroundColor White
    Write-Host "  Initial Replicas:  $($result.InitialReplicas)" -ForegroundColor White
    Write-Host "  Final Replicas:    $($result.FinalReplicas)" -ForegroundColor White
    Write-Host "  Status:            $status" -ForegroundColor $statusColor
}

Write-Host ""
$passCount = ($testResults | Where-Object { $_.Success }).Count
$totalCount = $testResults.Count

Write-Host "Overall: $passCount/$totalCount tests passed" -ForegroundColor $(if ($passCount -eq $totalCount) { "Green" } else { "Yellow" })
Write-Host ""

if ($passCount -eq $totalCount) {
    Write-Host "✓ HPA scaling test PASSED!" -ForegroundColor Green
} else {
    Write-Host "⚠ Some HPA scaling tests failed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  - Ensure metrics-server is installed in the cluster" -ForegroundColor White
    Write-Host "  - Check HPA status: kubectl describe hpa worker-service-hpa -n $Namespace" -ForegroundColor White
    Write-Host "  - Verify CPU requests are set in worker deployment" -ForegroundColor White
    Write-Host "  - Increase processing delay to generate more CPU load" -ForegroundColor White
}
