<#
.SYNOPSIS
    Monitors Horizontal Pod Autoscaler status in real-time.

.DESCRIPTION
    Watches HPA metrics, replica counts, and scaling events for the worker service.
    Supports both local Kubernetes and AKS deployments.

.PARAMETER Namespace
    Kubernetes namespace (default: hello-apis)

.PARAMETER HpaName
    HPA resource name (default: worker-service-hpa)

.PARAMETER RefreshInterval
    Refresh interval in seconds (default: 5)

.EXAMPLE
    .\Watch-HPA.ps1
    Monitor HPA with default settings

.EXAMPLE
    .\Watch-HPA.ps1 -Namespace hello-apis -RefreshInterval 10
    Monitor with 10-second refresh interval
#>

param(
    [Parameter()]
    [string]$Namespace = "hello-apis",
    
    [Parameter()]
    [string]$HpaName = "worker-service-hpa",
    
    [Parameter()]
    [int]$RefreshInterval = 5
)

$ErrorActionPreference = "Stop"

function Get-HPAStatus {
    try {
        $hpaJson = kubectl get hpa $HpaName -n $Namespace -o json 2>&1 | ConvertFrom-Json
        
        $currentReplicas = $hpaJson.status.currentReplicas
        $desiredReplicas = $hpaJson.status.desiredReplicas
        $minReplicas = $hpaJson.spec.minReplicas
        $maxReplicas = $hpaJson.spec.maxReplicas
        
        $cpuCurrent = "N/A"
        $cpuTarget = "N/A"
        
        if ($hpaJson.status.currentMetrics) {
            foreach ($metric in $hpaJson.status.currentMetrics) {
                if ($metric.type -eq "Resource" -and $metric.resource.name -eq "cpu") {
                    $cpuCurrent = "$($metric.resource.current.averageUtilization)%"
                }
            }
        }
        
        if ($hpaJson.spec.metrics) {
            foreach ($metric in $hpaJson.spec.metrics) {
                if ($metric.type -eq "Resource" -and $metric.resource.name -eq "cpu") {
                    $cpuTarget = "$($metric.resource.target.averageUtilization)%"
                }
            }
        }
        
        return @{
            Success = $true
            CurrentReplicas = $currentReplicas
            DesiredReplicas = $desiredReplicas
            MinReplicas = $minReplicas
            MaxReplicas = $maxReplicas
            CPUCurrent = $cpuCurrent
            CPUTarget = $cpuTarget
            LastScaleTime = $hpaJson.status.lastScaleTime
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-PodStatus {
    try {
        $podsJson = kubectl get pods -n $Namespace -l app=worker-service -o json 2>&1 | ConvertFrom-Json
        
        $pods = @()
        foreach ($pod in $podsJson.items) {
            $pods += @{
                Name = $pod.metadata.name
                Status = $pod.status.phase
                Ready = "$($pod.status.containerStatuses[0].ready)"
                Restarts = $pod.status.containerStatuses[0].restartCount
                Age = ((Get-Date) - [DateTime]$pod.metadata.creationTimestamp).ToString("hh\:mm\:ss")
            }
        }
        
        return @{
            Success = $true
            Pods = $pods
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-ScalingEvents {
    try {
        $events = kubectl get events -n $Namespace --field-selector involvedObject.name=$HpaName --sort-by='.lastTimestamp' 2>&1 | Out-String
        return @{
            Success = $true
            Events = $events
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Display-Dashboard {
    param($hpaStatus, $podStatus, $timestamp)
    
    Clear-Host
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  HPA Scaling Monitor" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Time:       $timestamp" -ForegroundColor White
    Write-Host "Namespace:  $Namespace" -ForegroundColor White
    Write-Host "HPA Name:   $HpaName" -ForegroundColor White
    Write-Host ""
    
    if ($hpaStatus.Success) {
        Write-Host "HPA Status:" -ForegroundColor Yellow
        Write-Host "  Current Replicas:  $($hpaStatus.CurrentReplicas)" -ForegroundColor White
        Write-Host "  Desired Replicas:  $($hpaStatus.DesiredReplicas)" -ForegroundColor $(
            if ($hpaStatus.DesiredReplicas -gt $hpaStatus.CurrentReplicas) { "Green" } 
            elseif ($hpaStatus.DesiredReplicas -lt $hpaStatus.CurrentReplicas) { "Yellow" }
            else { "White" }
        )
        Write-Host "  Min / Max:         $($hpaStatus.MinReplicas) / $($hpaStatus.MaxReplicas)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "CPU Metrics:" -ForegroundColor Yellow
        Write-Host "  Current:  $($hpaStatus.CPUCurrent)" -ForegroundColor White
        Write-Host "  Target:   $($hpaStatus.CPUTarget)" -ForegroundColor White
        
        if ($hpaStatus.LastScaleTime) {
            $scaleTime = [DateTime]$hpaStatus.LastScaleTime
            $timeSince = ((Get-Date) - $scaleTime).ToString("hh\:mm\:ss")
            Write-Host "  Last Scale: $timeSince ago" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Scaling status indicator
        if ($hpaStatus.CurrentReplicas -lt $hpaStatus.DesiredReplicas) {
            Write-Host "↗ Scaling UP: Adding $($hpaStatus.DesiredReplicas - $hpaStatus.CurrentReplicas) pod(s)..." -ForegroundColor Green
        } elseif ($hpaStatus.CurrentReplicas -gt $hpaStatus.DesiredReplicas) {
            Write-Host "↘ Scaling DOWN: Removing $($hpaStatus.CurrentReplicas - $hpaStatus.DesiredReplicas) pod(s)..." -ForegroundColor Yellow
        } elseif ($hpaStatus.CurrentReplicas -eq $hpaStatus.MaxReplicas) {
            Write-Host "⚠ At MAX capacity ($($hpaStatus.MaxReplicas) pods)" -ForegroundColor Red
        } elseif ($hpaStatus.CurrentReplicas -eq $hpaStatus.MinReplicas) {
            Write-Host "✓ At MIN capacity ($($hpaStatus.MinReplicas) pod)" -ForegroundColor Green
        } else {
            Write-Host "✓ Stable at $($hpaStatus.CurrentReplicas) pods" -ForegroundColor Green
        }
        Write-Host ""
    } else {
        Write-Host "✗ Failed to retrieve HPA status" -ForegroundColor Red
        Write-Host "Error: $($hpaStatus.Error)" -ForegroundColor Red
        Write-Host ""
    }
    
    if ($podStatus.Success -and $podStatus.Pods.Count -gt 0) {
        Write-Host "Worker Pods:" -ForegroundColor Yellow
        Write-Host "  NAME                                   STATUS      READY   RESTARTS   AGE" -ForegroundColor Gray
        
        foreach ($pod in $podStatus.Pods) {
            $color = if ($pod.Status -eq "Running") { "Green" } else { "Yellow" }
            $readyColor = if ($pod.Ready -eq "True") { "Green" } else { "Red" }
            
            $name = $pod.Name.PadRight(40)
            $status = $pod.Status.PadRight(10)
            $ready = $pod.Ready.PadRight(6)
            $restarts = $pod.Restarts.ToString().PadRight(9)
            $age = $pod.Age
            
            Write-Host "  " -NoNewline
            Write-Host $name -ForegroundColor $color -NoNewline
            Write-Host " " -NoNewline
            Write-Host $ready -ForegroundColor $readyColor -NoNewline
            Write-Host "  $restarts  $age" -ForegroundColor White
        }
        Write-Host ""
    }
    
    Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Gray
    Write-Host "Refreshing in $RefreshInterval seconds..." -ForegroundColor Gray
}

# Main execution
Write-Host "Connecting to Kubernetes cluster..." -ForegroundColor Yellow
Write-Host ""

# Verify kubectl access
try {
    kubectl cluster-info | Out-Null
} catch {
    Write-Host "✗ Failed to connect to Kubernetes cluster" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host "  - kubectl is installed" -ForegroundColor White
    Write-Host "  - Cluster credentials are configured" -ForegroundColor White
    Write-Host "  - Namespace '$Namespace' exists" -ForegroundColor White
    exit 1
}

Write-Host "✓ Connected to cluster" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 1

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hpaStatus = Get-HPAStatus
    $podStatus = Get-PodStatus
    Display-Dashboard -hpaStatus $hpaStatus -podStatus $podStatus -timestamp $timestamp
    Start-Sleep -Seconds $RefreshInterval
}
