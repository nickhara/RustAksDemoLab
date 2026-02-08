# Dev Container Environment Validation Script
# PowerShell version for Windows environments

param(
    [switch]$Verbose
)

# Colors for output (if supported)
$script:PassedCount = 0
$script:FailedCount = 0

function Write-Header {
    param([string]$Text)
    Write-Host "`n🔍 $Text" -ForegroundColor Blue
    Write-Host "----------------------------------------" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
    $script:PassedCount++
}

function Write-Failure {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
    $script:FailedCount++
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠️ $Text" -ForegroundColor Yellow
}

function Test-Command {
    param(
        [string]$Command,
        [string]$Description,
        [string]$VersionCommand = "$Command --version"
    )
    
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            $version = Invoke-Expression $VersionCommand 2>$null | Select-Object -First 1
            Write-Success "$Description : $version"
            return $true
        } else {
            Write-Failure "$Description : Command not found"
            return $false
        }
    } catch {
        Write-Failure "$Description : Error checking version"
        return $false
    }
}

# Header
Write-Host @"

╔══════════════════════════════════════════════════╗
║        Dev Container Validation Script           ║
║          Rust AKS Demo Lab Environment           ║
║              PowerShell Version                  ║
╚══════════════════════════════════════════════════╝

"@ -ForegroundColor Blue

# Check environment
Write-Header "Environment Check"

# Check if we're in the expected directory
$currentPath = Get-Location
if ($currentPath -like "*RustAksDemoLab*") {
    Write-Success "Working directory: $currentPath"
} else {
    Write-Warning "Working directory might not be correct: $currentPath"
}

# Check for dev container indicators
if (Test-Path "/.dockerenv" -PathType Leaf) {
    Write-Success "Running in containerized environment"
} elseif ($env:USER -eq "codespace" -or $env:USER -eq "vscode") {
    Write-Success "Running in dev container environment (User: $($env:USER))"
} else {
    Write-Warning "May not be running in expected dev container environment"
}

# Development Tools Validation
Write-Header "Development Tools"

# Rust ecosystem
Test-Command "rustc" "Rust Compiler" | Out-Null
Test-Command "cargo" "Cargo Package Manager" | Out-Null

# Check Rust components
try {
    if (Get-Command rustup -ErrorAction SilentlyContinue) {
        $components = rustup component list --installed
        if ($components -match "rustfmt") {
            Write-Success "Rust formatter: rustfmt installed"
        } else {
            Write-Failure "Rust formatter: rustfmt not installed"
        }
        
        if ($components -match "clippy") {
            Write-Success "Rust linter: clippy installed"
        } else {
            Write-Failure "Rust linter: clippy not installed"
        }
    }
} catch {
    Write-Failure "Error checking Rust components"
}

# .NET ecosystem
Test-Command "dotnet" ".NET SDK" | Out-Null

# Check .NET global tools
try {
    $globalTools = dotnet tool list -g
    if ($globalTools -match "dotnet-ef") {
        Write-Success ".NET Entity Framework tools installed"
    } else {
        Write-Warning ".NET Entity Framework tools not found"
    }
} catch {
    Write-Warning "Could not check .NET global tools"
}

# Container tools
Test-Command "docker" "Docker" | Out-Null
Test-Command "docker-compose" "Docker Compose" | Out-Null

# Kubernetes tools
Test-Command "kubectl" "Kubernetes CLI" "kubectl version --client --short" | Out-Null

# Azure tools
if (Get-Command az -ErrorAction SilentlyContinue) {
    try {
        $azVersion = (az --version | Select-Object -First 1) -replace 'azure-cli\s+', ''
        Write-Success "Azure CLI: $azVersion"
        
        # Check Bicep
        $bicepVersion = az bicep version
        if ($bicepVersion) {
            $bicepVer = ($bicepVersion -split ' ')[-1]
            Write-Success "Bicep: $bicepVer"
        } else {
            Write-Failure "Bicep: Not installed or not working"
        }
    } catch {
        Write-Failure "Azure CLI: Error checking version"
    }
} else {
    Write-Failure "Azure CLI: Command not found"
}

# PowerShell
Test-Command "pwsh" "PowerShell Core" | Out-Null

# Project Build Validation
Write-Header "Project Build Tests"

$originalLocation = Get-Location

# Test Rust API
if (Test-Path "src\rust-api" -PathType Container) {
    try {
        Set-Location "src\rust-api"
        $result = cargo check --quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Rust API: cargo check passed"
        } else {
            Write-Failure "Rust API: cargo check failed"
        }
    } catch {
        Write-Failure "Rust API: Error running cargo check"
    } finally {
        Set-Location $originalLocation
    }
} else {
    Write-Warning "Rust API: src\rust-api directory not found"
}

# Test C# API
if (Test-Path "src\csharp-api" -PathType Container) {
    try {
        Set-Location "src\csharp-api"
        $result = dotnet build --verbosity quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "C# API: dotnet build passed"
        } else {
            Write-Failure "C# API: dotnet build failed"
        }
    } catch {
        Write-Failure "C# API: Error running dotnet build"
    } finally {
        Set-Location $originalLocation
    }
} else {
    Write-Warning "C# API: src\csharp-api directory not found"
}

# Test Worker Service
if (Test-Path "src\worker-service\WorkerService" -PathType Container) {
    try {
        Set-Location "src\worker-service\WorkerService"
        $result = dotnet build --verbosity quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Worker Service: dotnet build passed"
        } else {
            Write-Failure "Worker Service: dotnet build failed"
        }
    } catch {
        Write-Failure "Worker Service: Error running dotnet build"
    } finally {
        Set-Location $originalLocation
    }
} else {
    Write-Warning "Worker Service: src\worker-service\WorkerService directory not found"
}

