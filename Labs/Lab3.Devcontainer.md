# Lab 3: Devcontainer Development Modes and Cloud-Native Workflows

Building upon the microservices architecture from Labs 1 and 2, this lab introduces advanced development
workflows using Visual Studio Code devcontainers. Learn how to leverage containerized development environments
for cloud-native applications, master different development modes, and establish efficient code-to-cloud
deployment pipelines.

This lab covers:

- **Devcontainer Environment** - Complete containerized development setup with all tools pre-configured
- **Direct Development Mode** - Native execution within the devcontainer for rapid iteration
- **Local Kubernetes Mode** - Production-like testing with local cluster deployment
- **Azure Production Deployment** - End-to-end deployment pipeline to Azure Kubernetes Service
- **Development Workflow Integration** - Best practices for switching between modes efficiently

This lab demonstrates modern cloud-native development practices including containerized development
environments, dual-mode workflows, and seamless progression from local development to production deployment.

## Lab Version

This lab is stabilized on the **`lab3-v1.0`** tag and the **`labs/lab3`** branch.

To follow this lab against a known-good snapshot of the repository:

```powershell
git fetch --tags
git checkout lab3-v1.0
```

To make changes while following along, create a working branch from the tag:

```powershell
git checkout -b my-lab3-work lab3-v1.0
```

For the latest in-progress version of the lab, use the `main` branch or the long-lived `labs/lab3` branch (which tracks the tip of this lab).

## Table of Contents

