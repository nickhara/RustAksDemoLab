---
marp: true
theme: default
paginate: true
backgroundColor: #fff
style: |
  section {
    font-family: 'Segoe UI', Arial, sans-serif;
  }
  h1 {
    color: #0078d4;
  }
  h2 {
    color: #005a9e;
  }
  code {
    background-color: #f4f4f4;
  }
---

# My Focus Time Experiment

## Getting Started with Rust and AKS

Rust & C# APIs Hosted in Containers

![bg right:40% 80%](https://azure.microsoft.com/svghandler/kubernetes-service/?width=600&height=315)

---

# Agenda

1. **Project Overview** - What we're building and why
2. **Architecture** - How it all fits together
3. **The Cool Stuff**
    - **Local Development** - Running APIs locally
    - **Docker Containers** - Building and testing images
    - **Azure Deployment** - Infrastructure with Bicep
    - **Kubernetes** - Deploying to AKS
4. **Marp** - Create slide deck written in Marp Markdown on VS Code
    - <https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode>

---

# What we're building and why?

The short answer, I wanted to utilize my day of learning, and build a project I could extend to dig deeper as time permitted.

1. I wanted to learn about rust, crates, and their dependencies.
2. I wanted to run my APIs in local containers in Docker Desktop
3. I wanted to deploy my API services to AKS
4. I wanted to learn how to use Copilot more effectively

---

# API Details

| API | Technology | Framework |
|-----|------------|-----------|
| **Rust API** | Rust | Actix-web |
| **C# API** | .NET 10 | ASP.NET Core Minimal API |

## Both APIs expose identical endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Returns "Hello, World!" |
| `/health` | GET | Health check for K8s probes |
| `/info` | GET | API version and runtime info |

---

# Architecture: Local Docker Desktop

```
┌─────────────────────────────────────────────────────────────────┐
│                     Local Development Machine                   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Docker Desktop                          │ │
│  │                                                            │ │
│  │   ┌─────────────────────┐   ┌─────────────────────┐        │ │
│  │   │  hello-rust-api     │   │  hello-csharp-api   │        │ │
│  │   │  Container          │   │  Container          │        │ │
│  │   │                     │   │                     │        │ │
│  │   │  Port: 8080 ────────┼───│  Port: 8080         │        │ │
│  │   └─────────┬───────────┘   └──────────┬──────────┘        │ │
│  │             │                          │                   │ │
│  └─────────────┼──────────────────────────┼───────────────────┘ │
│                │                          │                     │
│         Port Mapping               Port Mapping                 │
│          -p 8080:8080               -p 8081:8080                │
│                │                          │                     │
└────────────────┼──────────────────────────┼─────────────────────┘
                 │                          │
         localhost:8080              localhost:8081
                 │                          │
         ┌───────┴──────────────────────────┴───────┐
         │              Browser / curl              │
         └──────────────────────────────────────────┘
```

---

# Architecture: Azure Kubernetes Service

```
┌─────────────────────────────────────────────────────────────┐
│                   Azure Resource Group                      │
│  ┌────────────────┐       ┌──────────────────────────────┐  │
│  │                │       │        AKS Cluster           │  │
│  │  Azure         │       │  ┌───────────────────────┐   │  │
│  │  Container     │◄──────│  │  hello-apis namespace │   │  │
│  │  Registry      │ pull  │  │  ┌────┐    ┌────┐     │   │  │
│  │                │       │  │  │Rust│    │ C# │     │   │  │
│  │  - rust-api    │       │  │  │API │    │API │     │   │  │
│  │  - csharp-api  │       │  │  └──┬─┘    └─┬──┘     │   │  │
│  └────────────────┘       │  └─────┼────────┼────────┘   │  │
│                           │     Load Balancer            │  │
│                           └────────────┬─────────────────┘  │
└────────────────────────────────────────┼────────────────────┘
                        Internet
```

---

# Project Structure

```
├── src/
│   ├── rust-api/           # Rust REST API
│   │   ├── src/main.rs
│   │   ├── Cargo.toml
│   │   └── Dockerfile
│   ├── csharp-api/         # C# REST API
│   │   ├── Program.cs
│   │   ├── HelloApi.csproj
│   │   └── Dockerfile
│   ├── k8s/                # Kubernetes manifests
│   │   ├── namespace.yaml
│   │   ├── rust-deployment.yaml
│   │   └── csharp-deployment.yaml
│   └── infra/              # Azure infrastructure
│       └── main.bicep
```

---

# Prerequisites

| Tool | Purpose |
|------|---------|
| Docker Desktop | Container runtime |
| Visual Studio Build Tools | Rust compilation (Windows) |
| Rust | Rust API development |
| .NET 10 SDK | C# API development |
| Azure CLI | Azure resource management |
| kubectl | Kubernetes management |

---

# Demo: Local Development

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

---

# Demo: Testing Locally

```powershell
# Test Rust API
Invoke-RestMethod -Uri http://localhost:8080/
Invoke-RestMethod -Uri http://localhost:8080/health
Invoke-RestMethod -Uri http://localhost:8080/info

# Expected output:
# message   : Hello, World!
# language  : Rust
# framework : Actix-web
```

---

# Demo: Building Docker Images

```powershell
# Build Rust API
docker build -t hello-rust-api:latest ./src/rust-api

# Build C# API
docker build -t hello-csharp-api:latest ./src/csharp-api

# Verify images
docker images | Select-String "hello"
```

---

# Demo: Running in Docker

```powershell
# Run Rust API on port 8080
docker run -d -p 8080:8080 --name rust-api hello-rust-api:latest

# Run C# API on port 8081
docker run -d -p 8081:8080 --name csharp-api hello-csharp-api:latest

# Test both APIs
Invoke-RestMethod -Uri http://localhost:8080/    # Rust
Invoke-RestMethod -Uri http://localhost:8081/    # C#
```

---

# Azure Infrastructure (Bicep)

### What gets deployed

- **Azure Container Registry (ACR)** - Store Docker images
- **Azure Kubernetes Service (AKS)** - Run containers
- **Managed Identity** - Secure ACR access
- **Load Balancer** - Expose APIs publicly

### Key Parameters

| Parameter | Default |
|-----------|---------|
| nodeVmSize | Standard_DS2_v2 |
| nodeCount | 2 |
| kubernetesVersion | 1.34 |

---

# Demo: Deploy Azure Infrastructure

```powershell
# Login to Azure
az login

# Create resource group
az group create --name rg-hello-apis --location westus2

# Deploy with Bicep
az deployment group create `
  --resource-group rg-hello-apis `
  --template-file src/infra/main.bicep `
  --parameters clusterName=aks-hello-apis `
               acrName=acrhelloapis12345
```

---

# Demo: Push Images to ACR

```powershell
# Login to ACR
az acr login --name acrhelloapis12345

# Tag images
docker tag hello-rust-api:latest `
  acrhelloapis12345.azurecr.io/hello-rust-api:latest
docker tag hello-csharp-api:latest `
  acrhelloapis12345.azurecr.io/hello-csharp-api:latest

# Push to ACR
docker push acrhelloapis12345.azurecr.io/hello-rust-api:latest
docker push acrhelloapis12345.azurecr.io/hello-csharp-api:latest
```

---

# Kubernetes Manifests

### Deployment Configuration

- **Replicas:** 2 pods per API (high availability)
- **Resources:** CPU/memory limits defined
- **Health checks:** Liveness & readiness probes
- **Security:** Non-root user, dropped capabilities

### Files

- `namespace.yaml` - Creates `hello-apis` namespace
- `rust-deployment.yaml` - Rust API Deployment + Service
- `csharp-deployment.yaml` - C# API Deployment + Service

---

# Demo: Deploy to AKS

```powershell
# Get AKS credentials
az aks get-credentials --resource-group rg-hello-apis `
                       --name aks-hello-apis

# Deploy resources
kubectl apply -f src/k8s/namespace.yaml
kubectl apply -f src/k8s/rust-deployment.yaml
kubectl apply -f src/k8s/csharp-deployment.yaml

# Watch pods come up
kubectl get pods -n hello-apis -w
```

---

# Demo: Access the APIs

```powershell
# Get external IPs
kubectl get services -n hello-apis

# NAME               TYPE           EXTERNAL-IP
# rust-hello-api     LoadBalancer   20.xx.xx.xx
# csharp-hello-api   LoadBalancer   20.xx.xx.xx

# Test the APIs
$RUST_IP = kubectl get svc rust-hello-api -n hello-apis `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Invoke-RestMethod -Uri "http://$RUST_IP/"
```

---

# Monitoring & Troubleshooting

```powershell
# View pod status
kubectl get pods -n hello-apis

# View logs
kubectl logs -l app=rust-hello-api -n hello-apis

# Describe pod (for debugging)
kubectl describe pod <pod-name> -n hello-apis

# Shell into container
kubectl exec -it <pod-name> -n hello-apis -- /bin/sh
```

---

# Security Features

✅ **Managed Identity** - AKS authenticates to ACR without secrets

✅ **Non-root containers** - APIs run as unprivileged user

✅ **Resource limits** - CPU/memory caps prevent runaway usage

✅ **Health probes** - Kubernetes auto-restarts unhealthy pods

✅ **RBAC enabled** - Role-based access control on AKS

✅ **Dropped capabilities** - Minimal Linux capabilities

---

# Cleanup

```powershell
# Delete Kubernetes resources
kubectl delete -f src/k8s/

# Delete entire Azure resource group
az group delete --name rg-hello-apis --yes --no-wait

# Remove kubectl context
kubectl config delete-context aks-hello-apis
```

---

# Summary

### What we covered

1. ✅ Built Rust and C# REST APIs
2. ✅ Containerized with Docker
3. ✅ Deployed Azure infrastructure with Bicep
4. ✅ Pushed images to Azure Container Registry
5. ✅ Deployed to Azure Kubernetes Service
6. ✅ Tested live APIs in the cloud

### Resources

- 📁 GitHub: [RustKubernetesDemo](https://github.com/your-repo)
- 📖 Docs: `docs/DEPLOYMENT.md`

---

# Questions?

![bg right:50% 80%](https://azure.microsoft.com/svghandler/kubernetes-service/?width=600&height=315)

### Thank you

**Contact:**

- 📧 <your.email@example.com>
- 🔗 linkedin.com/in/yourprofile
