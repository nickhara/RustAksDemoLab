<#
.SYNOPSIS
    Monitors RabbitMQ queue depth and worker status.

.DESCRIPTION
    Connects to RabbitMQ Management API to display queue statistics and worker status.
    Supports continuous monitoring with auto-refresh.

.PARAMETER ManagementUrl
    RabbitMQ Management API URL (default: http://localhost:15672)

.PARAMETER Username
    RabbitMQ username (default: admin)

.PARAMETER Password
    RabbitMQ password (default: admin123)

.PARAMETER QueueName
    Queue name to monitor (default: task-queue)

.PARAMETER Continuous
    Enable continuous monitoring with auto-refresh

.PARAMETER RefreshInterval
    Refresh interval in seconds for continuous mode (default: 5)

.EXAMPLE
    .\Monitor-Queue.ps1
    Monitor queue once

.EXAMPLE
    .\Monitor-Queue.ps1 -Continuous
    Monitor queue continuously with 5-second refresh

.EXAMPLE
    .\Monitor-Queue.ps1 -ManagementUrl "http://20.123.45.67" -Username admin -Password admin123 -Continuous
    Monitor AKS RabbitMQ instance continuously
#>

param(
    [Parameter()]
    [string]$ManagementUrl = "http://localhost:15672",
    
    [Parameter()]
    [string]$Username = "admin",
    
    [Parameter()]
    [string]$Password = "admin123",
    
    [Parameter()]
    [string]$QueueName = "task-queue",
    
    [Parameter()]
    [switch]$Continuous,
    
    [Parameter()]
    [int]$RefreshInterval = 5
)

$ErrorActionPreference = "Stop"

# Create auth header
$pair = "${Username}:${Password}"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$authHeader = @{
    Authorization = "Basic $base64"
}

function Get-QueueStats {
    try {
        $apiUrl = "$ManagementUrl/api/queues/%2F/$QueueName"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $authHeader -Method Get
        
        return @{
            Success = $true
            Messages = $response.messages
            MessagesReady = $response.messages_ready
            MessagesUnacknowledged = $response.messages_unacknowledged
            Consumers = $response.consumers
            MessageStats = $response.message_stats
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Display-Stats {
    param($stats, $timestamp)
    
    Clear-Host
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RabbitMQ Queue Monitor" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Time:         $timestamp" -ForegroundColor White
    Write-Host "Queue:        $QueueName" -ForegroundColor White
    Write-Host "Management:   $ManagementUrl" -ForegroundColor White
    Write-Host ""
    
    if ($stats.Success) {
        Write-Host "Queue Statistics:" -ForegroundColor Yellow
        Write-Host "  Total Messages:        $($stats.Messages)" -ForegroundColor White
        Write-Host "  Ready (waiting):       $($stats.MessagesReady)" -ForegroundColor $(if ($stats.MessagesReady -gt 50) { "Red" } elseif ($stats.MessagesReady -gt 10) { "Yellow" } else { "Green" })
        Write-Host "  Unacknowledged:        $($stats.MessagesUnacknowledged)" -ForegroundColor White
        Write-Host "  Active Consumers:      $($stats.Consumers)" -ForegroundColor $(if ($stats.Consumers -eq 0) { "Red" } else { "Green" })
        Write-Host ""
        
        if ($stats.MessageStats) {
            Write-Host "Message Rates:" -ForegroundColor Yellow
            
            $publishRate = if ($stats.MessageStats.publish_details) { 
                [math]::Round($stats.MessageStats.publish_details.rate, 2) 
            } else { 0 }
            
            $deliverRate = if ($stats.MessageStats.deliver_get_details) { 
                [math]::Round($stats.MessageStats.deliver_get_details.rate, 2) 
            } else { 0 }
            
            $ackRate = if ($stats.MessageStats.ack_details) { 
                [math]::Round($stats.MessageStats.ack_details.rate, 2) 
            } else { 0 }
            
            Write-Host "  Publish Rate:          $publishRate msg/s" -ForegroundColor White
            Write-Host "  Delivery Rate:         $deliverRate msg/s" -ForegroundColor White
            Write-Host "  Acknowledgment Rate:   $ackRate msg/s" -ForegroundColor White
            Write-Host ""
            
            if ($publishRate -gt $ackRate -and $stats.MessagesReady -gt 10) {
                Write-Host "⚠ Warning: Messages are being published faster than processed!" -ForegroundColor Yellow
                Write-Host "  Consider scaling up worker instances." -ForegroundColor Yellow
            } elseif ($stats.MessagesReady -eq 0 -and $ackRate -eq 0 -and $stats.Consumers -gt 1) {
                Write-Host "✓ Queue is empty and workers are idle. Consider scaling down." -ForegroundColor Green
            } elseif ($stats.MessagesReady -eq 0) {
                Write-Host "✓ Queue is empty - all messages processed!" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "✗ Failed to retrieve queue stats" -ForegroundColor Red
        Write-Host "Error: $($stats.Error)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check:" -ForegroundColor Yellow
        Write-Host "  - RabbitMQ is running and accessible" -ForegroundColor White
        Write-Host "  - Management URL is correct" -ForegroundColor White
        Write-Host "  - Username and password are correct" -ForegroundColor White
        Write-Host "  - Queue name exists" -ForegroundColor White
    }
    
    Write-Host ""
    
    if ($Continuous) {
        Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Gray
        Write-Host "Refreshing in $RefreshInterval seconds..." -ForegroundColor Gray
    }
}

# Main execution
Write-Host "Connecting to RabbitMQ Management API..." -ForegroundColor Yellow
Write-Host ""

if ($Continuous) {
    while ($true) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $stats = Get-QueueStats
        Display-Stats -stats $stats -timestamp $timestamp
        Start-Sleep -Seconds $RefreshInterval
    }
} else {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $stats = Get-QueueStats
    Display-Stats -stats $stats -timestamp $timestamp
}
