# Dev Container Dual-Mode Service Management

This dev container supports **two development workflows** for maximum flexibility:

## 🏗️ Development Modes

### 1️⃣ Direct Execution Mode (Default)

- **Infrastructure services** (RabbitMQ) → Docker containers  
- **Application services** (Rust API, C# Worker, C# API) → Direct execution in dev container

### 2️⃣ Local Kubernetes Mode

- **All services** → Deployed to local Kubernetes cluster
- **Container images** → Built locally and deployed to K8s
- **Production-like** → Test Kubernetes manifests locally

## ✅ Benefits Comparison

| Feature | Direct Execution | Kubernetes Mode |
| --------- | ---------------- | ---------------- |
| **Development Speed** | ⚡ Fastest (hot reload) | 🔄 Medium (rebuild images) |
| **Debugging** | 🐞 Native IDE debugging | 📝 kubectl logs |
| **Environment** | 🏠 Dev container | ☸️ Production-like |
| **K8s Testing** | ❌ Not applicable | ✅ Full K8s validation |
| **Resource Usage** | 💚 Low | 📊 Higher |
| **Best For** | Active development | Integration/K8s testing |

## 🚀 Quick Start

### Mode Selector (Recommended)

```bash
./.devcontainer/dev-mode-selector.sh
```

Interactive menu to choose and start your preferred mode.

### Direct Commands

```bash
# Direct Execution Mode
./.devcontainer/start-dev.sh

# Kubernetes Mode  
kubectl apply -f ./src/k8s/local/
./.devcontainer/k8s-port-forward.sh
```

### VS Code Task Shortcuts

```bash
# Quick access to main workflows:
Ctrl+Shift+B           # Default build task
F1 → "Tasks: Run Test Task"  # Start All Services (default test)
Ctrl+Shift+P → Tasks    # Full task menu
```

## 🎮 VS Code Tasks

**Tasks are now organized into semantic groups for better VS Code integration:**

### 📦 BUILD Group - Compilation & Preparation

Access via: **Ctrl+Shift+P** → `Tasks: Run Build Task` or **Ctrl+Shift+B**

| Task | Purpose |
| ------ | --------- |
| **Build Rust API** | Compile Rust project |
| **Build C# Services** | Build all .NET projects |
| **🐳 Build Local Docker Images** | Build container images locally |
| **Clean Rust** | Clean Rust build artifacts |
| **Clean C#** | Clean .NET build artifacts |
| **Clean All** | Clean all artifacts + stop infrastructure |

### 🧪 TEST Group - Services & Testing

Access via: **Ctrl+Shift+P** → `Tasks: Run Test Task`

#### Direct Execution Mode Tasks

| Task | Purpose |
| ------ | --------- |
| **Start All Services** | Infrastructure + all application services ⭐ |
| **Start Infrastructure** | Just RabbitMQ in Docker |
| **Start Rust API** | Rust service with hot reload |
| **Start C# Worker** | Worker service with hot reload |
| **Start C# API** | ASP.NET Core API with hot reload |

#### Kubernetes Mode Tasks

| Task | Purpose |
| ------ | --------- |
| **☸️ Full K8s Setup** | Complete K8s deployment + port forwarding ⭐ |
| **☸️ Deploy to Local K8s** | Deploy all services to K8s cluster |
| **🔌 Start K8s Port Forwarding** | Expose services to localhost |
| **🗑️ Remove from Local K8s** | Clean up K8s deployment |
| **📊 K8s Status** | Check deployment status and logs |

#### Utility Tasks

| Task | Purpose |
| ------ | --------- |
| **🎮 Development Mode Selector** | Interactive mode selection |

⭐ = Default tasks for each group

## 🐞 Debugging

### Direct Execution Mode

1. Set breakpoints in your code
2. **F5** → Select debug configuration:
   - **"Debug Rust API"** - Full Rust debugging
   - **"Debug C# Worker Service"** - .NET worker debugging  
   - **"Debug C# API"** - ASP.NET Core debugging
   - **"Debug All Services"** - Multi-service debugging
3. Full debugging with variables, call stack, hot reload

### Kubernetes Debugging

```bash
# View all pods
kubectl get pods -n hello-apis-local

# Stream logs from specific service
kubectl logs -f deployment/rust-hello-api -n hello-apis-local
kubectl logs -f deployment/worker-service -n hello-apis-local

# Debug pod issues
kubectl describe pod <pod-name> -n hello-apis-local

# Execute commands in pod
kubectl exec -it <pod-name> -n hello-apis-local -- bash
```

## 📊 Service URLs (Both Modes)

| Service | URL | Credentials |
| --------- | ----- | ------------- |
| RabbitMQ Management | <http://localhost:15672> | admin/admin123 |
| Rust API | <http://localhost:8080> | - |
| C# API | <http://localhost:5000> | - |

Worker service runs in background (no web interface)

## 🔧 Environment Variables

### Direct Execution Environment

**Rust API:**

```bash
RUST_LOG=debug
PORT=8080
RABBITMQ_URL=amqp://admin:admin123@localhost:5672
RABBITMQ_QUEUE=task-queue
```

**C# Worker Service:**

```bash
RabbitMQ__Host=localhost
RabbitMQ__Port=5672
RabbitMQ__Username=admin
RabbitMQ__Password=admin123
RabbitMQ__Queue=task-queue
ProcessingDelayMs=2000
```

### Kubernetes Mode

**Environment variables are managed via K8s ConfigMaps and Secrets:**

- **ConfigMap**: `rabbitmq-config` (URLs, host, queue names)
- **Secret**: `rabbitmq-secret` (credentials)
- **Namespace**: `hello-apis-local`

## 🔄 Development Workflow Comparison

### Direct Execution Workflow

```bash
# 1. Start infrastructure and services
# VS Code: Ctrl+Shift+P → "Tasks: Run Test Task" → "Start All Services"
# OR manually: ./.devcontainer/start-dev.sh

# 2. Develop with hot reload
# Edit code → automatic reload

# 3. Debug natively  
# F5 → set breakpoints → debug

# 4. Test locally
curl http://localhost:8080/health

# 5. Build when ready
# VS Code: Ctrl+Shift+B (default build) or F1 → "Tasks: Run Build Task"
```

### Kubernetes Workflow

```bash
# 1. Build container images
# VS Code: Ctrl+Shift+B → "🐳 Build Local Docker Images"

# 2. Deploy to K8s
# VS Code: F1 → "Tasks: Run Test Task" → "☸️ Full K8s Setup"
# OR manually: kubectl apply -f ./src/k8s/local/

# 3. Expose services (included in Full K8s Setup)
# Manual: ./.devcontainer/k8s-port-forward.sh

# 4. Develop cycle
# Edit code → rebuild image → redeploy

# 5. Debug via logs
kubectl logs -f deployment/rust-hello-api -n hello-apis-local

# 6. Check status
# VS Code: "📊 K8s Status" task
```

## 🛠️ Local Kubernetes Prerequisites

### Supported Local Clusters

- **Docker Desktop Kubernetes** (simplest)
- **minikube** (`minikube start`)
- **kind** (`kind create cluster`)  
- **k3s** (lightweight K8s)

### Verification

```bash
# Check cluster connectivity
kubectl cluster-info

# Verify node status
kubectl get nodes

# Check available storage classes
kubectl get storageclass
```

## 🚨 Troubleshooting

### Direct Execution Issues

**RabbitMQ not starting?**

```bash
# Check Docker status
docker ps | grep rabbitmq

# View RabbitMQ logs
docker logs rabbitmq

# Restart infrastructure
docker-compose restart rabbitmq
```

**Service can't connect to RabbitMQ?**

- Ensure RabbitMQ started first
- Check URL: `localhost:5672` (not `rabbitmq:5672`)
- Verify credentials: `admin/admin123`

### Kubernetes Environment

**Images not found?**

```bash
# Verify local images exist
docker images | grep ":local"

# Rebuild if missing
./.devcontainer/build-local-images.sh
```

**Pods not starting?**

```bash
# Check pod status
kubectl get pods -n hello-apis-local

# Describe problematic pod
kubectl describe pod <pod-name> -n hello-apis-local

# View pod logs
kubectl logs <pod-name> -n hello-apis-local
```

**Port forwarding not working?**

```bash
# Kill existing port forwarding
pkill -f "kubectl port-forward"

# Restart port forwarding
./.devcontainer/k8s-port-forward.sh
```

**Storage issues?**

```bash
# Check persistent volumes
kubectl get pv,pvc -n hello-apis-local

# For minikube, enable storage addon
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
```

## 🎯 When to Use Each Mode

### Use Direct Execution Mode When

- ✅ Actively developing application code  
- ✅ Need fast iteration cycles
- ✅ Want to debug with breakpoints
- ✅ Testing business logic
- ✅ Working on API endpoints or background processing

### Use Kubernetes Mode When

- ✅ Testing Kubernetes manifests
- ✅ Validating container configurations
- ✅ Integration testing with K8s features
- ✅ Testing resource limits and requests
- ✅ Preparing for cloud deployment
- ✅ Load testing with horizontal scaling

## 🎉 Summary

**Two powerful development workflows in one dev container:**

1. **🏃 Direct Execution**: Fast development with native debugging
2. **☸️ Kubernetes**: Production-like testing with local cluster

**Semantic task organization for better VS Code integration:**

- **📦 BUILD tasks**: Compilation, Docker images, cleanup
- **🧪 TEST tasks**: Services, deployment, validation
- **Quick access**: Ctrl+Shift+B for builds, F1→"Run Test Task" for services

**Switch between modes easily:**

- **🎮 Development Mode Selector** task for guided setup
- Both modes use the same RabbitMQ configuration
- Same service URLs for seamless workflow switching
- Optimized VS Code task integration

**Best practice**: Develop in Direct Mode, validate in Kubernetes Mode before deploying to cloud!

---

🎯 **Result**: Maximum flexibility for both rapid development and thorough Kubernetes
testing in a single dev container environment with optimized VS Code workflow integration!
