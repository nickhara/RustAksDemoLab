# Deployment Guide: Azure Kubernetes Service

This guide walks you through deploying the Hello World REST APIs to Azure Kubernetes Service (AKS) using Bicep for infrastructure and kubectl for application deployment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Step 1: Azure Infrastructure Deployment (Bicep)](#step-1-azure-infrastructure-deployment-bicep)
- [Step 2: Build and Push Docker Images](#step-2-build-and-push-docker-images)
- [Step 3: Configure Kubernetes Manifests](#step-3-configure-kubernetes-manifests)
- [Step 4: Deploy to AKS](#step-4-deploy-to-aks)
- [Step 5: Verify Deployment](#step-5-verify-deployment)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before starting, ensure you have the following installed:

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.50+)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- An active Azure subscription

Verify your tools:

```powershell
az --version
docker --version
kubectl version --client
```

## Architecture Overview

The deployment creates:

| Resource | Purpose |
| -------- | ------- |
| **Azure Container Registry (ACR)** | Stores Docker images for both APIs |
| **Azure Kubernetes Service (AKS)** | Hosts the containerized APIs |
| **Managed Identity** | Enables AKS to pull images from ACR securely |
| **Load Balancer** | Exposes APIs to the internet |

```text
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Resource Group                      │
│  ┌──────────────────┐       ┌────────────────────────────────┐  │
│  │                  │       │         AKS Cluster            │  │
│  │  Azure Container │       │  ┌────────────────────────┐   │  │
│  │  Registry (ACR)  │◄──────│  │   hello-apis namespace │   │  │
│  │                  │ pull  │  │  ┌──────┐  ┌──────┐    │   │  │
│  │  - rust-api      │       │  │  │ Rust │  │ C#   │    │   │  │
│  │  - csharp-api    │       │  │  │ API  │  │ API  │    │   │  │
│  │                  │       │  │  └──┬───┘  └──┬───┘    │   │  │
│  └──────────────────┘       │  └─────┼─────────┼────────┘   │  │
│                             │        │         │            │  │
│                             │  ┌─────▼─────────▼─────┐      │  │
│                             │  │    Load Balancer    │      │  │
│                             │  └─────────┬───────────┘      │  │
│                             └────────────┼──────────────────┘  │
└──────────────────────────────────────────┼─────────────────────┘
                                           │
                                      Internet
```

## Step 1: Azure Infrastructure Deployment (Bicep)

### 1.1 Login to Azure

```powershell
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "<your-subscription-id>"

# Verify current subscription
az account show --query "{name:name, id:id}" -o table
```

### 1.2 Create Resource Group

```powershell
# Define variables
$RESOURCE_GROUP = "rg-hello-apis"
$LOCATION = "eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### 1.3 Deploy Infrastructure with Bicep

The Bicep template (`src/infra/main.bicep`) creates:
- Azure Container Registry (Basic SKU)
- AKS Cluster (2 nodes, Standard_B2s)
- Managed Identity with ACR pull permissions

```powershell
# Define unique names (ACR name must be globally unique)
$CLUSTER_NAME = "aks-hello-apis"
$ACR_NAME = "acrhelloapis" + (Get-Date -Format "yyyyMMddHHmm")  # Appends timestamp for uniqueness

# Deploy infrastructure
az deployment group create `
  --resource-group $RESOURCE_GROUP `
  --template-file src/infra/main.bicep `
  --parameters clusterName=$CLUSTER_NAME acrName=$ACR_NAME

# Save the outputs
$ACR_LOGIN_SERVER = az deployment group show `
  --resource-group $RESOURCE_GROUP `
  --name main `
  --query properties.outputs.acrLoginServer.value -o tsv

Write-Host "ACR Login Server: $ACR_LOGIN_SERVER"
```

### 1.4 Bicep Parameters Reference

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `clusterName` | Name of the AKS cluster | Required |
| `acrName` | Name of the ACR (must be globally unique) | Required |
| `location` | Azure region | Resource group location |
| `nodeVmSize` | VM size for AKS nodes | `Standard_B2s` |
| `nodeCount` | Number of AKS nodes (1-10) | `2` |
| `kubernetesVersion` | Kubernetes version | `1.28` |

**Custom deployment example:**

```powershell
az deployment group create `
  --resource-group $RESOURCE_GROUP `
  --template-file src/infra/main.bicep `
  --parameters `
    clusterName=$CLUSTER_NAME `
    acrName=$ACR_NAME `
    nodeVmSize="Standard_B4ms" `
    nodeCount=3 `
    kubernetesVersion="1.29"
```

## Step 2: Build and Push Docker Images

### 2.1 Login to ACR

```powershell
# Login to your Azure Container Registry
az acr login --name $ACR_NAME
```

### 2.2 Build Docker Images

```powershell
# Navigate to project root
cd C:\path\to\RustKubernetesDemo

# Build Rust API
docker build -t hello-rust-api:latest ./src/rust-api

# Build C# API
docker build -t hello-csharp-api:latest ./src/csharp-api
```

### 2.3 Tag and Push Images

```powershell
# Tag images for ACR
docker tag hello-rust-api:latest "$ACR_LOGIN_SERVER/hello-rust-api:latest"
docker tag hello-csharp-api:latest "$ACR_LOGIN_SERVER/hello-csharp-api:latest"

# Push images to ACR
docker push "$ACR_LOGIN_SERVER/hello-rust-api:latest"
docker push "$ACR_LOGIN_SERVER/hello-csharp-api:latest"

# Verify images in ACR
az acr repository list --name $ACR_NAME -o table
```

## Step 3: Configure Kubernetes Manifests

### 3.1 Update Image References

Before deploying, update the image paths in the Kubernetes manifests to use your ACR:

**src/k8s/rust-deployment.yaml** (line 29):

```yaml
image: <your-acr-name>.azurecr.io/hello-rust-api:latest
# Change to:
image: acrhelloapis123456.azurecr.io/hello-rust-api:latest
```

**src/k8s/csharp-deployment.yaml** (line 29):

```yaml
image: <your-acr-name>.azurecr.io/hello-csharp-api:latest
# Change to:
image: acrhelloapis123456.azurecr.io/hello-csharp-api:latest
```

**PowerShell replacement:**

```powershell
# Replace placeholder with your ACR name
(Get-Content src/k8s/rust-deployment.yaml) -replace '<your-acr-name>', $ACR_NAME | Set-Content src/k8s/rust-deployment.yaml
(Get-Content src/k8s/csharp-deployment.yaml) -replace '<your-acr-name>', $ACR_NAME | Set-Content src/k8s/csharp-deployment.yaml
```

**Bash replacement (Linux/macOS/WSL):**

```bash
# Replace placeholder with your ACR name
sed -i "s/<your-acr-name>/$ACR_NAME/g" src/k8s/rust-deployment.yaml
sed -i "s/<your-acr-name>/$ACR_NAME/g" src/k8s/csharp-deployment.yaml
```

### 3.2 Kubernetes Manifest Overview

| File | Purpose |
| ---- | ------- |
| `namespace.yaml` | Creates `hello-apis` namespace |
| `rust-deployment.yaml` | Deployment + Service for Rust API |
| `csharp-deployment.yaml` | Deployment + Service for C# API |

**Key configurations in deployments:**

- **Replicas:** 2 pods per API for high availability
- **Resources:** CPU/memory requests and limits defined
- **Health checks:** Liveness and readiness probes on `/health`
- **Security:** Non-root user, dropped capabilities, read-only filesystem (Rust)

## Step 4: Deploy to AKS

### 4.1 Get AKS Credentials

```powershell
# Configure kubectl to use your AKS cluster
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 4.2 Deploy Kubernetes Resources

```powershell
# Create namespace
kubectl apply -f src/k8s/namespace.yaml

# Deploy Rust API
kubectl apply -f src/k8s/rust-deployment.yaml

# Deploy C# API
kubectl apply -f src/k8s/csharp-deployment.yaml
```

### 4.3 Monitor Deployment Progress

```powershell
# Watch pods come up
kubectl get pods -n hello-apis -w

# Check deployment status
kubectl get deployments -n hello-apis

# View detailed pod status
kubectl describe pods -n hello-apis
```

## Step 5: Verify Deployment

### 5.1 Get Service External IPs

```powershell
# Get services (wait for EXTERNAL-IP to be assigned)
kubectl get services -n hello-apis

# Output example:
# NAME               TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)
# rust-hello-api     LoadBalancer   10.0.xxx.xxx   20.xxx.xxx.xxx  80:xxxxx/TCP
# csharp-hello-api   LoadBalancer   10.0.xxx.xxx   20.xxx.xxx.xxx  80:xxxxx/TCP
```

> **Note:** External IP assignment may take 1-2 minutes.

### 5.2 Test the APIs

```powershell
# Get external IPs
$RUST_IP = kubectl get svc rust-hello-api -n hello-apis -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$CSHARP_IP = kubectl get svc csharp-hello-api -n hello-apis -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "Rust API: http://$RUST_IP"
Write-Host "C# API: http://$CSHARP_IP"

# Test Rust API
curl http://$RUST_IP/
curl http://$RUST_IP/health
curl http://$RUST_IP/info

# Test C# API
curl http://$CSHARP_IP/
curl http://$CSHARP_IP/health
curl http://$CSHARP_IP/info
```

### 5.3 View Logs

```powershell
# View Rust API logs
kubectl logs -l app=rust-hello-api -n hello-apis --tail=50

# View C# API logs
kubectl logs -l app=csharp-hello-api -n hello-apis --tail=50

# Follow logs in real-time
kubectl logs -l app=rust-hello-api -n hello-apis -f
```

## Troubleshooting

### Pods not starting

```powershell
# Check pod status and events
kubectl describe pod <pod-name> -n hello-apis

# Common issues:
# - ImagePullBackOff: ACR authentication issue or wrong image name
# - CrashLoopBackOff: Application error, check logs
```

### ImagePullBackOff errors

```powershell
# Verify ACR role assignment
$ACR_ID = az acr show --name $ACR_NAME --query id -o tsv
az role assignment list --scope $ACR_ID -o table

# Verify image exists in ACR
az acr repository show --name $ACR_NAME --repository hello-rust-api
```

### Service has no External IP

```powershell
# Check service events
kubectl describe svc rust-hello-api -n hello-apis

# Verify load balancer is provisioning
kubectl get events -n hello-apis --sort-by='.lastTimestamp'
```

### Health check failures

```powershell
# Test health endpoint from within the cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -n hello-apis -- curl http://rust-hello-api:80/health
```

## Cleanup

### Delete Kubernetes Resources Only

```powershell
kubectl delete -f src/k8s/csharp-deployment.yaml
kubectl delete -f src/k8s/rust-deployment.yaml
kubectl delete -f src/k8s/namespace.yaml
```

### Delete All Azure Resources

```powershell
# Delete the entire resource group (includes AKS, ACR, and all resources)
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Verify deletion
az group list -o table
```

### Remove kubectl Context

```powershell
# Remove the AKS context from kubectl
kubectl config delete-context $CLUSTER_NAME

# Remove the cluster and user from kubeconfig
kubectl config delete-cluster $CLUSTER_NAME
kubectl config delete-user "clusterUser_${RESOURCE_GROUP}_${CLUSTER_NAME}"
```

## Quick Reference

### Environment Variables

```powershell
$RESOURCE_GROUP = "rg-hello-apis"
$LOCATION = "eastus"
$CLUSTER_NAME = "aks-hello-apis"
$ACR_NAME = "acrhelloapis<unique-suffix>"
$ACR_LOGIN_SERVER = "$ACR_NAME.azurecr.io"
```

### Common Commands

| Action | Command |
| ------ | ------- |
| View pods | `kubectl get pods -n hello-apis` |
| View services | `kubectl get svc -n hello-apis` |
| View logs | `kubectl logs -l app=rust-hello-api -n hello-apis` |
| Shell into pod | `kubectl exec -it <pod-name> -n hello-apis -- /bin/sh` |
| Scale deployment | `kubectl scale deployment rust-hello-api --replicas=3 -n hello-apis` |
| Restart deployment | `kubectl rollout restart deployment rust-hello-api -n hello-apis` |
| Update image | `kubectl set image deployment/rust-hello-api rust-hello-api=$ACR_LOGIN_SERVER/hello-rust-api:v2 -n hello-apis` |
