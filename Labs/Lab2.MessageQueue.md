# Lab 2: Message Queue Processing with RabbitMQ and Horizontal Pod Autoscaling

Building upon the foundational knowledge from Lab 1, this lab introduces asynchronous message processing with RabbitMQ, demonstrating how to implement a distributed task queue system with automatic scaling capabilities. The system consists of:

- **Rust API** - Enhanced with `/send` endpoint to publish messages to RabbitMQ
- **RabbitMQ** - Message broker for reliable task queuing
- **C# Worker Service** - Background worker that processes messages from the queue
- **Horizontal Pod Autoscaler (HPA)** - Automatically scales workers based on CPU utilization

This lab demonstrates cloud-native patterns including message queuing, worker pools, and auto-scaling in Kubernetes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Message Format and Flow](#message-format-and-flow)
- [Local Development with Docker Compose](#local-development-with-docker-compose)
- [AKS Deployment](#aks-deployment)
- [Testing the System](#testing-the-system)
- [Horizontal Pod Autoscaler (HPA)](#horizontal-pod-autoscaler-hpa)
- [PowerShell Test Scripts](#powershell-test-scripts)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Quick Reference](#quick-reference)

## Prerequisites

This lab builds upon Lab 1. You must complete Lab 1 first to have the foundational infrastructure and understanding.

### Required from Lab 1
- Azure Container Registry (ACR) deployed
- AKS Cluster running
- kubectl configured for your AKS cluster
- Docker Desktop installed and running
- Azure CLI authenticated

### Additional Tools

| Tool | Purpose | Installation Check |
| ---- | ------- | ------------------ |
| Docker Compose | Multi-container local orchestration | `docker-compose --version` |
| PowerShell 7+ | Test script execution | `$PSVersionTable.PSVersion` |

### Verify Lab 1 Infrastructure

```powershell
# Verify Azure resources exist
$RESOURCE_GROUP = "rg-hello-apis"
$CLUSTER_NAME = "aks-hello-apis"
$ACR_NAME = "acrhelloapis<your-unique-suffix>"

# Check resource group
az group show --name $RESOURCE_GROUP

# Verify AKS cluster
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Verify ACR
az acr show --name $ACR_NAME

# Check kubectl connection
kubectl cluster-info
kubectl get nodes
```

## Architecture Overview

### Component Roles

| Component | Technology | Port(s) | Purpose |
|-----------|------------|---------|---------|
| **Rust API** | Rust (Actix-web) | 8080 | HTTP API with `/send` endpoint to publish messages |
| **RabbitMQ** | RabbitMQ 3.x | 5672 (AMQP)<br>15672 (Management UI) | Message broker for task queuing |
| **Worker Service** | C# (.NET 10) | N/A | Background service consuming and processing messages |
| **HPA** | Kubernetes | N/A | Auto-scales worker pods based on CPU metrics |

### Local Development Architecture (Docker Compose)

```text
┌─────────────────────────────────────────────────────────────────────┐
│                     Local Development Machine                       │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                       Docker Compose                           │ │
│  │                                                                │ │
│  │   ┌────────────────┐      ┌─────────────────┐                 │ │
│  │   │  rust-api      │      │   rabbitmq      │                 │ │
│  │   │  Container     │─────►│   Container     │                 │ │
│  │   │                │ pub  │                 │                 │ │
│  │   │  POST /send    │      │  Queue:         │                 │ │
│  │   │  Port: 8080    │      │  task-queue     │                 │ │
│  │   └────────────────┘      │                 │                 │ │
│  │                           │  Ports:         │                 │ │
│  │                           │  - 5672 (AMQP)  │                 │ │
│  │                           │  - 15672 (UI)   │                 │ │
│  │                           └────────┬────────┘                 │ │
│  │                                    │ consume                  │ │
│  │                           ┌────────▼────────┐                 │ │
│  │                           │  worker-service │                 │ │
│  │                           │  Container      │                 │ │
│  │                           │                 │                 │ │
│  │                           │  (2-sec delay)  │                 │ │
│  │                           └─────────────────┘                 │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  Access Points:                                                     │
│  - API: http://localhost:8080                                       │
│  - RabbitMQ UI: http://localhost:15672 (admin/admin123)             │
└─────────────────────────────────────────────────────────────────────┘
```

### Azure Kubernetes Architecture (AKS)

```text
┌──────────────────────────────────────────────────────────────────────┐
│                      Azure Resource Group                            │
│  ┌────────────────┐       ┌──────────────────────────────────────┐  │
│  │                │       │         AKS Cluster                  │  │
│  │  Azure         │       │  ┌────────────────────────────────┐  │  │
│  │  Container     │◄──────│  │    hello-apis namespace        │  │  │
│  │  Registry      │ pull  │  │                                │  │  │
│  │                │       │  │  ┌──────────┐  ┌───────────┐   │  │  │
│  │  Images:       │       │  │  │ Rust API │  │ RabbitMQ  │   │  │  │
│  │  - rust-api    │       │  │  │  (Pod)   │─►│   (Pod)   │   │  │  │
│  │  - worker      │       │  │  └──────────┘  │  Queue:   │   │  │  │
│  │  - rabbitmq    │       │  │                │ task-queue│   │  │  │
│  └────────────────┘       │  │                └─────┬─────┘   │  │  │
│                           │  │                      │         │  │  │
│                           │  │        ┌─────────────┴─────┐   │  │  │
│                           │  │        │   Worker Pods     │   │  │  │
│                           │  │        │  ┌───┐ ┌───┐      │   │  │  │
│                           │  │        │  │W-1│ │W-2│ ...  │   │  │  │
│                           │  │        │  └───┘ └───┘      │   │  │  │
│                           │  │        │                   │   │  │  │
│                           │  │        │  Managed by HPA   │   │  │  │
│                           │  │        │  Min: 1, Max: 10  │   │  │  │
│                           │  │        │  Target: 70% CPU  │   │  │  │
│                           │  │        └───────────────────┘   │  │  │
│                           │  └────────────────────────────────┘  │  │
│                           │          Load Balancer                │  │
│                           └───────────────┬───────────────────────┘  │
└───────────────────────────────────────────┼──────────────────────────┘
                                     Internet
                                        │
                                  Users/Scripts
```

### Message Flow Diagram

```text
1. Client Request          2. Publish to Queue      3. Worker Processing
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
                           workers (1-10)
```

## Message Format and Flow

### Message Structure

Messages published to RabbitMQ follow this JSON format:

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
| `id` | string (UUID) | Unique message identifier |
| `task_type` | string | Type of task to process |
| `payload` | object | Task-specific data |
| `timestamp` | string (ISO 8601) | Message creation time |

### Processing Flow

1. **Client Sends Request**: HTTP POST to `/send` endpoint with task data
2. **Rust API Publishes**: API serializes message and publishes to `task-queue`
3. **RabbitMQ Queues**: Message stored until a worker is available
4. **Worker Consumes**: Worker pod pulls message from queue
5. **Processing**: Worker simulates processing with 2-second delay
6. **Acknowledgment**: Worker acknowledges message completion
7. **Auto-scaling**: HPA monitors CPU and scales workers as needed

### Environment Variables

**Rust API:**

```text
RABBITMQ_HOST=rabbitmq          # RabbitMQ service hostname
RABBITMQ_PORT=5672              # AMQP port
RABBITMQ_USER=admin             # Authentication username
RABBITMQ_PASS=admin123          # Authentication password
RABBITMQ_QUEUE=task-queue       # Queue name
```

**Worker Service:**

```text
RabbitMQ__Host=rabbitmq         # RabbitMQ service hostname
RabbitMQ__Port=5672             # AMQP port
RabbitMQ__Username=admin        # Authentication username
RabbitMQ__Password=admin123     # Authentication password
RabbitMQ__QueueName=task-queue  # Queue name
```

**RabbitMQ:**

```text
RABBITMQ_DEFAULT_USER=admin     # Default admin username
RABBITMQ_DEFAULT_PASS=admin123  # Default admin password
```

> **Security Note**: In production, use Kubernetes Secrets for credentials. These defaults are for demo purposes only.

## Local Development with Docker Compose

Docker Compose provides the easiest way to run and test the entire system locally.

### 1.1 Docker Compose Overview

The `docker-compose.yml` file defines three services:

```yaml
services:
  rust-api:       # HTTP API with /send endpoint
  rabbitmq:       # Message broker
  worker-service: # Background message processor
```

### 1.2 Start All Services

```powershell
# Navigate to project root
cd E:\Code\RustAksDemoLab

# Start all services (builds images if needed)
docker-compose up --build

# Run in detached mode (background)
docker-compose up -d --build
```

**Expected output:**

```text
[+] Running 3/3
 ✔ Container rustaksdemolab-rabbitmq-1        Started
 ✔ Container rustaksdemolab-rust-api-1        Started
 ✔ Container rustaksdemolab-worker-service-1  Started
```

### 1.3 Verify Services are Running

```powershell
# Check container status
docker-compose ps

# View logs from all services
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# View specific service logs
docker-compose logs rust-api
docker-compose logs worker-service
docker-compose logs rabbitmq
```

### 1.4 Access RabbitMQ Management UI

1. Open browser to [http://localhost:15672](http://localhost:15672)
2. Login with credentials:
   - **Username**: `admin`
   - **Password**: `admin123`
3. Navigate to **Queues** tab to see `task-queue`

### 1.5 Test Message Sending

**Send a single message:**

```powershell
# Basic test message
curl -X POST http://localhost:8080/send `
  -H "Content-Type: application/json" `
  -d '{
    "task_type": "process_data",
    "payload": {
      "test": "hello world"
    }
  }'
```

**Expected response:**

```json
{
  "status": "queued",
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "queue": "task-queue"
}
```

**Send multiple messages:**

```powershell
# Send 10 messages
1..10 | ForEach-Object {
    curl -X POST http://localhost:8080/send `
      -H "Content-Type: application/json" `
      -d "{
        `"task_type`": `"batch_process`",
        `"payload`": {
          `"batch_id`": $_,
          `"data`": `"test data $_`"
        }
      }"
    Start-Sleep -Milliseconds 100
}
```

### 1.6 Monitor Message Processing

**Watch worker logs:**

```powershell
# Real-time worker processing logs
docker-compose logs -f worker-service

# Expected log output:
# worker-service-1  | [2024-01-15 10:30:00] INFO: Processing message 550e8400...
# worker-service-1  | [2024-01-15 10:30:00] INFO: Task type: process_data
# worker-service-1  | [2024-01-15 10:30:02] INFO: Message processed successfully
```

**Check queue in RabbitMQ UI:**

1. Go to [http://localhost:15672/#/queues](http://localhost:15672/#/queues)
2. Click on `task-queue`
3. View **Messages** and **Message rates** charts

### 1.7 Stop Services

```powershell
# Stop all services (containers remain)
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop, remove containers, and delete volumes
docker-compose down -v
```

## AKS Deployment

Now we'll deploy the message queue system to Azure Kubernetes Service.

### 2.1 Build and Push Docker Images

```powershell
# Set variables (use your values from Lab 1)
$RESOURCE_GROUP = "rg-hello-apis"
$ACR_NAME = "acrhelloapis<your-unique-suffix>"
$ACR_LOGIN_SERVER = "$ACR_NAME.azurecr.io"

# Login to ACR
az acr login --name $ACR_NAME

# Build images from project root
cd E:\Code\RustAksDemoLab

# Build Rust API (with message queue support)
docker build -t rust-api:latest ./src/rust-api
docker tag rust-api:latest "$ACR_LOGIN_SERVER/rust-api:latest"
docker push "$ACR_LOGIN_SERVER/rust-api:latest"

# Build Worker Service
docker build -t worker-service:latest ./src/worker-service
docker tag worker-service:latest "$ACR_LOGIN_SERVER/worker-service:latest"
docker push "$ACR_LOGIN_SERVER/worker-service:latest"

# Build RabbitMQ (if using custom image, otherwise use official)
# Note: For this lab, we'll use the official RabbitMQ image, no push needed

# Verify images in ACR
az acr repository list --name $ACR_NAME -o table
```

**Expected output:**

```text
Result
----------------
hello-rust-api      (from Lab 1)
hello-csharp-api    (from Lab 1)
rust-api            (new - with /send endpoint)
worker-service      (new)
```

### 2.2 Update Kubernetes Manifests

**Update image references in manifests:**

```powershell
# Update RabbitMQ deployment
(Get-Content src/k8s/rabbitmq-deployment.yaml) -replace '<your-acr-name>', $ACR_NAME | Set-Content src/k8s/rabbitmq-deployment.yaml

# Update Worker deployment
(Get-Content src/k8s/worker-deployment.yaml) -replace '<your-acr-name>', $ACR_NAME | Set-Content src/k8s/worker-deployment.yaml

# Update Rust API deployment (if not already updated)
(Get-Content src/k8s/rust-api-mq-deployment.yaml) -replace '<your-acr-name>', $ACR_NAME | Set-Content src/k8s/rust-api-mq-deployment.yaml
```

### 2.3 Create Kubernetes Secrets

Store RabbitMQ credentials securely:

```powershell
# Get AKS credentials (if not already configured)
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Create namespace (if not exists from Lab 1)
kubectl create namespace hello-apis --dry-run=client -o yaml | kubectl apply -f -

# Create secret for RabbitMQ credentials
kubectl create secret generic rabbitmq-credentials `
  --from-literal=username=admin `
  --from-literal=password=admin123 `
  -n hello-apis

# Verify secret
kubectl get secret rabbitmq-credentials -n hello-apis
```

### 2.4 Deploy RabbitMQ

```powershell
# Deploy RabbitMQ StatefulSet and Service
kubectl apply -f src/k8s/rabbitmq-deployment.yaml

# Wait for RabbitMQ to be ready
kubectl wait --for=condition=ready pod -l app=rabbitmq -n hello-apis --timeout=300s

# Check RabbitMQ status
kubectl get pods -l app=rabbitmq -n hello-apis
kubectl get svc rabbitmq -n hello-apis
```

**Verify RabbitMQ logs:**

```powershell
kubectl logs -l app=rabbitmq -n hello-apis --tail=50

# Expected log output should show:
# Server startup complete
# Management plugin started
```

### 2.5 Deploy Rust API with Message Queue Support

```powershell
# Deploy Rust API with /send endpoint
kubectl apply -f src/k8s/rust-api-mq-deployment.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=rust-api-mq -n hello-apis --timeout=300s

# Check API status
kubectl get pods -l app=rust-api-mq -n hello-apis
kubectl get svc rust-api-mq -n hello-apis
```

### 2.6 Deploy Worker Service

```powershell
# Deploy worker service (1 replica initially)
kubectl apply -f src/k8s/worker-deployment.yaml

# Wait for worker to be ready
kubectl wait --for=condition=ready pod -l app=worker-service -n hello-apis --timeout=300s

# Check worker status
kubectl get pods -l app=worker-service -n hello-apis
```

### 2.7 Deploy Horizontal Pod Autoscaler (HPA)

```powershell
# Deploy HPA for worker service
kubectl apply -f src/k8s/worker-hpa.yaml

# Verify HPA is created
kubectl get hpa -n hello-apis

# View HPA details
kubectl describe hpa worker-hpa -n hello-apis
```

**Expected HPA output:**

```text
NAME         REFERENCE                    TARGETS         MINPODS   MAXPODS   REPLICAS
worker-hpa   Deployment/worker-service    <unknown>/70%   1         10        1
```

> **Note**: `<unknown>` is normal initially. Metrics appear after pods generate CPU load.

### 2.8 Verify Complete Deployment

```powershell
# Check all pods in namespace
kubectl get pods -n hello-apis

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# rabbitmq-0                        1/1     Running   0          5m
# rust-api-mq-xxx                   1/1     Running   0          3m
# worker-service-xxx                1/1     Running   0          2m

# Check all services
kubectl get svc -n hello-apis

# Check HPA status
kubectl get hpa -n hello-apis
```

## Testing the System

### 3.1 Get API External IP

```powershell
# Wait for external IP to be assigned
kubectl get svc rust-api-mq -n hello-apis -w

# Get external IP
$API_IP = kubectl get svc rust-api-mq -n hello-apis -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "API URL: http://$API_IP"

# Test basic connectivity
curl http://$API_IP/health
```

### 3.2 Send Test Messages

**Single message:**

```powershell
# Send a test message
$response = Invoke-RestMethod -Uri "http://${API_IP}/send" -Method POST -ContentType "application/json" -Body '{
  "task_type": "test_task",
  "payload": {
    "message": "Hello from AKS!"
  }
}'

$response | ConvertTo-Json
```

**Bulk message sending:**

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

    Invoke-RestMethod -Uri "http://${API_IP}/send" -Method POST -ContentType "application/json" -Body $body
    
    if ($_ % 10 -eq 0) {
        Write-Host "Sent $_ messages..."
    }
}

Write-Host "Sent 100 messages. Workers should scale up shortly."
```

### 3.3 Monitor Message Processing

**Watch worker pods:**

```powershell
# Monitor worker pod scaling
kubectl get pods -l app=worker-service -n hello-apis -w
```

**View worker logs:**

```powershell
# Follow logs from all worker pods
kubectl logs -l app=worker-service -n hello-apis -f --max-log-requests=10

# View logs from specific pod
kubectl logs <worker-pod-name> -n hello-apis -f
```

**Check RabbitMQ queue status:**

```powershell
# Port-forward RabbitMQ management UI
kubectl port-forward svc/rabbitmq 15672:15672 -n hello-apis

# Open browser to http://localhost:15672
# Login: admin / admin123
# Navigate to Queues > task-queue
```

### 3.4 Monitor HPA Behavior

```powershell
# Watch HPA in real-time
kubectl get hpa worker-hpa -n hello-apis -w

# Expected output during load:
# NAME         REFERENCE                    TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
# worker-hpa   Deployment/worker-service    15%/70%    1         10        1          10m
# worker-hpa   Deployment/worker-service    85%/70%    1         10        1          11m
# worker-hpa   Deployment/worker-service    85%/70%    1         10        2          11m
# worker-hpa   Deployment/worker-service    75%/70%    1         10        3          12m
```

**View detailed HPA events:**

```powershell
kubectl describe hpa worker-hpa -n hello-apis

# Look for events like:
# Normal   SuccessfulRescale  2m   horizontal-pod-autoscaler  New size: 3; reason: cpu resource utilization (percentage of request) above target
```

## Horizontal Pod Autoscaler (HPA)

### Understanding HPA

The Horizontal Pod Autoscaler automatically scales the number of worker pods based on CPU utilization.

**HPA Configuration:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: worker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: worker-service
  minReplicas: 1              # Minimum number of pods
  maxReplicas: 10             # Maximum number of pods
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Target 70% CPU utilization
```

### How HPA Works

1. **Metrics Collection**: HPA queries metrics-server every 15 seconds (default)
2. **Calculation**: Compares current CPU usage vs target (70%)
3. **Decision**: Determines desired replica count
4. **Scaling**: Scales deployment up or down
5. **Cooldown**: Waits before scaling again (3-5 minutes)

**Formula:**

```text
desired_replicas = ceil(current_replicas * (current_metric / target_metric))

Example:
- Current: 2 replicas at 90% CPU
- Target: 70% CPU
- Desired: ceil(2 * (90 / 70)) = ceil(2.57) = 3 replicas
```

### Scaling Triggers

**Scale Up (CPU > 70%)**:
- High message volume in queue
- Workers processing messages continuously
- Each worker taking 2+ seconds per message
- Multiple messages queued per worker

**Scale Down (CPU < 70%)**:
- Queue empty or low message count
- Workers idle most of the time
- CPU usage drops below target
- Cooldown period (5 minutes) passes

### Observing HPA Behavior

```powershell
# Monitor HPA decisions
kubectl get hpa worker-hpa -n hello-apis -w

# View scaling events
kubectl get events -n hello-apis --sort-by='.lastTimestamp' | Select-String -Pattern "worker"

# Check current metrics
kubectl top pods -l app=worker-service -n hello-apis

# View HPA status details
kubectl describe hpa worker-hpa -n hello-apis
```

### HPA Best Practices

| Practice | Reason |
|----------|--------|
| Set appropriate min/max | Prevent over-provisioning and ensure availability |
| Choose right metric target | Too low = frequent scaling, too high = poor performance |
| Monitor cooldown periods | Understand why scaling isn't happening immediately |
| Use resource requests | HPA requires CPU/memory requests to calculate % |
| Test under load | Verify scaling behavior before production |

## PowerShell Test Scripts

The `scripts/` directory contains comprehensive test scripts for the message queue system.

### Send-TestMessages.ps1

Sends messages to the Rust API `/send` endpoint.

**Usage:**

```powershell
# Send 10 messages (default)
.\scripts\Send-TestMessages.ps1

# Send specific number of messages
.\scripts\Send-TestMessages.ps1 -Count 50

# Send to custom endpoint
.\scripts\Send-TestMessages.ps1 -ApiUrl "http://20.30.40.50" -Count 100

# Send with custom delay between messages
.\scripts\Send-TestMessages.ps1 -Count 20 -DelayMs 500
```

**Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ApiUrl` | Base URL of Rust API | `http://localhost:8080` |
| `-Count` | Number of messages to send | `10` |
| `-DelayMs` | Delay between messages (ms) | `100` |
| `-TaskType` | Message task type | `load_test` |

**Output:**

```text
Sending 50 messages to http://20.30.40.50/send...
Sent message 1/50: ID 550e8400-e29b-41d4-a716-446655440000
Sent message 2/50: ID 661f9511-f3ac-52e5-b827-557766551111
...
Successfully sent 50 messages in 12.34 seconds
Average: 4.05 messages/second
```

### Monitor-Queue.ps1

Monitors RabbitMQ queue status via Management API.

**Usage:**

```powershell
# Monitor with default settings
.\scripts\Monitor-Queue.ps1

# Monitor specific RabbitMQ instance
.\scripts\Monitor-Queue.ps1 -RabbitMqUrl "http://localhost:15672" -Username "admin" -Password "admin123"

# Monitor with custom refresh interval
.\scripts\Monitor-Queue.ps1 -RefreshSeconds 5

# Monitor specific queue
.\scripts\Monitor-Queue.ps1 -QueueName "my-custom-queue"
```

**Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-RabbitMqUrl` | RabbitMQ Management UI URL | `http://localhost:15672` |
| `-Username` | RabbitMQ username | `admin` |
| `-Password` | RabbitMQ password | `admin123` |
| `-QueueName` | Queue name to monitor | `task-queue` |
| `-RefreshSeconds` | Refresh interval | `3` |

**Output:**

```text
Monitoring RabbitMQ Queue: task-queue
Press Ctrl+C to stop...

[2024-01-15 10:30:00] Messages: 42 | Ready: 42 | Unacked: 3 | Rate: 5.2/s
[2024-01-15 10:30:03] Messages: 35 | Ready: 35 | Unacked: 2 | Rate: 4.8/s
[2024-01-15 10:30:06] Messages: 28 | Ready: 28 | Unacked: 4 | Rate: 5.1/s
```

### Watch-HPA.ps1

Monitors Horizontal Pod Autoscaler metrics and scaling events.

**Usage:**

```powershell
# Watch HPA with defaults
.\scripts\Watch-HPA.ps1

# Watch with custom namespace
.\scripts\Watch-HPA.ps1 -Namespace "hello-apis" -HpaName "worker-hpa"

# Watch with custom refresh rate
.\scripts\Watch-HPA.ps1 -RefreshSeconds 5
```

**Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Namespace` | Kubernetes namespace | `hello-apis` |
| `-HpaName` | HPA resource name | `worker-hpa` |
| `-RefreshSeconds` | Refresh interval | `3` |

**Output:**

```text
Monitoring HPA: worker-hpa in namespace: hello-apis
Press Ctrl+C to stop...

[2024-01-15 10:30:00] Replicas: 2/10 | CPU: 45% (target: 70%) | Status: Stable
[2024-01-15 10:30:03] Replicas: 3/10 | CPU: 82% (target: 70%) | Status: Scaling Up
[2024-01-15 10:30:06] Replicas: 4/10 | CPU: 75% (target: 70%) | Status: Scaling Up
[2024-01-15 10:30:09] Replicas: 5/10 | CPU: 65% (target: 70%) | Status: Stable
```

### Get-ProcessingResults.ps1

Retrieves processing statistics from worker logs.

**Usage:**

```powershell
# Get results from all workers
.\scripts\Get-ProcessingResults.ps1

# Get results for specific namespace
.\scripts\Get-ProcessingResults.ps1 -Namespace "hello-apis"

# Get results with more log lines
.\scripts\Get-ProcessingResults.ps1 -TailLines 200
```

**Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Namespace` | Kubernetes namespace | `hello-apis` |
| `-LabelSelector` | Pod label selector | `app=worker-service` |
| `-TailLines` | Number of log lines to analyze | `100` |

**Output:**

```text
Worker Processing Statistics
============================

Total workers: 4
Total messages processed: 267
Average processing time: 2.03 seconds
Success rate: 100%

Per-Worker Breakdown:
---------------------
worker-service-abc123: 78 messages (29.2%)
worker-service-def456: 71 messages (26.6%)
worker-service-ghi789: 64 messages (24.0%)
worker-service-jkl012: 54 messages (20.2%)
```

### Test-E2E.ps1

Comprehensive end-to-end test of the entire system.

**Usage:**

```powershell
# Run full E2E test
.\scripts\Test-E2E.ps1

# Run with custom parameters
.\scripts\Test-E2E.ps1 -ApiUrl "http://20.30.40.50" -MessageCount 50 -TimeoutSeconds 300
```

**Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ApiUrl` | Rust API URL | `http://localhost:8080` |
| `-MessageCount` | Number of test messages | `20` |
| `-TimeoutSeconds` | Max wait time for completion | `180` |
| `-Namespace` | Kubernetes namespace | `hello-apis` |

**Test Steps:**

1. ✅ Verify API is reachable
2. ✅ Check RabbitMQ is running
3. ✅ Verify worker pods are ready
4. ✅ Send test messages to queue
5. ✅ Monitor queue processing
6. ✅ Wait for queue to drain
7. ✅ Verify all messages processed
8. ✅ Check for errors in worker logs
9. ✅ Generate test report

**Output:**

```text
=== E2E Test Suite ===
Test started: 2024-01-15 10:30:00

[1/9] Checking API health...                     ✅ PASSED
[2/9] Verifying RabbitMQ connectivity...         ✅ PASSED
[3/9] Checking worker pods...                    ✅ PASSED (2 pods ready)
[4/9] Sending 20 test messages...                ✅ PASSED (20/20 sent)
[5/9] Monitoring queue processing...             ✅ PASSED
[6/9] Waiting for queue to drain...              ✅ PASSED (drained in 45s)
[7/9] Verifying message processing...            ✅ PASSED (20/20 processed)
[8/9] Checking for worker errors...              ✅ PASSED (0 errors)
[9/9] Generating test report...                  ✅ PASSED

=== Test Results ===
Status: SUCCESS
Duration: 52 seconds
Messages sent: 20
Messages processed: 20
Success rate: 100%
Average throughput: 2.3 messages/second
Worker pods: 2
Errors: 0
```

### Test-HPAScaling.ps1

Tests HPA auto-scaling behavior under load.

**Usage:**

```powershell
# Run HPA scaling test
.\scripts\Test-HPAScaling.ps1

# Run with custom load parameters
.\scripts\Test-HPAScaling.ps1 -ApiUrl "http://20.30.40.50" -LoadDuration 300 -TargetRPS 10
```

**Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ApiUrl` | Rust API URL | Auto-detect from kubectl |
| `-LoadDuration` | Load test duration (seconds) | `180` |
| `-TargetRPS` | Target requests per second | `5` |
| `-Namespace` | Kubernetes namespace | `hello-apis` |

**Test Phases:**

1. **Baseline**: Measure initial state (1 worker, low CPU)
2. **Load Generation**: Send messages continuously for duration
3. **Scale Up**: Monitor HPA scaling up workers
4. **Sustained Load**: Maintain load and observe stability
5. **Cool Down**: Stop load and observe scale down
6. **Analysis**: Generate scaling behavior report

**Output:**

```text
=== HPA Scaling Test ===
Test Configuration:
- Load Duration: 180 seconds
- Target RPS: 5 requests/second
- Expected Scale: 1 → 5-7 workers

Phase 1: Baseline Metrics
-------------------------
Initial workers: 1
Initial CPU: 12%
Initial queue depth: 0

Phase 2: Load Generation (0-180s)
----------------------------------
[00:15] Sent: 75 msgs  | Workers: 1 | CPU: 45% | Queue: 12
[00:30] Sent: 150 msgs | Workers: 2 | CPU: 78% | Queue: 28
[00:45] Sent: 225 msgs | Workers: 3 | CPU: 82% | Queue: 45
[01:00] Sent: 300 msgs | Workers: 4 | CPU: 71% | Queue: 38
[01:30] Sent: 450 msgs | Workers: 5 | CPU: 68% | Queue: 25
[02:00] Sent: 600 msgs | Workers: 6 | CPU: 65% | Queue: 18
[03:00] Sent: 900 msgs | Workers: 6 | CPU: 67% | Queue: 8

Phase 3: Cool Down (180-360s)
------------------------------
[03:30] Workers: 6 | CPU: 42% | Queue: 0
[04:00] Workers: 5 | CPU: 38% | Queue: 0
[05:00] Workers: 3 | CPU: 15% | Queue: 0
[06:00] Workers: 1 | CPU: 8%  | Queue: 0

=== Scaling Analysis ===
✅ HPA functioning correctly
- Max workers reached: 6 (within expected range)
- Scale-up latency: ~45 seconds (good)
- Scale-down latency: ~180 seconds (expected)
- CPU target maintained: Yes (65-75% avg)
- Messages processed: 900/900 (100%)
```

## Troubleshooting

### Common Issues and Solutions

#### RabbitMQ Connection Failures

**Symptoms:**
- Rust API logs: `Failed to connect to RabbitMQ`
- Worker logs: `Connection refused on port 5672`

**Solutions:**

```powershell
# Check RabbitMQ pod status
kubectl get pods -l app=rabbitmq -n hello-apis
kubectl describe pod -l app=rabbitmq -n hello-apis

# Check RabbitMQ logs
kubectl logs -l app=rabbitmq -n hello-apis --tail=100

# Verify RabbitMQ service
kubectl get svc rabbitmq -n hello-apis
kubectl describe svc rabbitmq -n hello-apis

# Test connection from API pod
kubectl exec -it <rust-api-pod> -n hello-apis -- /bin/sh
# (inside pod) curl http://rabbitmq:15672

# Restart RabbitMQ if needed
kubectl rollout restart statefulset rabbitmq -n hello-apis
```

#### Workers Not Processing Messages

**Symptoms:**
- Messages queued but not consumed
- Worker logs show no activity
- Queue depth increasing

**Solutions:**

```powershell
# Check worker pod status
kubectl get pods -l app=worker-service -n hello-apis

# View worker logs for errors
kubectl logs -l app=worker-service -n hello-apis --tail=50

# Verify worker environment variables
kubectl describe pod -l app=worker-service -n hello-apis | Select-String -Pattern "Environment"

# Check RabbitMQ credentials secret
kubectl get secret rabbitmq-credentials -n hello-apis -o yaml

# Restart workers
kubectl rollout restart deployment worker-service -n hello-apis

# Scale workers manually if needed
kubectl scale deployment worker-service --replicas=3 -n hello-apis
```

#### HPA Not Scaling

**Symptoms:**
- HPA shows `<unknown>` for CPU metrics
- Worker count remains at 1 despite high load
- `kubectl describe hpa` shows metric errors

**Solutions:**

```powershell
# Check if metrics-server is installed
kubectl get deployment metrics-server -n kube-system

# Install metrics-server if missing (for AKS, usually pre-installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics are available
kubectl top nodes
kubectl top pods -n hello-apis

# Check HPA status
kubectl describe hpa worker-hpa -n hello-apis

# Verify worker deployment has resource requests
kubectl get deployment worker-service -n hello-apis -o yaml | Select-String -Pattern "resources:" -Context 5

# Check HPA events
kubectl get events -n hello-apis | Select-String -Pattern "HorizontalPodAutoscaler"

# Manually trigger scaling to test (then let HPA take over)
kubectl scale deployment worker-service --replicas=3 -n hello-apis
```

**Common HPA issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| `<unknown>` metrics | metrics-server not running | Install/restart metrics-server |
| Not scaling up | No resource requests set | Add CPU/memory requests to deployment |
| Scaling too slowly | Default cooldown period | Adjust HPA behavior annotations |
| Flapping | Target too close to baseline | Increase target utilization |

#### Messages Stuck in Queue

**Symptoms:**
- Queue depth not decreasing
- Workers running but messages remain
- RabbitMQ shows messages as "ready" but not delivered

**Solutions:**

```powershell
# Check queue status via RabbitMQ API
kubectl port-forward svc/rabbitmq 15672:15672 -n hello-apis
# Browse to http://localhost:15672, login, check Queues

# Check for message acknowledgment issues
kubectl logs -l app=worker-service -n hello-apis | Select-String -Pattern "ack\|nack\|reject"

# Check for worker crashes during processing
kubectl get pods -l app=worker-service -n hello-apis
kubectl describe pods -l app=worker-service -n hello-apis | Select-String -Pattern "Restart"

# Purge queue if needed (CAUTION: Deletes all messages)
kubectl exec -it rabbitmq-0 -n hello-apis -- rabbitmqctl purge_queue task-queue

# Check consumer count on queue
kubectl exec -it rabbitmq-0 -n hello-apis -- rabbitmqctl list_queues name consumers messages
```

#### API /send Endpoint Returns 500 Error

**Symptoms:**
- POST requests to `/send` fail with 500 status
- API logs show RabbitMQ publish errors

**Solutions:**

```powershell
# Check API logs
kubectl logs -l app=rust-api-mq -n hello-apis --tail=100

# Verify API can reach RabbitMQ
kubectl exec -it <rust-api-pod> -n hello-apis -- /bin/sh
# (inside pod) nc -zv rabbitmq 5672

# Check environment variables
kubectl describe pod -l app=rust-api-mq -n hello-apis | Select-String -Pattern "RABBITMQ"

# Test RabbitMQ credentials
kubectl exec -it rabbitmq-0 -n hello-apis -- rabbitmqctl authenticate_user admin admin123

# Restart API pods
kubectl rollout restart deployment rust-api-mq -n hello-apis
```

#### High CPU but No Scaling

**Symptoms:**
- Worker pods at 90%+ CPU
- HPA shows high CPU but doesn't scale
- Pod count remains at minimum

**Solutions:**

```powershell
# Check current HPA status
kubectl get hpa worker-hpa -n hello-apis
kubectl describe hpa worker-hpa -n hello-apis

# Verify deployment isn't at max replicas
kubectl get deployment worker-service -n hello-apis

# Check for HPA events/errors
kubectl get events -n hello-apis --sort-by='.lastTimestamp' | Select-String -Pattern "worker-hpa"

# Verify resource requests vs limits
kubectl describe deployment worker-service -n hello-apis | Select-String -Pattern "Limits\|Requests" -Context 2

# Check if deployment has update strategy blocking
kubectl get deployment worker-service -n hello-apis -o yaml | Select-String -Pattern "strategy"

# Temporarily increase max replicas for testing
kubectl patch hpa worker-hpa -n hello-apis -p '{"spec":{"maxReplicas":15}}'
```

### Debugging Commands Reference

| Scenario | Command |
|----------|---------|
| Check all resources | `kubectl get all -n hello-apis` |
| View recent events | `kubectl get events -n hello-apis --sort-by='.lastTimestamp' \| Select-Object -Last 20` |
| Check pod resource usage | `kubectl top pods -n hello-apis` |
| View full pod YAML | `kubectl get pod <pod-name> -n hello-apis -o yaml` |
| Get pod shell access | `kubectl exec -it <pod-name> -n hello-apis -- /bin/sh` |
| Check network connectivity | `kubectl exec -it <pod-name> -n hello-apis -- nc -zv rabbitmq 5672` |
| View service endpoints | `kubectl get endpoints -n hello-apis` |
| Check secret contents | `kubectl get secret rabbitmq-credentials -n hello-apis -o jsonpath='{.data}' \| ConvertFrom-Json` |
| Force pod restart | `kubectl delete pod <pod-name> -n hello-apis` |
| Scale deployment | `kubectl scale deployment <name> --replicas=<count> -n hello-apis` |

### Docker Compose Troubleshooting

#### Port Already in Use

```powershell
# Find process using port 8080
Get-NetTCPConnection -LocalPort 8080 -State Listen | ForEach-Object { Get-Process -Id $_.OwningProcess }

# Stop conflicting container
docker-compose down

# Or use different ports in docker-compose.yml
# Change: "8080:8080" to "8081:8080"
```

#### Container Exits Immediately

```powershell
# View container logs
docker-compose logs rust-api
docker-compose logs worker-service

# Check container status
docker-compose ps

# Rebuild images
docker-compose up --build --force-recreate

# Run container interactively for debugging
docker-compose run --rm rust-api /bin/sh
```

## Cleanup

### Clean Up Docker Compose Resources

```powershell
# Stop and remove all containers
docker-compose down

# Remove containers and volumes
docker-compose down -v

# Remove containers, volumes, and images
docker-compose down -v --rmi all

# Remove orphaned containers
docker-compose down --remove-orphans
```

### Clean Up AKS Resources (Keep Cluster)

```powershell
# Delete Lab 2 resources only
kubectl delete -f src/k8s/worker-hpa.yaml
kubectl delete -f src/k8s/worker-deployment.yaml
kubectl delete -f src/k8s/rust-api-mq-deployment.yaml
kubectl delete -f src/k8s/rabbitmq-deployment.yaml

# Delete secrets
kubectl delete secret rabbitmq-credentials -n hello-apis

# Verify cleanup
kubectl get all -n hello-apis
```

### Clean Up All AKS Resources (Complete)

```powershell
# Delete entire namespace (removes everything from Lab 1 and Lab 2)
kubectl delete namespace hello-apis

# Verify namespace deletion
kubectl get namespace hello-apis
```

### Clean Up Azure Infrastructure (Nuclear Option)

⚠️ **WARNING**: This deletes ALL resources from Lab 1 and Lab 2.

```powershell
# Set variables
$RESOURCE_GROUP = "rg-hello-apis"

# Delete resource group (AKS, ACR, everything)
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Monitor deletion status
az group list --query "[?name=='$RESOURCE_GROUP']" -o table

# Remove kubectl context
kubectl config delete-context $CLUSTER_NAME
kubectl config delete-cluster $CLUSTER_NAME
```

### Clean Up Docker Images Locally

```powershell
# Remove Lab 2 images
docker rmi rust-api:latest
docker rmi worker-service:latest
docker rmi rabbitmq:3-management

# Remove all unused images
docker image prune -a

# Remove all build cache
docker builder prune -a
```

## Quick Reference

### Environment Variables Summary

**Rust API:**
```powershell
$env:RABBITMQ_HOST="rabbitmq"
$env:RABBITMQ_PORT="5672"
$env:RABBITMQ_USER="admin"
$env:RABBITMQ_PASS="admin123"
$env:RABBITMQ_QUEUE="task-queue"
```

**Worker Service:**
```powershell
$env:RabbitMQ__Host="rabbitmq"
$env:RabbitMQ__Port="5672"
$env:RabbitMQ__Username="admin"
$env:RabbitMQ__Password="admin123"
$env:RabbitMQ__QueueName="task-queue"
```

### Common Commands

| Action | Command |
|--------|---------|
| Start Docker Compose | `docker-compose up -d --build` |
| View logs | `docker-compose logs -f` |
| Stop services | `docker-compose down` |
| Send message | `curl -X POST http://localhost:8080/send -H "Content-Type: application/json" -d '{...}'` |
| Port-forward RabbitMQ UI | `kubectl port-forward svc/rabbitmq 15672:15672 -n hello-apis` |
| Watch HPA | `kubectl get hpa worker-hpa -n hello-apis -w` |
| Scale workers | `kubectl scale deployment worker-service --replicas=5 -n hello-apis` |
| View worker logs | `kubectl logs -l app=worker-service -n hello-apis -f` |
| Check queue status | Browse to `http://localhost:15672` (admin/admin123) |
| Send bulk messages | `.\scripts\Send-TestMessages.ps1 -Count 100` |
| Run E2E test | `.\scripts\Test-E2E.ps1` |
| Test HPA scaling | `.\scripts\Test-HPAScaling.ps1` |

### Key Endpoints

| Endpoint | Method | Purpose | Example |
|----------|--------|---------|---------|
| `/` | GET | Hello World | `curl http://localhost:8080/` |
| `/health` | GET | Health check | `curl http://localhost:8080/health` |
| `/info` | GET | API information | `curl http://localhost:8080/info` |
| `/send` | POST | Queue message | `curl -X POST http://localhost:8080/send -H "Content-Type: application/json" -d '{...}'` |

### RabbitMQ Management UI URLs

| Environment | URL | Credentials |
|-------------|-----|-------------|
| Local (Docker Compose) | http://localhost:15672 | admin / admin123 |
| AKS (Port-Forward) | http://localhost:15672 | admin / admin123 |

**Useful RabbitMQ UI Sections:**
- **Overview**: System health, message rates
- **Queues**: View `task-queue` details, purge messages
- **Connections**: Active connections from API/workers
- **Channels**: Communication channels per connection

### Message Payload Examples

**Simple task:**
```json
{
  "task_type": "process_data",
  "payload": {
    "value": "test"
  }
}
```

**Batch processing:**
```json
{
  "task_type": "batch_process",
  "payload": {
    "batch_id": 42,
    "items": ["item1", "item2", "item3"]
  }
}
```

**Complex task:**
```json
{
  "task_type": "data_transformation",
  "payload": {
    "source": "database",
    "transformation": "aggregate",
    "filters": {
      "date_range": "2024-01",
      "category": "sales"
    }
  }
}
```

### kubectl Cheat Sheet

```powershell
# View everything in namespace
kubectl get all -n hello-apis

# Watch pods
kubectl get pods -n hello-apis -w

# View logs (all worker pods)
kubectl logs -l app=worker-service -n hello-apis --tail=50

# Follow logs in real-time
kubectl logs -l app=worker-service -n hello-apis -f

# Get shell in pod
kubectl exec -it <pod-name> -n hello-apis -- /bin/sh

# Check resource usage
kubectl top pods -n hello-apis

# View HPA status
kubectl get hpa -n hello-apis

# Describe HPA (events and details)
kubectl describe hpa worker-hpa -n hello-apis

# Port-forward service
kubectl port-forward svc/rabbitmq 15672:15672 -n hello-apis

# Scale deployment manually
kubectl scale deployment worker-service --replicas=3 -n hello-apis

# Restart deployment
kubectl rollout restart deployment worker-service -n hello-apis

# View deployment history
kubectl rollout history deployment worker-service -n hello-apis

# Update image
kubectl set image deployment/worker-service worker-service=$ACR_LOGIN_SERVER/worker-service:v2 -n hello-apis
```

### Expected System Performance

| Metric | Value |
|--------|-------|
| Message processing time | ~2 seconds per message |
| Worker throughput | 0.5 messages/second per worker |
| HPA scale-up time | 30-60 seconds |
| HPA scale-down time | 3-5 minutes |
| Max concurrent workers | 10 (configurable) |
| RabbitMQ throughput | 1000+ messages/second |

### Next Steps

After completing this lab, you have learned:

✅ Message queue patterns with RabbitMQ  
✅ Asynchronous task processing with worker services  
✅ Horizontal Pod Autoscaling in Kubernetes  
✅ Load testing and performance monitoring  
✅ Multi-container orchestration with Docker Compose  
✅ AKS deployment of distributed systems  

**Further Learning:**
- Implement dead-letter queues for failed messages
- Add message priority and routing
- Implement request-response patterns with RabbitMQ
- Use KEDA for queue-length-based scaling
- Add distributed tracing with OpenTelemetry
- Implement circuit breakers and retry policies
- Deploy to production with Helm charts

**Resources:**
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [KEDA (Kubernetes Event-driven Autoscaling)](https://keda.sh/)
- [Actix-web Documentation](https://actix.rs/)
- [.NET Background Services](https://docs.microsoft.com/en-us/dotnet/core/extensions/hosted-services)
