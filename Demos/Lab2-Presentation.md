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

# Lab 2: Message Queue with RabbitMQ & Auto-Scaling

## Building Async Processing and Auto-Scaling on AKS

Extending Lab 1 with Message Queuing and Horizontal Pod Autoscaling

![bg right:40% 80%](https://azure.microsoft.com/svghandler/kubernetes-service/?width=600&height=315)

---

# Agenda

1. **What We're Building** - Extending Lab 1 with async processing
2. **Architecture** - Local and AKS deployments
3. **Message Flow** - How messages travel through the system
4. **Horizontal Pod Autoscaler (HPA)** - Auto-scaling workers
5. **Demo: Local Development** - Docker Compose environment
6. **Demo: Sending Messages** - Testing the message queue
7. **Demo: Monitoring** - Queue status and HPA metrics
8. **Demo: AKS Deployment** - Production deployment
9. **Testing & Validation** - PowerShell test scripts
10. **Troubleshooting** - Common issues and solutions

---

# What We're Building and Why

Building upon Lab 1, we're adding **asynchronous message processing** with:

1. **Message Queue Pattern** - Decouple API from background work
2. **RabbitMQ** - Industry-standard message broker
3. **Worker Pool** - C# background services processing tasks
4. **Auto-Scaling** - Kubernetes HPA scales workers dynamically

### Why This Matters

- Handle high traffic without blocking API responses
- Process work in background (emails, reports, data processing)
- Scale workers independently from API
- Learn cloud-native patterns used in production

---

# New Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Enhanced Rust API** | Actix-web | `/send` endpoint publishes to queue |
| **RabbitMQ** | Message Broker | Reliable task queuing (AMQP) |
| **Worker Service** | C# .NET 10 | Background processing (2-sec delay) |
| **HPA** | Kubernetes | Auto-scales workers (1-10 pods) |
| **Metrics Server** | Kubernetes | Provides CPU/memory metrics |

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/send` | POST | Publish message to RabbitMQ queue |
| `/health` | GET | Health check endpoint |
| `/info` | GET | API version info |

---

# Architecture: Local Docker Compose

```
┌─────────────────────────────────────────────────────────────┐
│              Local Development Machine                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 Docker Compose                         │ │
│  │                                                        │ │
│  │   ┌────────────────┐      ┌─────────────────┐          │ │
│  │   │  rust-api      │      │   rabbitmq      │          │ │
│  │   │  Port: 8080    │─────►│   Container     │          │ │
│  │   │                │ pub  │                 │          │ │
│  │   │  POST /send    │      │  Queue:         │          │ │
│  │   └────────────────┘      │  task-queue     │          │ │
│  │                           │                 │          │ │
│  │                           │  Ports:         │          │ │
│  │                           │  - 5672 (AMQP)  │          │ │
│  │                           │  - 15672 (UI)   │          │ │
│  │                           └────────┬────────┘          │ │
│  │                                    │ consume           │ │
│  │                           ┌────────▼────────┐          │ │
│  │                           │  worker-service │          │ │
│  │                           │  (2-sec delay)  │          │ │
│  │                           └─────────────────┘          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

# Architecture: Azure Kubernetes Service

```
┌───────────────────────────────────────────────────────────────┐
│                    Azure Resource Group                       │
│  ┌───────────────┐       ┌──────────────────────────────────┐ │
│  │               │       │        AKS Cluster               │ │
│  │  Azure        │       │  ┌────────────────────────────┐  │ │
│  │  Container    │◄──────│  │   hello-apis namespace     │  │ │
│  │  Registry     │ pull  │  │                            │  │ │
│  │               │       │  │  ┌──────┐  ┌──────────┐    │  │ │
│  │  Images:      │       │  │  │ Rust │  │ RabbitMQ │    │  │ │
│  │  - rust-api   │       │  │  │ API  │─►│   Pod    │    │  │ │
│  │  - worker     │       │  │  └──────┘  │  Queue   │    │  │ │
│  │  - rabbitmq   │       │  │            └────┬─────┘    │  │ │
│  └───────────────┘       │  │                 │          │  │ │
│                          │  │      ┌──────────▼────────┐ │  │ │
│                          │  │      │   Worker Pods     │ │  │ │
│                          │  │      │  ┌───┐ ┌───┐      │ │  │ │
│                          │  │      │  │W-1│ │W-2│ ...  │ │  │ │
│                          │  │      │  └───┘ └───┘      │ │  │ │
│                          │  │      │  HPA: 1-10 pods   │ │  │ │
│                          │  │      │  Target: 70% CPU  │ │  │ │
│                          │  │      └───────────────────┘ │  │ │
│                          │  └────────────────────────────┘  │ │
│                          │       Load Balancer              │ │
│                          └──────────┬───────────────────────┘ │
└─────────────────────────────────────┼─────────────────────────┘
                                Internet
```

---

# Message Flow

```text
1. Client Request          2. Queue Storage         3. Worker Processing

┌──────────┐              ┌───────────────┐         ┌──────────────┐
│  Client  │              │   RabbitMQ    │         │    Worker    │
│   curl   │              │               │         │   Pod 1      │
└────┬─────┘              │  ┌─────────┐  │         └──────┬───────┘
     │                    │  │ task-   │  │                │
     │ POST /send         │  │ queue   │  │                │
     ├───────────────────►│  │         │  │                │
     │ {task_type, data}  │  │ [M][M]  │◄─┤ CONSUME        │
     │                    │  │ [M][M]  │  │                │
     │ 200 OK             │  │ [M]     │  │                │
     │◄───────────────────┤  └─────────┘  │   ┌──────────┐ │
     │ {message_id: ...}  │               │   │ Process  │ │
     └────────────────────┘               │   │ 2-sec    │ │
                                          │   │ delay    │ │
                          ┌──────────────┐│   └────┬─────┘ │
                          │    Worker    ││        │       │
                          │    Pod 2     ││        │ ACK   │
                          └──────┬───────┘│        ├──────►│
                                 │        │        │       │
                                 │ CONSUME│   ┌────▼─────┐ │
                                 ├────────┤   │ Complete │ │
                                          │   └──────────┘ │
                           HPA monitors   └────────────────┘
                           CPU and scales
```

---

# Message Structure

### JSON Format

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "task_type": "process_data",
  "payload": {
    "key1": "value1",
    "key2": "value2"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique message identifier |
| `task_type` | string | Type of task to process |
| `payload` | object | Task-specific data |
| `timestamp` | ISO 8601 | Message creation time |

---

# Horizontal Pod Autoscaler (HPA)

### What is HPA?

Kubernetes HPA automatically scales the number of pods based on metrics like CPU or memory utilization.

### HPA Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: worker-hpa
spec:
  scaleTargetRef:
    kind: Deployment
    name: worker-service
  minReplicas: 1              # Minimum pods
  maxReplicas: 10             # Maximum pods
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70  # Target 70% CPU
```

---

# How HPA Works

### Scaling Algorithm

```text
desired_replicas = ceil(current_replicas * (current_metric / target_metric))

Example:
- Current: 2 replicas at 90% CPU
- Target: 70% CPU
- Desired: ceil(2 * (90 / 70)) = ceil(2.57) = 3 replicas
```

### Scaling Process

1. **Metrics Collection** - Queries metrics-server every 15 seconds
2. **Calculation** - Compares current vs target CPU (70%)
3. **Decision** - Determines desired replica count
4. **Scaling** - Adjusts deployment up or down
5. **Cooldown** - Waits 3-5 minutes before scaling again

---

# HPA Scaling Triggers

### Scale Up (CPU > 70%)

- ✅ High message volume in queue
- ✅ Workers processing continuously
- ✅ Each message takes 2+ seconds
- ✅ Multiple messages queued per worker

### Scale Down (CPU < 70%)

- ✅ Queue empty or low message count
- ✅ Workers idle most of the time
- ✅ CPU drops below 70% target
- ✅ Cooldown period (5 minutes) passed

---

# Demo: Local Development

### Start Docker Compose Stack

```powershell
# Navigate to project root
cd E:\Code\RustAksDemoLab

# Start all services
docker-compose up -d

# Verify services are running
docker-compose ps

# View logs
docker-compose logs -f
```

### Access Points

- **API:** <http://localhost:8080>
- **RabbitMQ Management UI:** <http://localhost:15672>
  - Username: `admin`
  - Password: `admin123`

---

# Demo: Sending Messages

### Single Message

```powershell
# Send a test message
$response = Invoke-RestMethod -Uri "http://localhost:8080/send" `
  -Method POST -ContentType "application/json" -Body '{
    "task_type": "test_task",
    "payload": {
      "message": "Hello RabbitMQ!"
    }
  }'

$response | ConvertTo-Json
```

### Expected Response

```json
{
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued",
  "queue": "task-queue"
}
```

---

# Demo: Bulk Message Sending

### Load Test Script

```powershell
# Send 100 messages to trigger scaling
1..100 | ForEach-Object {
    $body = @{
        task_type = "load_test"
        payload = @{
            batch_id = $_
            timestamp = Get-Date -Format "o"
        }
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:8080/send" `
      -Method POST -ContentType "application/json" -Body $body
    
    if ($_ % 10 -eq 0) {
        Write-Host "Sent $_ messages..."
    }
}

Write-Host "✅ Sent 100 messages!"
```

---

# Demo: Monitoring Queue

### RabbitMQ Management UI

1. Open <http://localhost:15672>
2. Login: `admin` / `admin123`
3. Navigate to **Queues** tab
4. Monitor **task-queue**:
   - Message rate (publish/consume)
   - Total messages
   - Ready messages
   - Unacknowledged messages

### Check Worker Logs

```powershell
# Watch worker processing messages
docker-compose logs -f worker-service

# Expected output:
# [INFO] Processing message: 550e8400-e29b-41d4...
# [INFO] Task type: test_task
# [INFO] Simulating work (2 seconds)...
# [INFO] Message processed successfully
```

---

# Demo: AKS Deployment

### Prerequisites Check

```powershell
# Verify Lab 1 infrastructure
$RESOURCE_GROUP = "rg-hello-apis"
$CLUSTER_NAME = "aks-hello-apis"
$ACR_NAME = "acrhelloapis<suffix>"

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP `
                       --name $CLUSTER_NAME --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

# Demo: Build and Push Images

```powershell
# Login to ACR
az acr login --name $ACR_NAME

# Build images (from project root)
docker build -t $ACR_NAME.azurecr.io/rust-api-mq:latest `
  ./src/rust-api-mq
docker build -t $ACR_NAME.azurecr.io/worker-service:latest `
  ./src/worker-service

# Push to ACR
docker push $ACR_NAME.azurecr.io/rust-api-mq:latest
docker push $ACR_NAME.azurecr.io/worker-service:latest

# Use official RabbitMQ image
docker pull rabbitmq:3-management
docker tag rabbitmq:3-management $ACR_NAME.azurecr.io/rabbitmq:3-management
docker push $ACR_NAME.azurecr.io/rabbitmq:3-management
```

---

# Demo: Deploy to AKS

### Apply Kubernetes Manifests

```powershell
# Deploy RabbitMQ
kubectl apply -f src/k8s-lab2/rabbitmq-deployment.yaml

# Deploy Rust API
kubectl apply -f src/k8s-lab2/rust-api-mq-deployment.yaml

# Deploy Worker Service
kubectl apply -f src/k8s-lab2/worker-deployment.yaml

# Deploy HPA
kubectl apply -f src/k8s-lab2/worker-hpa.yaml

# Watch pods come up
kubectl get pods -n hello-apis -w
```

---

# Demo: Testing on AKS

### Get API External IP

```powershell
# Wait for external IP assignment
kubectl get svc rust-api-mq -n hello-apis -w

# Get IP address
$API_IP = kubectl get svc rust-api-mq -n hello-apis `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "API URL: http://$API_IP"

# Test connectivity
Invoke-RestMethod -Uri "http://$API_IP/health"
```

---

# Demo: Load Testing & HPA

### Generate Load

```powershell
# Send 200 messages to trigger scaling
1..200 | ForEach-Object {
    $body = @{
        task_type = "load_test_aks"
        payload = @{ batch = $_ }
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://${API_IP}/send" `
      -Method POST -ContentType "application/json" -Body $body
}
```

### Watch HPA Scale

```powershell
# Monitor HPA in real-time
kubectl get hpa worker-hpa -n hello-apis -w