# Test solution build
if (Test-Path "src\RustKubernetesDemo.sln" -PathType Leaf) {
    try {
        Set-Location "src"
        $result = dotnet build --verbosity quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Solution: dotnet build passed"
        } else {
            Write-Failure "Solution: dotnet build failed"
        }
    } catch {
        Write-Failure "Solution: Error running dotnet build"
    } finally {
        Set-Location $originalLocation
    }
}

# Infrastructure Validation
Write-Header "Infrastructure & Configuration"

# Test Kubernetes manifests
if (Test-Path "k8s" -PathType Container) {
    $manifestFiles = Get-ChildItem "k8s\*.yaml" -ErrorAction SilentlyContinue
    $manifestCount = $manifestFiles.Count
    $validManifests = 0
    
    foreach ($manifest in $manifestFiles) {
        try {
            $result = kubectl apply --dry-run=client --validate=true -f $manifest.FullName 2>$null
            if ($LASTEXITCODE -eq 0) {
                $validManifests++
            }
        } catch {
            # Manifest validation failed
        }
    }
    
    if ($validManifests -eq $manifestCount -and $manifestCount -gt 0) {
        Write-Success "Kubernetes manifests: All $manifestCount manifests valid"
    } elseif ($manifestCount -gt 0) {
        Write-Failure "Kubernetes manifests: $validManifests/$manifestCount valid"
    } else {
        Write-Warning "Kubernetes manifests: No YAML files found in k8s\"
    }
} else {
    Write-Warning "Kubernetes manifests: k8s\ directory not found"
}

# Test Bicep templates
if (Test-Path "infra\main.bicep" -PathType Leaf) {
    try {
        $result = az bicep build --file infra\main.bicep 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Bicep template: main.bicep compiles successfully"
        } else {
            Write-Failure "Bicep template: main.bicep compilation failed"
        }
    } catch {
        Write-Failure "Bicep template: Error compiling main.bicep"
    }
} else {
    Write-Warning "Bicep template: infra\main.bicep not found"
}

# Development Services
Write-Header "Development Services"

if (Test-Path "docker-compose.yml" -PathType Leaf) {
    Write-Host "Starting development services..." -ForegroundColor Yellow
    try {
        $result = docker-compose up -d 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose: Services started"
            
            # Wait for services to initialize
            Start-Sleep -Seconds 5
            
            # Check RabbitMQ Management UI
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:15672" -TimeoutSec 5 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-Success "RabbitMQ: Management UI accessible on port 15672"
                }
            } catch {
                Write-Failure "RabbitMQ: Management UI not accessible"
            }
            
            # Check RabbitMQ AMQP port
            try {
                $connection = Test-NetConnection -ComputerName localhost -Port 5672 -InformationLevel Quiet -ErrorAction SilentlyContinue
                if ($connection) {
                    Write-Success "RabbitMQ: AMQP port 5672 listening"
                } else {
                    Write-Failure "RabbitMQ: AMQP port 5672 not available"
                }
            } catch {
                Write-Warning "RabbitMQ: Could not test AMQP port 5672"
            }
        } else {
            Write-Failure "Docker Compose: Failed to start services"
        }
    } catch {
        Write-Failure "Docker Compose: Error starting services"
    }
} else {
    Write-Warning "Docker Compose: docker-compose.yml not found"
}

# Environment Variables
Write-Header "Environment Configuration"

$envVars = @{
    "RUST_LOG" = "debug"
    "DOTNET_NOLOGO" = "true"
    "DOTNET_CLI_TELEMETRY_OPTOUT" = "true"
    "DOTNET_SKIP_FIRST_TIME_EXPERIENCE" = "true"
}

foreach ($envVar in $envVars.GetEnumerator()) {
    $actualValue = [Environment]::GetEnvironmentVariable($envVar.Key)
    if ($actualValue -eq $envVar.Value) {
        Write-Success "Environment: $($envVar.Key)=$actualValue"
    } else {
        Write-Warning "Environment: $($envVar.Key)=$actualValue (expected: $($envVar.Value))"
    }
}

# Final Summary
Write-Header "Validation Summary"

$total = $script:PassedCount + $script:FailedCount
Write-Host "Tests run: $total"
Write-Host "Passed: " -NoNewline; Write-Host $script:PassedCount -ForegroundColor Green

if ($script:FailedCount -gt 0) {
    Write-Host "Failed: " -NoNewline; Write-Host $script:FailedCount -ForegroundColor Red
    Write-Host ""
    Write-Warning "Some validations failed. Check the output above for details."
    Write-Host "Common solutions:" -ForegroundColor Yellow
    Write-Host "  • Rebuild dev container: Command Palette → 'Dev Containers: Rebuild Container'"
    Write-Host "  • Check Docker Desktop is running"
    Write-Host "  • Verify internet connectivity for downloads"
    Write-Host "  • Review VS Code dev container logs"
    exit 1
} else {
    Write-Host "Failed: " -NoNewline; Write-Host "0" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 All validations passed! Your dev container is ready for development." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  • Start with Lab 1: docs\LabExperimentGuide.md"
    Write-Host "  • Or try Lab 2: docs\Lab2-MessageQueue.md"
    Write-Host "  • RabbitMQ Management UI: http://localhost:15672 (admin/admin123)"
    exit 0
}