# Rust, C#, and Azure Kubernetes Service - Learning Labs

This project provides hands-on labs to learn Rust, C#, Containers, Azure Kubernetes Service (AKS), and advanced Kubernetes features like autoscaling and message queues.

## Available Labs

### Lab 1: Hello World REST APIs (Prerequisite)

Build and deploy basic REST APIs to AKS.

- **Rust API** - Built with Actix-web framework
- **C# API** - Built with ASP.NET Core Minimal API
- **Infrastructure** - Bicep templates for ACR and AKS
- **Deployment** - Kubernetes manifests and deployment pipelines

📖 **[View Lab 1 Guide](docs/LabExperimentGuide.md)**

### Lab 2: Message Queue with RabbitMQ and Auto-Scaling Workers

Extend the Rust API with asynchronous message processing using RabbitMQ and auto-scaling worker services.

- **Message Queue** - RabbitMQ for async task processing
- **Rust API Enhancement** - POST `/send` endpoint to publish messages
- **C# Worker Service** - Scalable message consumer with simulated processing
- **Horizontal Pod Autoscaler (HPA)** - Automatic worker scaling based on CPU load
- **Testing Scripts** - PowerShell tools for load testing and monitoring

📖 **[View Lab 2 Guide](docs/Lab2-MessageQueue.md)**  
📖 **[HPA Reference Documentation](docs/HPA-Reference.md)**

## Quick Start

Both APIs are containerized and ready for deployment to Azure Kubernetes Service (AKS).

**Lab 1:** Start here to set up the basic infrastructure and APIs.  
**Lab 2:** Build on Lab 1 to add message queuing and autoscaling capabilities.

## Project Structure

```text
├── src/
│   ├── RustKubernetesDemo.sln
│   ├── rust-api/                 # Rust REST API (Lab 1 & 2)
│   │   ├── src/
│   │   │   └── main.rs
│   │   ├── Cargo.toml
│   │   └── Dockerfile
│   ├── csharp-api/              # C# REST API (Lab 1)
│   │   ├── Program.cs
│   │   ├── HelloApi.csproj
│   │   └── Dockerfile
│   ├── worker-service/          # C# Worker Service (Lab 2)
│   │   └── WorkerService/
│   │       ├── Worker.cs
│   │       ├── Program.cs
│   │       ├── WorkerService.csproj
│   │       └── Dockerfile
│   ├── k8s/                     # Kubernetes manifests
│   │   ├── namespace.yaml
│   │   ├── rust-deployment.yaml
│   │   ├── csharp-deployment.yaml
│   │   ├── rabbitmq-deployment.yaml    # Lab 2
│   │   ├── worker-deployment.yaml      # Lab 2
│   │   └── worker-hpa.yaml             # Lab 2
│   └── infra/                   # Azure infrastructure (Bicep)
│       └── main.bicep
├── .build/                      # Build automation scripts
│   └── Build-All.ps1
├── .deploy/                     # Deployment & monitoring scripts (Lab 2)
│   ├── Deploy-AKS.ps1
│   ├── Deploy-Local.ps1
│   ├── Validate-Deployment.ps1
│   ├── Get-ProcessingResults.ps1
│   ├── Monitor-Queue.ps1
│   └── Watch-HPA.ps1
├── .test/                       # Testing & validation scripts (Lab 2)
│   ├── Send-TestMessages.ps1
│   ├── Test-E2E.ps1
│   └── Test-HPAScaling.ps1
├── docs/                        # Lab guides and documentation
│   ├── LabExperimentGuide.md    # Lab 1 Guide
│   ├── Lab2-MessageQueue.md     # Lab 2 Guide
│   └── HPA-Reference.md         # HPA Deep Dive
├── docker-compose.yml           # Local development (Lab 2)
└── README.md
```

## Prerequisites

The following tools are required for development and deployment:

| Tool | Purpose | Required For |
| ---- | ------- | ------------ |
| WSL 2 | Linux environment on Windows | Docker Desktop (Windows) |
| Docker Desktop | Container runtime | Building & running containers |
| Visual Studio Build Tools | C++ compiler and linker | Rust development (Windows) |
| Rust | Rust API development | Local development |
| .NET 10 SDK | C# API development | Local development |
| Azure CLI | Azure resource management | Azure deployment |
| kubectl | Kubernetes management | AKS deployment |

### Installing WSL 2 (Windows Only)

WSL 2 is required for Docker Desktop on Windows.

1. Open PowerShell as Administrator and run:

   ```powershell
   wsl --install
   ```

2. Restart your computer
3. After restart, set WSL 2 as the default version:

   ```powershell
   wsl --set-default-version 2
   ```

4. Verify installation:

   ```powershell
   wsl --version
   ```

> **Note:** Windows 10 version 2004+ (Build 19041+) or Windows 11 is required for WSL 2.

### Installing Docker Desktop