# Expected output:
# NAME         REFERENCE                    TARGETS   MINPODS   MAXPODS   REPLICAS
# worker-hpa   Deployment/worker-service   85%/70%   1         10        1
# worker-hpa   Deployment/worker-service   85%/70%   1         10        3
# worker-hpa   Deployment/worker-service   75%/70%   1         10        4
```

---

# Key Features

### 1. Auto-Scaling

- **Dynamic scaling** based on CPU utilization
- **Min 1 pod** to handle light loads
- **Max 10 pods** for burst traffic
- **70% CPU target** balances performance and cost

### 2. Message Queue Benefits

- **Decoupled architecture** - API responds immediately
- **Reliable processing** - Messages persist in RabbitMQ
- **Load leveling** - Queue absorbs traffic spikes
- **Retry logic** - Failed messages can be reprocessed

---

# Key Features (cont.)

### 3. Monitoring & Observability

```powershell
# Check worker pod count
kubectl get pods -l app=worker-service -n hello-apis

# View CPU metrics
kubectl top pods -l app=worker-service -n hello-apis

# Check HPA status
kubectl describe hpa worker-hpa -n hello-apis

# View scaling events
kubectl get events -n hello-apis --sort-by='.lastTimestamp'
```

---

# Testing & Validation Scripts

### Provided PowerShell Scripts

| Script | Purpose |
|--------|---------|
| `Test-LocalQueue.ps1` | Test Docker Compose locally |
| `Test-AKSQueue.ps1` | Test AKS deployment |
| `Test-HPAScaling.ps1` | Generate load and watch HPA |
| `Get-QueueMetrics.ps1` | Monitor queue and pod metrics |

### Running Test Scripts

```powershell
# Local testing
.\scripts\Test-LocalQueue.ps1 -MessageCount 50

