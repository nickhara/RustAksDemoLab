<#
.SYNOPSIS
    Retrieves and displays processing results from worker service logs.

.DESCRIPTION
    Queries worker service logs from Kubernetes to show processing statistics,
    throughput, and success rates.

.PARAMETER Namespace
    Kubernetes namespace (default: hello-apis)

.PARAMETER TailLines
    Number of log lines to retrieve (default: 100)

.PARAMETER Since
    Show logs since duration (e.g., "5m", "1h", "24h")

.EXAMPLE
    .\Get-ProcessingResults.ps1
    Show last 100 log lines

.EXAMPLE
    .\Get-ProcessingResults.ps1 -TailLines 500 -Since "10m"
    Show last 500 lines from the past 10 minutes
#>

param(
    [Parameter()]
    [string]$Namespace = "hello-apis",
    
    [Parameter()]
    [int]$TailLines = 100,
    
    [Parameter()]
    [string]$Since = ""
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Worker Processing Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Get worker pods
    $pods = kubectl get pods -n $Namespace -l app=worker-service -o json | ConvertFrom-Json
    
    if ($pods.items.Count -eq 0) {
        Write-Host "✗ No worker pods found in namespace '$Namespace'" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found $($pods.items.Count) worker pod(s)" -ForegroundColor Green
    Write-Host ""
    
    $allLogs = @()
    $processedMessages = @{}
    $totalProcessed = 0
    $errors = 0
    
    foreach ($pod in $pods.items) {
        $podName = $pod.metadata.name
        Write-Host "Fetching logs from: $podName" -ForegroundColor Yellow
        
        $logCommand = "kubectl logs $podName -n $Namespace --tail=$TailLines"
        if ($Since) {
            $logCommand += " --since=$Since"
        }
        
        $logs = Invoke-Expression $logCommand 2>&1
        
        foreach ($line in $logs) {
            if ($line -match "Successfully processed message ([a-f0-9-]+)\..*Total processed: (\d+)") {
                $messageId = $matches[1]
                $count = [int]$matches[2]
                
                if (-not $processedMessages.ContainsKey($messageId)) {
                    $processedMessages[$messageId] = $true
                    $totalProcessed++
                }
            }
            
            if ($line -match "Error processing message") {
                $errors++
            }
            
            if ($line -match "Messages processed: (\d+)") {
                $workerTotal = [int]$matches[1]
                if ($workerTotal -gt $totalProcessed) {
                    $totalProcessed = $workerTotal
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Statistics" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total Messages Processed: $totalProcessed" -ForegroundColor Green
    Write-Host "Unique Messages:          $($processedMessages.Count)" -ForegroundColor White
    Write-Host "Errors:                   $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })
    Write-Host ""
    
    if ($totalProcessed -gt 0) {
        $successRate = [math]::Round((($totalProcessed - $errors) / $totalProcessed) * 100, 2)
        Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 95) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })
    }
    
    Write-Host ""
    Write-Host "Recent Activity (last 10 log entries):" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($pod in $pods.items) {
        $podName = $pod.metadata.name
        Write-Host "Pod: $podName" -ForegroundColor Cyan
        
        $logCommand = "kubectl logs $podName -n $Namespace --tail=10"
        if ($Since) {
            $logCommand += " --since=$Since"
        }
        
        $recentLogs = Invoke-Expression $logCommand 2>&1
        
        foreach ($line in $recentLogs) {
            if ($line -match "Successfully processed") {
                Write-Host "  $line" -ForegroundColor Green
            } elseif ($line -match "Error" -or $line -match "Failed") {
                Write-Host "  $line" -ForegroundColor Red
            } elseif ($line -match "Processing message") {
                Write-Host "  $line" -ForegroundColor White
            } elseif ($line -match "Worker is running") {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    
} catch {
    Write-Host "✗ Error retrieving logs: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host "  - kubectl is configured correctly" -ForegroundColor White
    Write-Host "  - Namespace '$Namespace' exists" -ForegroundColor White
    Write-Host "  - Worker pods are running" -ForegroundColor White
    exit 1
}