1. Download from [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Run the installer and follow the prompts
3. Restart your computer if prompted
4. Verify installation:

   ```bash
   docker --version
   docker run hello-world
   ```

### Installing Visual Studio Build Tools (Windows Only)

Visual Studio Build Tools provides the MSVC compiler and linker required for Rust development on Windows.

1. Download [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
2. Run the installer
3. Select **"Desktop development with C++"** workload
4. Click Install and wait for completion
5. Restart your computer

> **Note:** This is different from VS Code. The Build Tools provide the C++ compiler toolchain needed by Rust.

### Installing Rust

**Windows:**

1. Download and run [rustup-init.exe](https://rustup.rs/)
2. Follow the on-screen instructions (default installation is recommended)
3. Restart your terminal
4. Verify installation:

   ```bash
   rustc --version
   cargo --version
   ```

**macOS/Linux:**

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustc --version
```

### Installing .NET 10 SDK

**Windows:**

1. Download from [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
2. Run the installer
3. Verify installation:

   ```bash
   dotnet --version
   ```

**macOS (using Homebrew):**

```bash
brew install dotnet@10
dotnet --version
```

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get update
sudo apt-get install -y dotnet-sdk-10.0
dotnet --version
```

### Installing Azure CLI

**Windows:**

1. Download and run the [Azure CLI MSI installer](https://aka.ms/installazurecliwindows)
2. Verify installation:

   ```bash
   az --version
   ```

**macOS:**

```bash
brew install azure-cli
az --version
```

**Linux:**

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az --version
```

### Installing kubectl

**Windows (using winget):**

```bash
winget install Kubernetes.kubectl
kubectl version --client
```

**Windows (using Chocolatey):**

```bash
choco install kubernetes-cli
kubectl version --client
```

**macOS:**

```bash
brew install kubectl
kubectl version --client
```

**Linux:**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

> **Tip:** If you have Docker Desktop installed, kubectl is included. Enable it in Docker Desktop > Settings > Kubernetes > Enable Kubernetes.

## Local Development

### Rust API

```powershell
cd src/rust-api
cargo run
# API runs on http://localhost:8080
```

### C# API

```powershell
cd src/csharp-api
dotnet run
# API runs on http://localhost:8080
```

## Building Docker Images

```powershell
# Build Rust API
docker build -t hello-rust-api:latest ./src/rust-api

# Build C# API
docker build -t hello-csharp-api:latest ./src/csharp-api
```

## Testing Locally with Docker

```powershell
# Run Rust API
docker run -p 8080:8080 hello-rust-api:latest

# Run C# API (use different host port to avoid conflict)
docker run -p 8081:8080 hello-csharp-api:latest
```

### Testing with curl

Once the APIs are running (either via `cargo run`/`dotnet run` or Docker), test them with curl:

**Rust API (port 8080):**

```bash
# Hello endpoint
curl http://localhost:8080/

# Health check
curl http://localhost:8080/health

# API info
curl http://localhost:8080/info
```

**C# API (port 8080 local, or 8081 if running both in Docker):**

```bash
# Hello endpoint
curl http://localhost:8080/

# Health check
curl http://localhost:8080/health

# API info
curl http://localhost:8080/info
```

> **Tip:** Use `| ConvertTo-Json` for formatted output: `Invoke-RestMethod -Uri http://localhost:8080/ | ConvertTo-Json`

## Deploying to Azure Kubernetes Service

### 1. Create AKS Cluster and ACR

> **Note:** ACR names must be globally unique and contain only lowercase letters and numbers (5-50 characters).

```powershell
# Login to Azure
az login

# Create resource group
az group create --name rg-hello-apis --location eastus

# Deploy infrastructure using Bicep (replace acrhelloapis12345 with a unique name)
az deployment group create `
  --resource-group rg-hello-apis `
  --template-file src/infra/main.bicep `
  --parameters clusterName=aks-hello-apis acrName=acrhelloapis12345
```

### 2. Push Images to ACR

```powershell
# Login to ACR
az acr login --name acrhelloapis12345

# Tag and push images
docker tag hello-rust-api:latest acrhelloapis12345.azurecr.io/hello-rust-api:latest
docker tag hello-csharp-api:latest acrhelloapis12345.azurecr.io/hello-csharp-api:latest

docker push acrhelloapis12345.azurecr.io/hello-rust-api:latest
docker push acrhelloapis12345.azurecr.io/hello-csharp-api:latest
```

### 3. Deploy to AKS

```powershell
# Get AKS credentials
az aks get-credentials --resource-group rg-hello-apis --name aks-hello-apis

# Update image names in k8s manifests to use your ACR
# Then apply manifests
kubectl apply -f src/k8s/namespace.yaml
kubectl apply -f src/k8s/rust-deployment.yaml
kubectl apply -f src/k8s/csharp-deployment.yaml
```

### 4. Access the APIs

```bash
# Get service IPs
kubectl get services -n hello-apis

# Test endpoints
curl http://<RUST_EXTERNAL_IP>/
curl http://<RUST_EXTERNAL_IP>/health

curl http://<CSHARP_EXTERNAL_IP>/
curl http://<CSHARP_EXTERNAL_IP>/health
```

## API Endpoints

### Lab 1: REST APIs

Both Rust and C# APIs expose the same endpoints:

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/` | GET | Returns "Hello, World!" message |
| `/health` | GET | Health check endpoint |
| `/info` | GET | Returns API information |

### Lab 2: Message Queue

The Rust API gains an additional endpoint in Lab 2:

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/send` | POST | Publishes a message to RabbitMQ queue |

**Example Request:**

```json
{
  "task_type": "process-data",
  "payload": {
    "data": "your data here"
  }
}
```

## Learning Objectives

### Lab 1

- Build REST APIs in Rust and C#
- Containerize applications with Docker
- Deploy to Azure Kubernetes Service
- Manage infrastructure with Bicep
- Configure Kubernetes resources

### Lab 2

- Implement asynchronous message processing
- Use RabbitMQ for message queuing
- Build background worker services
- Configure Horizontal Pod Autoscaler (HPA)
- Monitor and test distributed systems
- Create operational automation scripts

## Security Considerations

- Uses Managed Identity for AKS to ACR authentication
- Non-root containers
- Resource limits defined in Kubernetes manifests
- Health checks configured for liveness and readiness probes