# AKS load test
.\scripts\Test-HPAScaling.ps1 -MessageCount 500

# Monitor metrics
.\scripts\Get-QueueMetrics.ps1 -Watch
```

---

# HPA Scaling Scenarios

### Scenario 1: Light Load

| Metric | Value |
|--------|-------|
| Messages/sec | 0.5 |
| Worker pods | 1 |
| CPU utilization | 20% |
| Queue depth | 0-2 |

### Scenario 2: Medium Load

| Metric | Value |
|--------|-------|
| Messages/sec | 5 |
| Worker pods | 3-4 |
| CPU utilization | 70% |
| Queue depth | 5-10 |

---

# HPA Scaling Scenarios (cont.)

### Scenario 3: High Load

| Metric | Value |
|--------|-------|
| Messages/sec | 15+ |
| Worker pods | 8-10 |
| CPU utilization | 80-90% |
| Queue depth | 50+ |

### Scenario 4: Scale Down

- Queue empties after peak
- Workers become idle
- CPU drops to 30%
- After 5 min cooldown: scales down to 2-3 pods
- Eventually reaches minimum (1 pod)

---

# Troubleshooting: Common Issues

### Workers Not Scaling

```powershell
# Check metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Verify HPA can read metrics
kubectl get hpa worker-hpa -n hello-apis
# Look for "unknown" in TARGETS column