- [Lab Version](#lab-version)
- [Prerequisites](#prerequisites)
- [Development Environment Architecture](#development-environment-architecture)
- [Devcontainer Deep Dive](#devcontainer-deep-dive)
- [Setup and Verification](#setup-and-verification)
- [Development Mode Selection](#development-mode-selection)
- [Direct Development Mode](#direct-development-mode)
- [Local Kubernetes Development Mode](#local-kubernetes-development-mode)
- [Azure Kubernetes Service Deployment](#azure-kubernetes-service-deployment)
- [Production Verification and Monitoring](#production-verification-and-monitoring)
- [Development Workflow Best Practices](#development-workflow-best-practices)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Quick Reference](#quick-reference)

## Prerequisites

This lab builds upon Labs 1 and 2. You must complete both previous labs to have the required infrastructure and understanding.

### Required from Previous Labs

- Azure Container Registry (ACR) deployed and configured
- AKS Cluster running with RabbitMQ, Rust API, and Worker Service
- kubectl configured for your AKS cluster
- Docker Desktop installed and running
- Azure CLI authenticated
- Understanding of Kubernetes concepts and RabbitMQ message flows

### Development Tools

| Tool | Purpose | Installation Check |
| ---- | ------- | ------------------ |
| Visual Studio Code | Primary development environment | `code --version` |
| Docker Desktop | Container runtime and Kubernetes | `docker --version && kubectl version --client` |
| Dev Containers Extension | VS Code devcontainer support | Check VS Code extensions |
| PowerShell 7+ | Automation scripts | `$PSVersionTable.PSVersion` |

### Verify Previous Lab Infrastructure

```powershell
# Set your variables from previous labs
$RESOURCE_GROUP = "rg-hello-apis"
$CLUSTER_NAME = "aks-hello-apis"
$ACR_NAME = "acrhelloapis<your-unique-suffix>"  # Replace with your actual ACR name

# Verify Azure resources exist
Write-Host "Checking Azure infrastructure..." -ForegroundColor Green
az group show --name $RESOURCE_GROUP --query "name" -o tsv
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "name" -o tsv
az acr show --name $ACR_NAME --query "name" -o tsv

# Check kubectl connection
Write-Host "Verifying Kubernetes connectivity..." -ForegroundColor Green
kubectl cluster-info
kubectl get nodes
kubectl get pods -n hello-apis

# Verify services from Lab 2 are running
Write-Host "Checking Lab 2 services..." -ForegroundColor Green
kubectl get pods -n hello-apis | grep -E "(rust-api|worker-service|rabbitmq)"
```

## Development Environment Architecture

### Devcontainer Components

The development environment provides a complete, reproducible setup for cloud-native development:

| Component | Technology | Purpose |
| ----------- | ------------ | --------- |
| **Base Image** | `mcr.microsoft.com/devcontainers/universal:2` | Ubuntu-based container with common dev tools |
| **Languages** | Rust (latest), .NET 10, PowerShell 7 | Multi-language development support |
| **Cloud Tools** | Azure CLI, kubectl, helm, bicep CLI | Azure and Kubernetes management |
| **Development Tools** | Git, Docker CLI, VS Code extensions | Complete development workflow |

### Development Mode Architectures

#### Direct Development Mode (Default)

```text
┌─────────────────────────────────────────┐
│           VS Code Devcontainer          │
├─────────────────────────────────────────┤
│  Rust API (8080)    C# Worker Service   │
│  ↓                  ↑                   │
│  RabbitMQ (Docker Container - 5672)     │
└─────────────────────────────────────────┘
```

#### Local Kubernetes Mode

```text
┌──────────────────────────────────────────┐
│           VS Code Devcontainer           │
├──────────────────────────────────────────┤
│               kubectl                    │
│                 ↓                        │
│        Local Kubernetes Cluster          │
│  ┌─────────┐ ┌─────────┐ ┌─────────────┐ │
│  │Rust API │ │RabbitMQ │ │Worker Svc   │ │
│  │(:local) │ │         │ │(:local)     │ │
│  └─────────┘ └─────────┘ └─────────────┘ │
└──────────────────────────────────────────┘
```

#### Azure Production Mode

```text
┌──────────────────────────────────────────┐
│           VS Code Devcontainer           │
├──────────────────────────────────────────┤
│            Azure CLI + kubectl           │
│                 ↓                        │
│           Azure Cloud (AKS)              │
│  ┌─────────┐ ┌─────────┐ ┌─────────────┐ │
│  │Rust API │ │RabbitMQ │ │Worker Svc   │ │
│  │(ACR)    │ │         │ │(ACR) + HPA  │ │
│  └─────────┘ └─────────┘ └─────────────┘ │
└──────────────────────────────────────────┘
```

## Devcontainer Deep Dive

The devcontainer configuration provides a complete development environment with all necessary tools pre-installed and configured.

### Container Configuration Analysis

Let's examine the devcontainer setup:

```bash
# Navigate to the devcontainer directory
cd .devcontainer

# Examine the devcontainer configuration
cat devcontainer.json
```

**Key Configuration Elements:**

1. **Base Image**: Ubuntu-based universal image with common development tools
2. **Features**: Automatic installation of Rust, .NET, Azure CLI, and Kubernetes tools
3. **Extensions**: 20+ VS Code extensions for multi-language development
4. **Port Forwarding**: Pre-configured for RabbitMQ (5672, 15672) and APIs (8080, 5000)
5. **Mount Points**: Source code and Docker socket mounted for development

### Pre-installed Extensions

The devcontainer includes essential extensions for cloud-native development:

| Category | Extensions | Purpose |
| ---------- | ----------- | --------- |
| **Languages** | rust-analyzer, C# DevKit | Rust and C# development support |
| **Containers** | Docker, Kubernetes | Container and orchestration management |
| **Azure** | Azure CLI Tools, Bicep | Azure resource management |
| **Development** | GitLens, REST Client | Enhanced development workflow |

### Development Scripts Overview

The devcontainer includes several automation scripts:

```bash
# List available development scripts
ls -la .devcontainer/*.sh

# Examine the mode selector script
cat .devcontainer/dev-mode-selector.sh
```

**Available Scripts:**

- `dev-mode-selector.sh` - Interactive menu for development mode selection
- `start-dev.sh` - Automated setup for direct development mode
- `build-local-images.sh` - Build container images for local Kubernetes
- `k8s-port-forward.sh` - Setup port forwarding for local Kubernetes
- `k8s-status.sh` - Check local Kubernetes deployment status

## Setup and Verification

### Step 1: Open Project in Devcontainer

1. **Clone Repository** (if not already cloned):

   ```bash
   git clone <repository-url>
   cd RustAksDemoLab
   ```

2. **Open in VS Code**:

   ```bash
   code .
   ```

3. **Reopen in Container**:
   - VS Code should prompt to "Reopen in Container"
   - Or use Command Palette: `Dev Containers: Reopen in Container`
   - Wait for container build to complete (initial build may take 5-10 minutes)

### Step 2: Verify Development Environment

Once the devcontainer is running, verify all tools are available:

```bash
# Verify language runtimes
echo "=== Language Runtimes ==="
rustc --version
dotnet --version
pwsh --version

# Verify cloud tools
echo "=== Cloud Tools ==="
az --version | head -1
kubectl version --client
bicep --version

# Verify container tools
echo "=== Container Tools ==="
docker --version
docker-compose --version

# Check extensions are loaded
echo "=== VS Code Extensions ==="
code --list-extensions | grep -E "(rust|csharp|azure|docker|kubernetes)"
```

### Step 3: Verify Project Structure

```bash
# Examine project structure
echo "=== Project Structure ==="
ls -la

# Check source directories
echo "=== Source Code ==="
find src -name "*.rs" -o -name "*.cs" -o -name "*.csproj" | head -10

# Verify configuration files
echo "=== Configuration Files ==="
ls -la .devcontainer/
ls -la src/k8s/local/
ls -la docker-compose.yml
```

### Step 4: Test VS Code Task Integration

```bash
# View available VS Code tasks
echo "=== Available Tasks ==="
grep -A 5 '"label":' .vscode/tasks.json | grep label
```

Open VS Code Command Palette (`Ctrl+Shift+P`) and run:

- `Tasks: Run Task` to see all available development tasks
- Verify tasks like "Start Infrastructure", "Build Rust API", etc. are available

## Development Mode Selection

The development environment supports multiple modes optimized for different scenarios.
Let's explore the automated mode selector:

### Interactive Mode Selection

```bash
# Run the development mode selector
./.devcontainer/dev-mode-selector.sh
```

The script presents an interactive menu:

```text
🚀 Development Mode Selector
============================

Select your development mode:

1) 🖥️  Direct Development (Default)
   - Run services natively in devcontainer
   - Fast iteration and debugging
   - Uses Docker Compose for infrastructure

2) ☸️  Local Kubernetes
   - Deploy to local K8s cluster
   - Production-like testing
   - Uses local container images

3) ☁️  Azure Development
   - Work with remote AKS cluster
   - Production debugging and testing
   - Uses Azure Container Registry

4) 📊 View Current Status
   - Check running services
   - Port forwarding status
   - Resource utilization

Enter your choice [1-4]:
```

### Manual Mode Understanding

Each development mode serves specific purposes:

| Mode | Use Case | Benefits | Trade-offs |
| ------ | ---------- | ---------- | ------------ |
| **Direct** | Active development, debugging | Hot reload, native debugger, low resources | Not production-like |
| **Local K8s** | Integration testing, K8s validation | Production-like, full K8s features | Higher resource usage |
| **Azure** | Production testing, remote debugging | Real cloud environment | Network latency, costs |

### Mode Comparison

```bash
# Check current development status
echo "=== Current Development Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -5
kubectl get pods -A 2>/dev/null | grep -E "(rust|worker|rabbitmq)" || echo "No local K8s pods"
```

## Direct Development Mode

Direct development mode runs services natively within the devcontainer for fastest iteration cycles.

### Step 1: Start Infrastructure Services

```bash
# Start RabbitMQ using Docker Compose
echo "Starting RabbitMQ infrastructure..."
docker-compose up -d rabbitmq

# Verify RabbitMQ is running
docker ps | grep rabbitmq
docker-compose logs rabbitmq | tail -5

# Wait for RabbitMQ to be ready
echo "Waiting for RabbitMQ to be ready..."
timeout 60 bash -c 'until docker-compose logs rabbitmq | grep "Server startup complete"; do sleep 2; done'
echo "RabbitMQ is ready!"
```

### Step 2: Start Application Services

Use VS Code tasks for streamlined service management:

1. **Open VS Code Command Palette** (`Ctrl+Shift+P`)
2. **Run Task**: `Tasks: Run Task`
3. **Select**: `Start All Services`

Or manually start services:

```bash
# Start Rust API in background
echo "Starting Rust API..."
cd src/rust-api
RUST_LOG=debug PORT=8080 RABBITMQ_URL=amqp://admin:admin123@localhost:5672 RABBITMQ_QUEUE=task-queue \
  cargo run &
RUST_PID=$!

# Start C# Worker Service in background  
echo "Starting C# Worker Service..."
cd ../worker-service/WorkerService
DOTNET_ENVIRONMENT=Development \
RabbitMQ__Host=localhost \
RabbitMQ__Port=5672 \
RabbitMQ__Username=admin \
RabbitMQ__Password=admin123 \
RabbitMQ__Queue=task-queue \
ProcessingDelayMs=2000 \
  dotnet run &
WORKER_PID=$!

echo "Services started - Rust API: $RUST_PID, Worker: $WORKER_PID"
```

### Step 3: Verify Direct Development Setup

```bash
# Check that services are responsive
echo "=== Testing Rust API ==="
curl -s http://localhost:8080/health | jq .

echo "=== Testing message sending ==="
curl -s -X POST http://localhost:8080/send \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Direct Development Mode!"}' | jq .

# Check RabbitMQ management interface
echo "=== RabbitMQ Management ==="
echo "RabbitMQ Management UI: http://localhost:15672 (admin/admin123)"
curl -s -u admin:admin123 http://localhost:15672/api/overview | jq '.queue_totals'
```

### Step 4: Development Workflow with Hot Reload

1. **Edit Rust Code**:

   ```bash
   # Open Rust API source
   code src/rust-api/src/main.rs
   ```

   - Make a small change (e.g., update health check response)
   - Save the file
   - `cargo` will automatically recompile and reload

2. **Edit C# Code**:

   ```bash
   # Open Worker Service source  
   code src/worker-service/WorkerService/Worker.cs
   ```

   - Make a small change (e.g., update log message)
   - Save the file
   - `dotnet` will automatically recompile and reload

3. **Test Changes**:

   ```bash
   # Test updated Rust API
   curl http://localhost:8080/health

   # Send test message to see updated worker behavior
   curl -X POST http://localhost:8080/send \
     -H "Content-Type: application/json" \
     -d '{"message": "Testing hot reload changes"}'
   ```

### Step 5: Debug with VS Code

1. **Set Breakpoints**: Open source files and click in the gutter to set breakpoints
2. **Attach Debugger**: Use VS Code debug configurations for Rust and C#
3. **Debug Workflow**:
   - Send HTTP requests to trigger breakpoints
   - Inspect variables and step through code
   - Modify code and restart with debugger attached

### Direct Development Benefits

- **Fast Iteration**: No container rebuilds or deployments
- **Native Debugging**: Full IDE debugging capabilities
- **Low Resource Usage**: Minimal overhead compared to containerized execution
- **Hot Reload**: Automatic recompilation on file changes

## Local Kubernetes Development Mode

Local Kubernetes mode deploys all services to your local cluster, providing production-like testing without cloud resources.

### Step 1: Build Local Container Images

```bash
# Build all services as local images
echo "Building local container images..."
./.devcontainer/build-local-images.sh

# Verify images were built with :local tags
echo "=== Local Images Built ==="
docker images | grep ":local"
```

The build script creates local images:

- `rust-api:local` - Rust API service
- `worker-service:local` - C# Worker Service  
- Images use `imagePullPolicy: Never` to prevent external pulls

### Step 2: Deploy to Local Kubernetes

```bash
# Apply local Kubernetes manifests
echo "Deploying to local Kubernetes..."
kubectl apply -f src/k8s/local/

# Wait for deployments to be ready
echo "Waiting for deployments..."
kubectl wait --for=condition=available deployment --all -n default --timeout=300s

# Check deployment status
echo "=== Deployment Status ==="
kubectl get pods -o wide
kubectl get services
```

### Step 3: Setup Port Forwarding

```bash
# Start automated port forwarding
echo "Setting up port forwarding..."
./.devcontainer/k8s-port-forward.sh &
PORT_FORWARD_PID=$!

# Wait for port forwarding to establish
sleep 10

# Verify port forwarding is working
echo "=== Port Forward Status ==="
ps aux | grep "kubectl port-forward" | head -3
netstat -tuln | grep -E "(8080|5672|15672)"
```

**Port Forwarding Setup:**

- `localhost:8080` → `rust-api-service:8080` (Rust API)
- `localhost:5672` → `rabbitmq-service:5672` (RabbitMQ AMQP)
- `localhost:15672` → `rabbitmq-service:15672` (RabbitMQ Management)

### Step 4: Test Local Kubernetes Deployment

```bash
# Test Rust API health
echo "=== Testing Rust API in K8s ==="
curl -s http://localhost:8080/health | jq .

# Test message processing pipeline
echo "=== Testing Message Pipeline ==="
curl -s -X POST http://localhost:8080/send \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Local Kubernetes!"}' | jq .

# Check RabbitMQ management interface
echo "=== RabbitMQ Management ==="
curl -s -u admin:admin123 http://localhost:15672/api/queues | jq '.[] | {name, messages}'

# View worker service logs
echo "=== Worker Service Logs ==="
kubectl logs -l app=worker-service --tail=10
```

### Step 5: Kubernetes-Specific Testing

```bash
# Test pod scaling
echo "=== Testing Pod Scaling ==="
kubectl scale deployment rust-api --replicas=2
kubectl wait --for=condition=available deployment/rust-api --timeout=60s
kubectl get pods -l app=rust-api

# Test pod restart behavior
echo "=== Testing Pod Resilience ==="
kubectl delete pod -l app=worker-service
kubectl wait --for=condition=ready pod -l app=worker-service --timeout=60s

# Check service discovery
echo "=== Service Discovery ==="
kubectl get endpoints
kubectl describe service rust-api-service
```

### Step 6: Monitor Local Deployment

```bash
# Check resource usage
echo "=== Resource Usage ==="
kubectl top pods 2>/dev/null || echo "Metrics server not available"

# View comprehensive status
echo "=== Comprehensive Status ==="
./.devcontainer/k8s-status.sh

# Monitor logs in real-time (optional)
echo "=== Real-time Logs ==="
echo "Use: kubectl logs -f -l app=worker-service"
echo "Use: kubectl logs -f -l app=rust-api"
```

### Local Kubernetes Benefits

- **Production-like Environment**: Identical to production Kubernetes behavior
- **Full K8s Feature Testing**: Services, ingress, scaling, health checks
- **Manifest Validation**: Verify Kubernetes configurations work correctly
- **Integration Testing**: Test inter-service communication through K8s networking

## Azure Kubernetes Service Deployment

Deploy the complete system to Azure for production testing and demonstration of the full cloud-native pipeline.

### Step 1: Prepare Azure Infrastructure

```powershell
# Set deployment variables
$RESOURCE_GROUP = "rg-hello-apis"
$CLUSTER_NAME = "aks-hello-apis" 
$ACR_NAME = "acrhelloapis<your-unique-suffix>"  # Use your actual ACR name
$LOCATION = "East US"

# Verify infrastructure from previous labs
Write-Host "Verifying existing infrastructure..." -ForegroundColor Green
az group show --name $RESOURCE_GROUP
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "name"
az acr show --name $ACR_NAME --query "loginServer"

# Get AKS credentials
Write-Host "Configuring kubectl for AKS..." -ForegroundColor Green
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 2: Build and Push Production Images

```bash
# Login to Azure Container Registry
echo "Logging into Azure Container Registry..."
az acr login --name $ACR_NAME

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"

# Build and tag images for ACR
echo "=== Building Production Images ==="

# Build Rust API
cd src/rust-api
docker build -t $ACR_LOGIN_SERVER/rust-api:latest .
docker push $ACR_LOGIN_SERVER/rust-api:latest

# Build Worker Service
cd ../worker-service/WorkerService
docker build -t $ACR_LOGIN_SERVER/worker-service:latest .
docker push $ACR_LOGIN_SERVER/worker-service:latest

echo "=== Images Built and Pushed ==="
az acr repository list --name $ACR_NAME --output table
```

### Step 3: Configure Production Manifests

```bash
# Navigate back to project root
cd ../../..

# Update Kubernetes manifests with ACR image references
echo "Updating production manifests..."

# Check current manifest configuration
grep -r "image:" src/k8s/ | grep -v local

# Ensure manifests use ACR references (should be pre-configured)
echo "Production manifests should reference: $ACR_LOGIN_SERVER/rust-api:latest"
echo "Production manifests should reference: $ACR_LOGIN_SERVER/worker-service:latest"
```

### Step 4: Deploy to AKS

```bash
# Create namespace if it doesn't exist
kubectl create namespace hello-apis --dry-run=client -o yaml | kubectl apply -f -

# Deploy all services to AKS
echo "Deploying to Azure Kubernetes Service..."
kubectl apply -f src/k8s/ -n hello-apis

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment --all -n hello-apis --timeout=600s

# Check deployment status
echo "=== AKS Deployment Status ==="
kubectl get all -n hello-apis
kubectl get events -n hello-apis --sort-by=.metadata.creationTimestamp | tail -10
```

### Step 5: Expose Services (LoadBalancer)

```bash
# Check service external IPs
echo "=== Checking Service External IPs ==="
kubectl get services -n hello-apis

# Wait for external IP assignment
echo "Waiting for LoadBalancer external IPs..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/rust-api-service -n hello-apis --timeout=300s

# Get service endpoints
RUST_API_IP=$(kubectl get service rust-api-service -n hello-apis -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Rust API External IP: $RUST_API_IP"

# Test external connectivity
echo "=== Testing External Access ==="
curl -s http://$RUST_API_IP:8080/health | jq .
```

### Step 6: Configure Horizontal Pod Autoscaler

```bash
# Verify HPA configuration
echo "=== Horizontal Pod Autoscaler ==="
kubectl get hpa -n hello-apis
kubectl describe hpa worker-service-hpa -n hello-apis

# Check metrics server availability
kubectl get deployment metrics-server -n kube-system

# Monitor current resource usage
echo "=== Current Resource Usage ==="
kubectl top pods -n hello-apis
```

## Production Verification and Monitoring

Thoroughly test the production deployment to ensure all components function correctly under real-world conditions.

### Step 1: End-to-End Functionality Testing

```bash
# Get external service IP
RUST_API_IP=$(kubectl get service rust-api-service -n hello-apis -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "=== Testing Production Endpoints ==="
echo "Rust API URL: http://$RUST_API_IP:8080"

# Test health endpoint
echo "Testing health endpoint..."
curl -s http://$RUST_API_IP:8080/health | jq .

# Test message sending functionality
echo "Testing message pipeline..."
for i in {1..5}; do
  echo "Sending message $i..."
  curl -s -X POST http://$RUST_API_IP:8080/send \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"Production test message $i\"}" | jq .
  sleep 1
done
```

### Step 2: Load Testing and Auto-Scaling

```powershell
# PowerShell script for load testing
$RUST_API_IP = kubectl get service rust-api-service -n hello-apis -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$API_URL = "http://$RUST_API_IP:8080"

Write-Host "Starting load test against $API_URL" -ForegroundColor Green

# Function to send concurrent requests
function Send-LoadTestRequests {
    param([int]$RequestCount, [string]$Url)
    
    $jobs = @()
    for ($i = 1; $i -le $RequestCount; $i++) {
        $job = Start-Job -ScriptBlock {
            param($url, $id)
            try {
                $body = @{ message = "Load test message $id" } | ConvertTo-Json
                $response = Invoke-RestMethod -Uri "$url/send" -Method Post -Body $body -ContentType "application/json"
                return @{ Success = $true; Id = $id; Response = $response }
            } catch {
                return @{ Success = $false; Id = $id; Error = $_.Exception.Message }
            }
        } -ArgumentList $Url, $i
        $jobs += $job
    }
    
    # Wait for all jobs and collect results
    $results = $jobs | Receive-Job -Wait -AutoRemoveJob
    return $results
}

# Generate load to trigger auto-scaling
Write-Host "Sending 50 concurrent requests..." -ForegroundColor Yellow
$results = Send-LoadTestRequests -RequestCount 50 -Url $API_URL

# Analyze results
$successful = ($results | Where-Object { $_.Success }).Count
$failed = ($results | Where-Object { !$_.Success }).Count, 
Write-Host "Load test results: $successful successful, $failed failed" -ForegroundColor Green
```

### Step 3: Monitor Auto-Scaling Behavior

```bash
# Monitor HPA scaling decisions
echo "=== Monitoring Auto-Scaling ==="
kubectl get hpa worker-service-hpa -n hello-apis -w &
HPA_WATCH_PID=$!

# Monitor pod scaling in separate terminal
kubectl get pods -l app=worker-service -n hello-apis -w &
PODS_WATCH_PID=$!

# Check current metrics
echo "=== Current Metrics ==="
kubectl top pods -n hello-apis | grep worker-service
kubectl describe hpa worker-service-hpa -n hello-apis

# Stop monitoring after 2 minutes
sleep 120
kill $HPA_WATCH_PID $PODS_WATCH_PID 2>/dev/null
```

### Step 4: Production Monitoring and Logging

```bash
# Check application logs
echo "=== Application Logs ==="
kubectl logs -l app=rust-api -n hello-apis --tail=20
kubectl logs -l app=worker-service -n hello-apis --tail=20

# Check system events
echo "=== Recent Events ==="
kubectl get events -n hello-apis --sort-by=.metadata.creationTimestamp | tail -20

# Resource utilization summary
echo "=== Resource Utilization ==="
kubectl top nodes
kubectl top pods -n hello-apis

# Service mesh information if applicable
echo "=== Network Information ==="
kubectl get endpoints -n hello-apis
kubectl describe service rust-api-service -n hello-apis
```

### Step 5: Azure Portal Verification

```powershell
# Get Azure portal links for monitoring
$RESOURCE_GROUP = "rg-hello-apis" 
$CLUSTER_NAME = "aks-hello-apis"

Write-Host "=== Azure Portal Links ===" -ForegroundColor Green
Write-Host "Resource Group: https://portal.azure.com/#@/resource/subscriptions/{subscriptionId}/resourceGroups/$RESOURCE_GROUP" -ForegroundColor Cyan
Write-Host "AKS Cluster: https://portal.azure.com/#@/resource/subscriptions/{subscriptionId}/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME" -ForegroundColor Cyan

# Check cluster health via Azure CLI
Write-Host "=== Azure CLI Health Check ===" -ForegroundColor Green
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "{name: name, powerState: powerState, kubernetesVersion: kubernetesVersion, provisioningState: provisioningState}"

# Monitor via Azure CLI
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
kubectl get nodes -o wide
```

## Development Workflow Best Practices

Establish efficient patterns for transitioning between development modes and managing the complete development lifecycle.

### Workflow Transition Patterns

#### From Direct to Local Kubernetes

```bash
# Stop direct development services
pkill -f "cargo run"
pkill -f "dotnet run"
docker-compose down

# Build and deploy to local K8s
./.devcontainer/build-local-images.sh
kubectl apply -f src/k8s/local/
./.devcontainer/k8s-port-forward.sh &

echo "Transitioned from Direct to Local Kubernetes mode"
```

#### From Local Kubernetes to Azure

```bash
# Stop local port forwarding
pkill -f "kubectl port-forward"

# Clean up local deployment
kubectl delete -f src/k8s/local/ --ignore-not-found=true

# Build and push to ACR, deploy to AKS
ACR_NAME="<your-acr-name>"
./build-and-deploy-azure.sh $ACR_NAME

echo "Transitioned from Local Kubernetes to Azure deployment"
```

#### Quick Mode Switching Script

Create a helper script for rapid mode switching:

```bash
# Create workflow script
cat > .devcontainer/switch-mode.sh << 'EOF'
#!/bin/bash
set -e

MODE=$1
case $MODE in
  "direct")
    echo "Switching to Direct Development Mode..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    kubectl delete -f src/k8s/local/ --ignore-not-found=true 2>/dev/null || true
    docker-compose up -d rabbitmq
    echo "Direct mode ready. Start services with VS Code tasks."
    ;;
  "k8s")
    echo "Switching to Local Kubernetes Mode..."
    pkill -f "cargo run" 2>/dev/null || true
    pkill -f "dotnet run" 2>/dev/null || true
    docker-compose down 2>/dev/null || true
    ./.devcontainer/build-local-images.sh
    kubectl apply -f src/k8s/local/
    ./.devcontainer/k8s-port-forward.sh &
    echo "Local Kubernetes mode ready."
    ;;
  "azure")
    echo "Switching to Azure Mode..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    kubectl delete -f src/k8s/local/ --ignore-not-found=true 2>/dev/null || true
    echo "Azure mode ready. Use production deployment scripts."
    ;;
  *)
    echo "Usage: $0 {direct|k8s|azure}"
    exit 1
    ;;
esac
EOF

chmod +x .devcontainer/switch-mode.sh

# Test the script
./.devcontainer/switch-mode.sh direct
```

### Development Lifecycle Best Practices

#### 1. Feature Development Workflow

```bash
# Start with direct mode for rapid iteration
./.devcontainer/switch-mode.sh direct

# Develop and test feature
# [Make code changes, test locally]

# Validate in Kubernetes environment
./.devcontainer/switch-mode.sh k8s

# Test integration and Kubernetes-specific behavior
# [Run integration tests]

# Deploy to Azure for final validation
./.devcontainer/switch-mode.sh azure
# [Deploy and test in production environment]
```

#### 2. Debugging Workflow

```bash
# For application bugs: Use direct mode
./.devcontainer/switch-mode.sh direct
# Set breakpoints, attach debugger, step through code

# For deployment/infrastructure bugs: Use local K8s
./.devcontainer/switch-mode.sh k8s
# Check pod logs, test service discovery, validate configurations

# For production issues: Use Azure tools
kubectl logs -l app=worker-service -n hello-apis --tail=50
kubectl describe pod <pod-name> -n hello-apis
```

#### 3. Testing Strategy per Mode

| Mode | Testing Focus | Tools |
| ------ | --------------- | -------- |
| **Direct** | Unit tests, business logic | VS Code debugger, `cargo test`, `dotnet test` |
| **Local K8s** | Integration tests, K8s configs | `kubectl`, container logs, service testing |
| **Azure** | Performance tests, scaling | Azure portal, HPA metrics, load testing |

### Code Quality and Consistency

```bash
# Set up pre-commit hooks for code quality
cat > .devcontainer/pre-commit-setup.sh << 'EOF'
#!/bin/bash

# Rust formatting and linting
echo "Setting up Rust tools..."
rustup component add rustfmt clippy

# .NET formatting tools  
echo "Setting up .NET tools..."
dotnet tool install -g dotnet-format

# Create pre-commit script
cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
echo "Running pre-commit checks..."

# Format Rust code
find src/rust-api/src -name "*.rs" -exec rustfmt {} \;

# Check Rust code
cd src/rust-api && cargo clippy -- -D warnings

# Format C# code
cd ../../src && dotnet format --verify-no-changes || (echo "Run 'dotnet format' to fix formatting" && exit 1)

echo "Pre-commit checks passed!"
HOOK

chmod +x .git/hooks/pre-commit
echo "Pre-commit hooks installed successfully!"
EOF

chmod +x .devcontainer/pre-commit-setup.sh
./.devcontainer/pre-commit-setup.sh
```

## Troubleshooting

Common issues and solutions for devcontainer development workflows.

### Devcontainer Issues

#### Issue: Devcontainer fails to build

**Symptoms:**

```text
Error response from daemon: failed to build devcontainer
```

**Solutions:**

```bash
# Clear Docker cache and rebuild
docker system prune -f
docker volume prune -f

# Rebuild devcontainer without cache
# In VS Code: Command Palette > Dev Containers: Rebuild Container Without Cache
```

#### Issue: Extensions not loading properly

**Symptoms:**

- Rust analyzer not working
- C# intellisense missing

**Solutions:**

```bash
# Reload window
# In VS Code: Command Palette > Developer: Reload Window

# Or restart the devcontainer
# Command Palette > Dev Containers: Rebuild Container
```

### Direct Development Mode Issues

#### Issue: Port conflicts

**Symptoms:**

```text
Error: Port 8080 is already in use
```

**Solutions:**

```bash
# Find and kill processes using ports
lsof -ti:8080 | xargs kill -9
lsof -ti:5672 | xargs kill -9

# Or use different ports
export PORT=8081
export RABBITMQ_URL=amqp://admin:admin123@localhost:5673
```

#### Issue: RabbitMQ connection failures

**Symptoms:**

```text
Failed to connect to RabbitMQ: Connection refused
```

**Solutions:**

```bash
# Check RabbitMQ container status
docker-compose ps rabbitmq

# Restart RabbitMQ
docker-compose down rabbitmq
docker-compose up -d rabbitmq

# Wait for startup
docker-compose logs -f rabbitmq | grep "Server startup complete"

# Verify connectivity
telnet localhost 5672
```

### Local Kubernetes Issues

#### Issue: Images not found in local K8s

**Symptoms:**

```text
Failed to pull image "rust-api:local": ImagePullBackOff
```

**Solutions:**

```bash
# Verify images exist with :local tags
docker images | grep :local

# Rebuild local images
./.devcontainer/build-local-images.sh

# Ensure imagePullPolicy is Never in manifests
grep -r "imagePullPolicy" src/k8s/local/
```

#### Issue: Port forwarding failures

**Symptoms:**

```text
error: unable to forward port because pod is not running
```

**Solutions:**

```bash
# Check pod status
kubectl get pods -o wide

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=rust-api --timeout=60s

# Restart port forwarding
pkill -f "kubectl port-forward"
./.devcontainer/k8s-port-forward.sh &
```

### Azure Deployment Issues  

#### Issue: Image pull errors from ACR

**Symptoms:**

```text
Failed to pull image from ACR: Unauthorized
```

**Solutions:**

```bash
# Verify ACR login
az acr login --name $ACR_NAME

# Check AKS has ACR access
az aks check-acr --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --acr $ACR_NAME

# Update AKS credentials if needed
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --attach-acr $ACR_NAME
```

#### Issue: LoadBalancer external IP pending

**Symptoms:**

```text
External IP shows <pending> for services
```

**Solutions:**

```bash
# Check service events
kubectl describe service rust-api-service -n hello-apis

# Verify cluster has load balancer support
kubectl get nodes -o yaml | grep -A 5 "cloud-provider"

# For development, use NodePort instead
kubectl patch service rust-api-service -n hello-apis -p '{"spec":{"type":"NodePort"}}'
```

### Performance Issues

#### Issue: High resource usage in devcontainer

**Solutions:**

```bash
# Check resource usage
docker stats

# Limit resources in devcontainer.json
# Add to devcontainer configuration:
# "runArgs": ["--memory=4g", "--cpus=2"]

# Clean up unused resources
docker system prune -f
```

#### Issue: Slow builds or builds failing

**Solutions:**

```bash
# Use BuildKit for faster builds
export DOCKER_BUILDKIT=1

# Build with specific target and cache
docker build --target release --cache-from rust-api:local -t rust-api:local src/rust-api/

# Parallel builds
make -j$(nproc) build-all
```

## Cleanup

Clean up resources across all deployment modes to prevent resource waste and conflicts.

### Local Environment Cleanup

```bash
# Stop all running processes
echo "Stopping direct development services..."
pkill -f "cargo run" 2>/dev/null || true
pkill -f "dotnet run" 2>/dev/null || true
pkill -f "kubectl port-forward" 2>/dev/null || true

# Clean up Docker Compose
echo "Cleaning up Docker Compose..."
docker-compose down -v
docker-compose rm -f

# Clean up local Kubernetes
echo "Cleaning up local Kubernetes..."
kubectl delete -f src/k8s/local/ --ignore-not-found=true

# Clean up Docker resources
echo "Cleaning up Docker resources..."
docker system prune -f
docker volume prune -f

# Remove local images (optional)
echo "Removing local container images..."
docker images | grep ":local" | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true
```

### Local Kubernetes Cleanup

```bash
# Delete local deployment
kubectl delete namespace default --ignore-not-found=true
kubectl delete -f src/k8s/local/ --ignore-not-found=true

# Stop port forwarding
pkill -f "kubectl port-forward" 2>/dev/null || true

# Clean up local images
docker images | grep ":local" | awk '{print $1":"$2}' | xargs docker rmi 2>/dev/null || true

echo "Local Kubernetes environment cleaned up"
```

### Azure Resources Cleanup

**⚠️ Warning**: This will delete Azure resources that may be used by other labs or applications.

```powershell
# Remove AKS deployment only (preserve infrastructure)
Write-Host "Removing Lab 3 deployment from AKS..." -ForegroundColor Yellow
kubectl delete namespace hello-apis --ignore-not-found=true

# Wait for namespace deletion
Write-Host "Waiting for namespace deletion..."
while (kubectl get namespace hello-apis 2>$null) {
    Start-Sleep 5
    Write-Host "." -NoNewline
}
Write-Host "`nNamespace deleted successfully" -ForegroundColor Green
```

**Complete Azure Infrastructure Cleanup** (if you want to delete everything):

```powershell
# ⚠️ WARNING: This deletes ALL Azure resources created in previous labs
$RESOURCE_GROUP = "rg-hello-apis"

Write-Host "⚠️  WARNING: This will delete ALL Azure resources!" -ForegroundColor Red
Write-Host "This includes ACR, AKS cluster, and all data." -ForegroundColor Red
$confirm = Read-Host "Are you sure? Type 'DELETE' to confirm"

if ($confirm -eq "DELETE") {
    Write-Host "Deleting Azure resource group: $RESOURCE_GROUP" -ForegroundColor Red
    az group delete --name $RESOURCE_GROUP --yes --no-wait
    
    Write-Host "Deletion initiated. This may take 10-20 minutes to complete." -ForegroundColor Yellow
    Write-Host "Check Azure portal for deletion progress." -ForegroundColor Yellow
} else {
    Write-Host "Azure infrastructure cleanup cancelled." -ForegroundColor Green
}
```

### Verify Cleanup

```bash
# Check no processes are running
echo "=== Process Check ==="
ps aux | grep -E "(cargo|dotnet|kubectl)" | grep -v grep || echo "No development processes running"

# Check Docker resources
echo "=== Docker Resources ==="
docker ps | grep -E "(rust-api|worker-service|rabbitmq)" || echo "No development containers running"

# Check local Kubernetes
echo "=== Local Kubernetes ==="
kubectl get pods | grep -E "(rust-api|worker-service|rabbitmq)" || echo "No development pods in local cluster"

# Check ports are free
echo "=== Port Status ==="
netstat -tuln | grep -E "(8080|5672|15672)" || echo "Development ports are available"
```

## Quick Reference

### Development Mode Commands

| Mode | Start Command | Test Command | Stop Command |
| ------ | --------------- | -------------- | -------------- |
| **Direct** | `.devcontainer/switch-mode.sh direct` | `curl localhost:8080/health` | `pkill -f "cargo\|dotnet"` |
| **Local K8s** | `.devcontainer/switch-mode.sh k8s` | `kubectl get pods` | `kubectl delete -f src/k8s/local/` |
| **Azure** | `./deploy-to-azure.sh` | `curl http://$EXTERNAL_IP:8080/health` | `kubectl delete namespace hello-apis` |

### Port Forwarding Reference

| Service | Local Port | Purpose |
| --------- | ------------ | --------- |
| Rust API | 8080 | HTTP API endpoints |
| RabbitMQ AMQP | 5672 | Message broker |
| RabbitMQ Management | 15672 | Web UI (admin/admin123) |

### Environment Variables

#### Direct Development Environment

```bash
# Rust API
export RUST_LOG=debug
export PORT=8080
export RABBITMQ_URL=amqp://admin:admin123@localhost:5672
export RABBITMQ_QUEUE=task-queue

# C# Worker Service
export DOTNET_ENVIRONMENT=Development
export RabbitMQ__Host=localhost
export RabbitMQ__Port=5672
export RabbitMQ__Username=admin
export RabbitMQ__Password=admin123
export RabbitMQ__Queue=task-queue
export ProcessingDelayMs=2000
```

### Common kubectl Commands

```bash
# Basic cluster info
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Application management
kubectl get pods -n hello-apis
kubectl logs -l app=rust-api -n hello-apis --tail=20
kubectl describe pod <pod-name> -n hello-apis

# Services and networking
kubectl get services -n hello-apis
kubectl get endpoints -n hello-apis
kubectl port-forward -n hello-apis svc/rust-api-service 8080:8080

# Scaling and HPA
kubectl get hpa -n hello-apis
kubectl scale deployment worker-service --replicas=3 -n hello-apis
kubectl top pods -n hello-apis
```

### Docker Commands

```bash
# Container management
docker ps                              # List running containers
docker logs <container-name>           # View container logs
docker exec -it <container-name> bash  # Enter container shell

# Image management
docker images | grep ":local"          # List local development images
docker build -t <name>:local .         # Build local image
docker system prune -f                 # Clean up unused resources

# Docker Compose
docker-compose up -d rabbitmq          # Start RabbitMQ only
docker-compose down                     # Stop all services
docker-compose logs -f rabbitmq         # Follow RabbitMQ logs
```

### VS Code Tasks Quick Reference

| Task | Purpose | Shortcut |
| ------ | --------- | ---------- |
| Start Infrastructure | Start RabbitMQ | `Ctrl+Shift+P` → Tasks → Start Infrastructure |
| Start All Services | Start full stack | `Ctrl+Shift+P` → Tasks → Start All Services |
| Build Rust API | Compile Rust code | `Ctrl+Shift+P` → Tasks → Build Rust API |
| Build C# Services | Compile .NET code | `Ctrl+Shift+P` → Tasks → Build C# Services |
| 🐳 Build Local Docker Images | Create :local images | `Ctrl+Shift+P` → Tasks → 🐳 Build Local Docker Images |
| ☸️ Deploy to Local K8s | Deploy to K8s | `Ctrl+Shift+P` → Tasks → ☸️ Deploy to Local K8s |

### API Testing Commands

```bash
# Health check
curl -s http://localhost:8080/health | jq .

# Send message
curl -s -X POST http://localhost:8080/send \
  -H "Content-Type: application/json" \
  -d '{"message": "Test message"}' | jq .

# RabbitMQ management API
curl -s -u admin:admin123 http://localhost:15672/api/overview | jq .
curl -s -u admin:admin123 http://localhost:15672/api/queues | jq '.[] | {name, messages}'
```

### Troubleshooting Quick Checks

```bash
# Port conflicts
lsof -i :8080 :5672 :15672

# Service connectivity
telnet localhost 8080
telnet localhost 5672

# Container status
docker-compose ps
docker ps | grep -E "(rust-api|worker-service|rabbitmq)"

 # Kubernetes status
kubectl get pods --all-namespaces | grep -E "(rust-api|worker-service|rabbitmq)"
kubectl describe pod <pod-name> -n hello-apis

# Process status
ps aux | grep -E "(cargo|dotnet|kubectl)" | grep -v grep

# Log locations
docker-compose logs rabbitmq | tail
kubectl logs -l app=rust-api -n hello-apis --tail=10
kubectl logs -l app=worker-service -n hello-apis --tail=10
```

---

**Congratulations!** You've completed Lab 3 and mastered devcontainer-based cloud-native development
workflows. You now understand how to efficiently transition between direct development, local Kubernetes,
and Azure production environments, providing you with the skills to work effectively on modern
cloud-native applications.

**Next Steps**:

- Explore advanced Kubernetes features (Ingress, ConfigMaps, Secrets)
- Implement CI/CD pipelines for automated deployments
- Add observability with logging and monitoring solutions
- Experiment with service mesh technologies like Istio
