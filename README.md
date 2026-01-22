# Hello World REST APIs for Azure Kubernetes Service

The intention of this project is to provide an environment to learn and interact with Rust, and C#, Containers, and Azure Kubernetes. This project contains two Hello World REST APIs, docker files for both APIs, and the orchestration files to deploy the API services:

- **Rust API** - Built with Actix-web framework
- **C# API** - Built with ASP.NET Core Minimal API

Both APIs are containerized and ready for deployment to Azure Kubernetes Service (AKS).

## Project Structure

```text
├── src/
│   ├── RustKubernetesDemo.sln
│   ├── rust-api/                 # Rust REST API
│   │   ├── src/
│   │   │   └── main.rs
│   │   ├── Cargo.toml
│   │   └── Dockerfile
│   ├── csharp-api/              # C# REST API
│   │   ├── Program.cs
│   │   ├── HelloApi.csproj
│   │   └── Dockerfile
│   ├── k8s/                     # Kubernetes manifests
│   │   ├── namespace.yaml
│   │   ├── rust-deployment.yaml
│   │   └── csharp-deployment.yaml
│   └── infra/                   # Azure infrastructure (Bicep)
│       └── main.bicep
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

```powershell
# Login to Azure
az login

# Create resource group
az group create --name rg-hello-apis --location eastus

# Deploy infrastructure using Bicep
az deployment group create `
  --resource-group rg-hello-apis `
  --template-file src/infra/main.bicep `
  --parameters clusterName=aks-hello-apis acrName=acrhelloapisXXXX
```

### 2. Push Images to ACR

```powershell
# Login to ACR
az acr login --name acrhelloapisXXXX

# Tag and push images
docker tag hello-rust-api:latest acrhelloapisXXXX.azurecr.io/hello-rust-api:latest
docker tag hello-csharp-api:latest acrhelloapisXXXX.azurecr.io/hello-csharp-api:latest

docker push acrhelloapisXXXX.azurecr.io/hello-rust-api:latest
docker push acrhelloapisXXXX.azurecr.io/hello-csharp-api:latest
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

Both APIs expose the same endpoints:

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/` | GET | Returns "Hello, World!" message |
| `/health` | GET | Health check endpoint |
| `/info` | GET | Returns API information |

## Security Considerations

- Uses Managed Identity for AKS to ACR authentication
- Non-root containers
- Resource limits defined in Kubernetes manifests
- Health checks configured for liveness and readiness probes
