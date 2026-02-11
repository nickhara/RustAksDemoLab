# Local Kubernetes Manifests

This directory contains Kubernetes manifests optimized for local development and testing.

## 📁 Files

- `rabbitmq-local.yaml` - RabbitMQ message broker with persistent storage
- `rust-api-local.yaml` - Rust API service deployment
- `worker-service-local.yaml` - C# background worker service
- `csharp-api-local.yaml` - C# API service (optional)

## 🏠 Local Development Optimizations

These manifests differ from production versions in several ways:

### **Docker Images**
- Uses locally built images with `:local` tags
- `imagePullPolicy: Never` to use local images only
- No container registry dependencies

### **Resource Requirements**
- Lower CPU/memory requests for development
- More generous limits for debugging
- Single replicas for easier debugging

### **Configuration**
- Simplified secrets (plaintext for local dev)
- Debug-level logging enabled
- Development environment variables

### **Storage**
- Smaller persistent volume claims
- Local storage class compatibility

### **Networking**  
- ClusterIP services for port-forward access
- No LoadBalancer dependencies
- Namespace: `hello-apis-local`

## 🚀 Usage

### Deploy All Services:
```bash
kubectl apply -f ./src/k8s/local/
```

### Check Status:
```bash
kubectl get all -n hello-apis-local
```

### Port Forward Services:
```bash
# RabbitMQ Management
kubectl port-forward -n hello-apis-local service/rabbitmq 15672:15672

# Rust API
kubectl port-forward -n hello-apis-local service/rust-hello-api 8080:8080

# C# API
kubectl port-forward -n hello-apis-local service/csharp-hello-api 5000:5000
```

### View Logs:
```bash
# Rust API logs
kubectl logs -f deployment/rust-hello-api -n hello-apis-local

# Worker service logs
kubectl logs -f deployment/worker-service -n hello-apis-local
```

### Clean Up:
```bash
kubectl delete -f ./src/k8s/local/
```

## 🔧 Prerequisites

**Local Kubernetes cluster** (one of):
- Docker Desktop with Kubernetes enabled
- minikube (`minikube start`)
- kind (`kind create cluster`)
- k3s or other lightweight K8s

**Built container images:**
```bash
# Run this first to build local images
./.devcontainer/build-local-images.sh
```

## 🎯 vs Production Manifests

| Feature | Local (`/local/`) | Production (`/`) |
|---------|-------------------|------------------|
| **Images** | Local `:local` tags | ACR registry images |
| **Secrets** | Plaintext for dev | Secure secret refs |
| **Resources** | Development sized | Production sized |
| **Replicas** | 1 for debugging | Multiple for HA |
| **Storage** | Basic PVC | Production storage classes |
| **Logging** | Debug level | Info/Warn level |

Use local manifests for development and testing, production manifests for cloud deployment.