# Check pod resource requests are defined
kubectl get pod <worker-pod> -n hello-apis -o yaml | Select-String "resources"
```

### Messages Not Processing

```powershell
# Check RabbitMQ connectivity
kubectl logs -l app=worker-service -n hello-apis | Select-String "connection"

# Verify queue exists
kubectl exec -it <rabbitmq-pod> -n hello-apis -- rabbitmqctl list_queues
```

---

# Troubleshooting: Debugging

### View Logs

```powershell
# API logs
kubectl logs -l app=rust-api-mq -n hello-apis --tail=50

# Worker logs
kubectl logs -l app=worker-service -n hello-apis --tail=100 -f

# RabbitMQ logs
kubectl logs -l app=rabbitmq -n hello-apis --tail=50
```

### Check Pod Status

```powershell
# Describe pod for events
kubectl describe pod <pod-name> -n hello-apis

# Check resource usage
kubectl top pod <pod-name> -n hello-apis
```

---

# Troubleshooting: Network Issues

### Test Internal Connectivity

```powershell
# Shell into API pod
kubectl exec -it <rust-api-pod> -n hello-apis -- /bin/sh

# Test RabbitMQ connection (if tools available)
# telnet rabbitmq 5672
# nc -zv rabbitmq 5672

# Check DNS resolution
# nslookup rabbitmq
```

### Verify Services

```powershell
# Check service endpoints
kubectl get endpoints -n hello-apis

