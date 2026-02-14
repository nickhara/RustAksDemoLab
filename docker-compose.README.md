# Docker Compose Configurations

This project includes two Docker Compose configurations to support different development workflows:

## 📁 **docker-compose.yml** (Default - Infrastructure Only)

**Usage:**
```bash
docker-compose up -d
# or
.\Deploy-Local.ps1
```

**What it includes:**
- ✅ RabbitMQ with Management UI
- ❌ Application services (run directly in dev container)

**Best for:**
- **Fast development iteration** - Apps run natively with hot reload
- **Debugging** - Direct access to debuggers and development tools
- **Resource efficiency** - Only infrastructure services containerized

---

## 📁 **docker-compose.full.yml** (Complete Containerized Setup)

**Usage:**
```bash
docker-compose -f docker-compose.full.yml up -d
# or
.\Deploy-Local.ps1 -UseDockerCompose
```

**What it includes:**
- ✅ RabbitMQ with Management UI  
- ✅ Rust API (port 8080)
- ✅ C# API (port 5000) 
- ✅ Worker Service

**Best for:**
- **Production-like testing** - All services containerized
- **Integration testing** - Complete system running together
- **Deployment validation** - Mirror production environment

---

## 🚀 **Quick Reference**

| Mode                   | Command                                | Use Case                    |
| ---------------------- | -------------------------------------- | --------------------------- |
| **Direct Execution**   | `.\Deploy-Local.ps1`                   | Development with hot reload |
| **Full Containerized** | `.\Deploy-Local.ps1 -UseDockerCompose` | Production-like testing     |
| **Kubernetes**         | `.\Deploy-Local.ps1 -UseKubernetes`    | Cloud-native development    |

## 🌐 **Access URLs**

| Service                 | URL                    | Credentials      |
| ----------------------- | ---------------------- | ---------------- |
| **Rust API**            | http://localhost:8080  | -                |
| **C# API**              | http://localhost:5000  | -                |
| **RabbitMQ Management** | http://localhost:15672 | admin / admin123 |

---

## 🛑 **Stopping Services**

```bash
# Infrastructure only
.\Deploy-Local.ps1 -Down

# Full containerized
.\Deploy-Local.ps1 -UseDockerCompose -Down  

# Kubernetes
.\Deploy-Local.ps1 -UseKubernetes -Down
```