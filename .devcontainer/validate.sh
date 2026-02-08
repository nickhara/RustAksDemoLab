#!/bin/bash

# Dev Container Environment Validation Script
# This script validates that all components are properly configured

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}🔍 $1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

print_failure() {
    echo -e "${RED}❌${NC} $1"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

check_command() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=$($cmd --version 2>/dev/null | head -n1 | cut -d' ' -f1-3)
        print_success "$description: $version"
        return 0
    else
        print_failure "$description: Command not found"
        return 1
    fi
}

check_version() {
    local cmd=$1
    local description=$2
    local version_cmd=$3
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version=$(eval "$version_cmd" 2>/dev/null)
        print_success "$description: $version"
        return 0
    else
        print_failure "$description: Command not found"
        return 1
    fi
}

# Start validation
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║        Dev Container Validation Script           ║"
echo "║          Rust AKS Demo Lab Environment           ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if we're in the dev container
if [ "$USER" = "codespace" ] || [ "$USER" = "vscode" ] || [ -f /.dockerenv ]; then
    print_success "Running in dev container environment"
else
    print_warning "Not running in expected dev container environment (USER: $USER)"
fi

# Check working directory
if [[ $PWD == *"RustAksDemoLab"* ]]; then
    print_success "Working directory: $PWD"
else
    print_warning "Working directory might not be correct: $PWD"
fi

# 1. Development Tools Validation
print_header "Development Tools"

# Rust ecosystem
check_version "rustc" "Rust Compiler" "rustc --version"
check_version "cargo" "Cargo Package Manager" "cargo --version"

if command -v rustup >/dev/null 2>&1; then
    if rustup component list --installed | grep -q "rustfmt"; then
        print_success "Rust formatter: rustfmt installed"
    else
        print_failure "Rust formatter: rustfmt not installed"
    fi
    
    if rustup component list --installed | grep -q "clippy"; then
        print_success "Rust linter: clippy installed"
    else
        print_failure "Rust linter: clippy not installed"
    fi
fi

# .NET ecosystem
check_version "dotnet" ".NET SDK" "dotnet --version"

# Check .NET global tools
if dotnet tool list -g | grep -q "dotnet-ef"; then
    print_success ".NET Entity Framework tools installed"
else
    print_warning ".NET Entity Framework tools not found"
fi

# Container and orchestration tools
check_version "docker" "Docker" "docker --version"
check_version "docker-compose" "Docker Compose" "docker-compose --version"

# Kubernetes tools
check_version "kubectl" "Kubernetes CLI" "kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -n1 | cut -d'\"' -f4"

# Azure tools
if command -v az >/dev/null 2>&1; then
    azure_version=$(az --version | head -n1 | cut -d' ' -f2)
    print_success "Azure CLI: $azure_version"
    
    # Check Bicep
    if az bicep version >/dev/null 2>&1; then
        bicep_version=$(az bicep version | grep -o 'Bicep CLI version [0-9.]*' | cut -d' ' -f4)
        print_success "Bicep: $bicep_version"
    else
        print_failure "Bicep: Not installed or not working"
    fi
else
    print_failure "Azure CLI: Command not found"
fi

# PowerShell
check_version "pwsh" "PowerShell" "pwsh --version"

# 2. Project Build Validation
print_header "Project Build Tests"

ORIGINAL_DIR=$PWD

# Test Rust API
if [ -d "src/rust-api" ]; then
    cd src/rust-api
    if cargo check --quiet >/dev/null 2>&1; then
        print_success "Rust API: cargo check passed"
    else
        print_failure "Rust API: cargo check failed"
    fi
    cd "$ORIGINAL_DIR"
else
    print_warning "Rust API: src/rust-api directory not found"
fi

# Test C# API
if [ -d "src/csharp-api" ]; then
    cd src/csharp-api
    if dotnet build --verbosity quiet >/dev/null 2>&1; then
        print_success "C# API: dotnet build passed"
    else
        print_failure "C# API: dotnet build failed"
    fi
    cd "$ORIGINAL_DIR"
else
    print_warning "C# API: src/csharp-api directory not found"
fi

# Test Worker Service
if [ -d "src/worker-service/WorkerService" ]; then
    cd src/worker-service/WorkerService
    if dotnet build --verbosity quiet >/dev/null 2>&1; then
        print_success "Worker Service: dotnet build passed"
    else
        print_failure "Worker Service: dotnet build failed"
    fi
    cd "$ORIGINAL_DIR"
else
    print_warning "Worker Service: src/worker-service/WorkerService directory not found"
fi

# Test solution build
if [ -f "src/RustKubernetesDemo.sln" ]; then
    cd src
    if dotnet build --verbosity quiet >/dev/null 2>&1; then
        print_success "Solution: dotnet build passed"
    else
        print_failure "Solution: dotnet build failed"
    fi
    cd "$ORIGINAL_DIR"
fi

# 3. Infrastructure Validation
print_header "Infrastructure & Configuration"