# Describe service
kubectl describe svc rabbitmq -n hello-apis
```

---

# Cleanup

### Stop Local Environment

```powershell
# Stop Docker Compose
docker-compose down

# Remove volumes (optional)
docker-compose down -v
```

### Delete AKS Resources

```powershell
# Delete Lab 2 deployments
kubectl delete -f src/k8s-lab2/

# Or delete specific resources
kubectl delete deployment rust-api-mq -n hello-apis
kubectl delete deployment worker-service -n hello-apis
kubectl delete deployment rabbitmq -n hello-apis
kubectl delete hpa worker-hpa -n hello-apis
kubectl delete svc rust-api-mq rabbitmq -n hello-apis
```

---

# Cleanup (cont.)

### Keep or Delete Infrastructure

**Keep for Lab 3** (recommended):

```powershell
# AKS and ACR remain for future labs
# Only delete Lab 2 Kubernetes resources (previous slide)
```

**Complete Cleanup**:

```powershell
# Delete entire resource group (removes AKS, ACR, everything)
az group delete --name rg-hello-apis --yes --no-wait

# Remove kubectl context
kubectl config delete-context aks-hello-apis
```

---

# Summary

### What We Accomplished

1. ✅ **Extended Lab 1** with async message processing
2. ✅ **Deployed RabbitMQ** for reliable message queuing
3. ✅ **Built Worker Service** to process background tasks
4. ✅ **Configured HPA** for automatic scaling (1-10 pods)
5. ✅ **Tested Locally** with Docker Compose
6. ✅ **Deployed to AKS** with load balancer
7. ✅ **Validated Auto-Scaling** with load tests
8. ✅ **Monitored Metrics** with kubectl and RabbitMQ UI

---

# Summary: Key Learnings

### Cloud-Native Patterns

| Pattern | Benefit |
|---------|---------|
| **Message Queue** | Decouples API from processing |
| **Worker Pool** | Parallel processing of tasks |
| **Auto-Scaling** | Elastic compute based on demand |
| **Health Probes** | Auto-recovery of failed pods |
| **Resource Limits** | Predictable performance |

### Production Readiness

- Handles traffic spikes gracefully
- Scales automatically (no manual intervention)
- Monitors resource utilization
- Provides observability with logs and metrics

---

# Summary: Next Steps

### Continue Learning

1. **Lab 3** - Add monitoring with Prometheus & Grafana
2. **Lab 4** - Implement CI/CD pipelines
3. **Optimize HPA** - Tune scaling parameters for your workload
4. **Add Persistence** - Use Azure Storage for queue persistence
5. **Implement Dead Letter Queue** - Handle failed messages

### Resources

- 📁 GitHub: [RustAksDemoLab](https://github.com/your-repo)
- 📖 Docs: `docs/Lab2.MessageQueue.md`
- 🔧 Scripts: `.test/Test-*.ps1` and `.deploy/`

---

# Questions?

![bg right:50% 80%](https://azure.microsoft.com/svghandler/kubernetes-service/?width=600&height=315)

### Thank you

**Key Takeaways:**

- Message queues enable scalable async processing
- HPA automatically adjusts compute to workload
- Kubernetes makes scaling seamless
- Docker Compose great for local development

**Lab 2 Complete!** 🚀