# Test Kubernetes manifests
if [ -d "k8s" ]; then
    manifest_count=0
    valid_manifests=0
    
    for manifest in k8s/*.yaml; do
        if [ -f "$manifest" ]; then
            ((manifest_count++))
            if kubectl apply --dry-run=client --validate=true -f "$manifest" >/dev/null 2>&1; then
                ((valid_manifests++))
            fi
        fi
    done
    
    if [ $valid_manifests -eq $manifest_count ] && [ $manifest_count -gt 0 ]; then
        print_success "Kubernetes manifests: All $manifest_count manifests valid"
    elif [ $manifest_count -gt 0 ]; then
        print_failure "Kubernetes manifests: $valid_manifests/$manifest_count valid"
    else
        print_warning "Kubernetes manifests: No YAML files found in k8s/"
    fi
else
    print_warning "Kubernetes manifests: k8s/ directory not found"
fi

# Test Bicep templates
if [ -f "infra/main.bicep" ]; then
    if az bicep build --file infra/main.bicep >/dev/null 2>&1; then
        print_success "Bicep template: main.bicep compiles successfully"
    else
        print_failure "Bicep template: main.bicep compilation failed"
    fi
else
    print_warning "Bicep template: infra/main.bicep not found"
fi

# 4. Development Services
print_header "Development Services"

# Start services if docker-compose file exists
if [ -f "docker-compose.yml" ]; then
    echo "Starting development services..."
    if docker-compose up -d >/dev/null 2>&1; then
        print_success "Docker Compose: Services started"
        
        # Wait a moment for services to initialize
        sleep 5
        
        # Check RabbitMQ
        if curl -f http://localhost:15672 >/dev/null 2>&1; then
            print_success "RabbitMQ: Management UI accessible on port 15672"
        else
            print_failure "RabbitMQ: Management UI not accessible"
        fi
        
        # Check if AMQP port is listening
        if netstat -tuln 2>/dev/null | grep -q ":5672 "; then
            print_success "RabbitMQ: AMQP port 5672 listening"
        else
            print_failure "RabbitMQ: AMQP port 5672 not available"
        fi
        
    else
        print_failure "Docker Compose: Failed to start services"
    fi
else
    print_warning "Docker Compose: docker-compose.yml not found"
fi

# 5. Environment Variables
print_header "Environment Configuration"

# Check dev container specific environment variables
env_vars=(
    "RUST_LOG:debug"
    "DOTNET_NOLOGO:true"
    "DOTNET_CLI_TELEMETRY_OPTOUT:true"
    "DOTNET_SKIP_FIRST_TIME_EXPERIENCE:true"
)

for env_var in "${env_vars[@]}"; do
    var_name="${env_var%:*}"
    expected_value="${env_var#*:}"
    actual_value="${!var_name}"
    
    if [ "$actual_value" = "$expected_value" ]; then
        print_success "Environment: $var_name=$actual_value"
    else
        print_warning "Environment: $var_name=$actual_value (expected: $expected_value)"
    fi
done

# 6. VS Code Integration
print_header "VS Code Integration"

# Check if VS Code server is running (indicates we're in VS Code dev container)
if pgrep -f "vscode-server" >/dev/null 2>&1; then
    print_success "VS Code: Server detected (running in VS Code)"
else
    print_warning "VS Code: Server not detected (may not be running in VS Code)"
fi

# Check for dev container indicator files
if [ -f "/vscode-dev-container-indicator" ]; then
    print_success "Dev Container: Official dev container indicator found"
elif [ -f "/.devcontainer-indicator" ]; then
    print_success "Dev Container: Custom dev container indicator found"
else
    print_warning "Dev Container: No container indicator found"
fi

# 7. Network and Ports
print_header "Network & Port Configuration"

# Check if common development ports are available or in use appropriately
ports=(5672 15672 8080 5000 5001)

for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        print_success "Port $port: In use (likely by development service)"
    else
        print_warning "Port $port: Not in use"
    fi
done

# Final Summary
print_header "Validation Summary"

total=$((PASSED + FAILED))
echo "Tests run: $total"
echo -e "Passed: ${GREEN}$PASSED${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "Failed: ${RED}$FAILED${NC}"
    echo ""
    echo -e "${YELLOW}Some validations failed. Check the output above for details.${NC}"
    echo "Common solutions:"
    echo "  • Rebuild dev container: Command Palette → 'Dev Containers: Rebuild Container'"
    echo "  • Check Docker Desktop is running"
    echo "  • Verify internet connectivity for downloads"
    echo "  • Review VS Code dev container logs"
    exit 1
else
    echo -e "Failed: ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}🎉 All validations passed! Your dev container is ready for development.${NC}"
    echo ""
    echo "Next steps:"
    echo "  • Start with Lab 1: docs/LabExperimentGuide.md"
    echo "  • Or try Lab 2: docs/Lab2-MessageQueue.md"
    echo "  • RabbitMQ Management UI: http://localhost:15672 (admin/admin123)"
    exit 0
fi