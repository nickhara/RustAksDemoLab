# Horizontal Pod Autoscaler (HPA) - Technical Reference

## Table of Contents

1. [What is HPA and How It Works](#what-is-hpa-and-how-it-works)
2. [HPA API Versions and Feature Comparison](#hpa-api-versions-and-feature-comparison)
3. [HPA YAML Configuration Deep Dive](#hpa-yaml-configuration-deep-dive)
4. [Metrics Types](#metrics-types)
5. [Scaling Behaviors](#scaling-behaviors)
6. [HPA Formula and Calculations](#hpa-formula-and-calculations)
7. [Best Practices](#best-practices)
8. [Common Pitfalls](#common-pitfalls)
9. [Monitoring and Debugging](#monitoring-and-debugging)
10. [KEDA for Advanced Scaling](#keda-for-advanced-scaling)
11. [Performance Tuning](#performance-tuning)

---

## What is HPA and How It Works

### Overview

Horizontal Pod Autoscaler (HPA) automatically scales the number of pods in a deployment, replica set, or stateful set based on observed metrics like CPU utilization, memory usage, or custom application metrics.

### Architecture

```text
┌─────────────────────────────────────────────────────┐
│                  HPA Controller                      │
│  (runs every 15 seconds by default)                 │
└──────────┬──────────────────────────────────────────┘
           │
           ├──> Queries Metrics Server/Custom Metrics API
           │    • CPU/Memory from metrics-server
           │    • Custom metrics from adapters
           │    • External metrics from providers
           │
           ├──> Calculates desired replica count
           │    • Uses target metrics and current values
           │    • Applies scaling policies and behaviors
           │
           └──> Updates Deployment/ReplicaSet scale
                • Respects min/max replica limits
                • Follows scale-up/down policies
```

### Control Loop

1. **Metric Collection** (every 15s): HPA controller queries the Metrics API
2. **Calculation**: Computes desired replicas based on current vs target metrics
3. **Decision**: Applies scaling behaviors and stabilization windows
4. **Action**: Updates the target resource's replica count
5. **Wait**: Kubernetes scheduler provisions/terminates pods

### Prerequisites

- **Metrics Server**: Must be installed for resource metrics (CPU/memory)
- **Resource Requests**: Pods must have CPU/memory requests defined
- **RBAC**: HPA controller needs permissions to read metrics and scale deployments

---

## HPA API Versions and Feature Comparison

### Version Timeline

| Version | Kubernetes | Status | Key Features |
|---------|------------|--------|--------------|
| `autoscaling/v1` | 1.1+ | Stable | CPU-only scaling |
| `autoscaling/v2beta1` | 1.8-1.11 | Deprecated | Multiple metrics, custom metrics |
| `autoscaling/v2beta2` | 1.12-1.22 | Deprecated | Behavior configuration |
| `autoscaling/v2` | 1.23+ | Stable | All features, production-ready |

### Feature Matrix

| Feature | v1 | v2 |
|---------|----|----|
| CPU Utilization | ✅ | ✅ |
| Memory Utilization | ❌ | ✅ |
| Custom Metrics | ❌ | ✅ |
| External Metrics | ❌ | ✅ |
| Multiple Metrics | ❌ | ✅ |
| Scale-up Policies | ❌ | ✅ |
| Scale-down Policies | ❌ | ✅ |
| Stabilization Windows | ❌ | ✅ |

**Recommendation**: Always use `autoscaling/v2` for new deployments (Kubernetes 1.23+).

---

## HPA YAML Configuration Deep Dive

### Complete Annotated Example

Here's the actual HPA configuration from our worker service with detailed annotations:

```yaml
apiVersion: autoscaling/v2  # Use v2 for full feature set (K8s 1.23+)
kind: HorizontalPodAutoscaler
metadata:
  name: worker-service-hpa  # Unique name for this HPA
  namespace: hello-apis     # Must match target deployment namespace
spec:
  # ═══════════════════════════════════════════════════════════
  # Scale Target Reference
  # ═══════════════════════════════════════════════════════════
  scaleTargetRef:
    apiVersion: apps/v1      # API version of target resource
    kind: Deployment         # Can be: Deployment, ReplicaSet, StatefulSet
    name: worker-service     # Name of the deployment to scale
  
  # ═══════════════════════════════════════════════════════════
  # Replica Boundaries
  # ═══════════════════════════════════════════════════════════
  minReplicas: 1             # Minimum pods to maintain (cost floor)
                              # Cannot scale below this even if metrics are low
  
  maxReplicas: 10            # Maximum pods to provision (cost ceiling)
                              # Prevents runaway scaling during load spikes
  
  # ═══════════════════════════════════════════════════════════
  # Metrics Configuration
  # ═══════════════════════════════════════════════════════════
  metrics:
  - type: Resource           # Metric type: Resource (CPU/memory from metrics-server)
    resource:
      name: cpu              # Resource name: 'cpu' or 'memory'
      target:
        type: Utilization    # Target type: 'Utilization' (%) or 'AverageValue' (absolute)
        averageUtilization: 70  # Target 70% average CPU across all pods
                                # Formula: (current CPU usage / CPU request) * 100
                                # If pods average >70% CPU, scale up
                                # If pods average <70% CPU, scale down
  
  # ═══════════════════════════════════════════════════════════
  # Scaling Behavior Configuration
  # ═══════════════════════════════════════════════════════════
  behavior:
    # ───────────────────────────────────────────────────────────
    # Scale-Up Behavior (Adding Pods)
    # ───────────────────────────────────────────────────────────
    scaleUp:
      stabilizationWindowSeconds: 0  # No stabilization for scale-up
                                      # 0 = react immediately to load spikes
                                      # Default: 0 (aggressive scale-up)
      policies:
      # Policy 1: Percentage-based scaling
      - type: Percent              # Scale by percentage of current pods
        value: 100                 # Double the pod count (100% increase)
        periodSeconds: 15          # Can apply this policy every 15 seconds
                                   # Example: 2 pods → 4 pods → 8 pods
      
      # Policy 2: Fixed-count scaling
      - type: Pods                 # Scale by fixed number of pods
        value: 2                   # Add 2 pods at a time
        periodSeconds: 15          # Can apply this policy every 15 seconds
                                   # Example: 2 pods → 4 pods → 6 pods
      
      selectPolicy: Max            # Use the policy that scales MOST aggressively
                                   # Options: Max, Min, Disabled
                                   # Max = take the largest increase from any policy
                                   # This ensures fast response to load spikes

    # ───────────────────────────────────────────────────────────
    # Scale-Down Behavior (Removing Pods)
    # ───────────────────────────────────────────────────────────
    scaleDown:
      stabilizationWindowSeconds: 300  # 5-minute stabilization window
                                        # HPA looks at metrics over last 5 minutes
                                        # Only scales down if ALL readings support it
                                        # Prevents thrashing during fluctuating load
      policies:
      - type: Percent                  # Scale by percentage
        value: 50                      # Remove 50% of pods at most
        periodSeconds: 60              # Can apply every 60 seconds
                                       # Example: 8 pods → 4 pods → 2 pods
      
      selectPolicy: Min                # Use the policy that scales LEAST aggressively
                                       # Min = conservative scale-down
                                       # Prevents premature pod termination
```

### Field Reference

#### Metadata Section

```yaml
metadata:
  name: <hpa-name>           # Required: Unique identifier
  namespace: <namespace>     # Required: Must match target
  labels:                    # Optional: For organization
    app: myapp
  annotations:               # Optional: Additional metadata
    description: "Scales based on CPU"
```

#### Scale Target Reference

```yaml
scaleTargetRef:
  apiVersion: apps/v1        # Target resource API version
  kind: Deployment           # Deployment | ReplicaSet | StatefulSet
  name: my-deployment        # Must exist in same namespace
```

#### Replica Limits

```yaml
minReplicas: 1               # Default: 1 if omitted
maxReplicas: 10              # Required: No default
```

---

## Metrics Types

HPA supports four metric types for scaling decisions:

### 1. Resource Metrics (CPU/Memory)

#### CPU Utilization

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization            # Percentage of requested CPU
      averageUtilization: 70       # Target: 70% average across pods
```

**How it works:**

- Requires CPU requests defined in pod spec
- Formula: `(actual CPU usage / CPU request) × 100`
- Example: Request 100m, using 70m = 70% utilization

#### CPU Average Value

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: AverageValue           # Absolute value per pod
      averageValue: 500m           # Target: 500 millicores per pod
```

**Use case:** When you want consistent CPU allocation regardless of requests.

#### Memory Utilization

```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80       # Target: 80% of memory request
```

**Warning:** Memory-based scaling is tricky because memory isn't easily freed in many applications.

#### Memory Average Value

```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: AverageValue
      averageValue: 1Gi            # Target: 1GB per pod
```

### 2. Pods Metrics (Custom Application Metrics)

```yaml
metrics:
- type: Pods
  pods:
    metric:
      name: http_requests_per_second    # Custom metric from your app
    target:
      type: AverageValue
      averageValue: "1000"               # Target: 1000 RPS per pod
```

**Requirements:**

- Custom metrics adapter (e.g., Prometheus Adapter, Datadog, Stackdriver)
- Metrics must be exposed per-pod
- Adapter translates metrics to Kubernetes custom metrics API

**Common use cases:**

- HTTP requests per second
- Queue message processing rate
- Active connections per pod
- Application-specific throughput

### 3. Object Metrics (Kubernetes Objects)

```yaml
metrics:
- type: Object
  object:
    metric:
      name: requests_per_second
    describedObject:
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      name: my-ingress                   # Scale based on Ingress traffic
    target:
      type: Value
      value: "10k"                       # Target: 10,000 RPS total
```

**Use cases:**

- Scale based on Ingress traffic
- Scale based on Service load
- Scale based on other cluster resources

**Difference from Pods metrics:**

- Object metrics are aggregate (total), not per-pod
- Target is absolute value, not average per pod

### 4. External Metrics (Outside Kubernetes)

```yaml
metrics:
- type: External
  external:
    metric:
      name: queue_messages_ready         # SQS, RabbitMQ, etc.
      selector:
        matchLabels:
          queue: "orders"
    target:
      type: AverageValue
      averageValue: "30"                 # Target: 30 messages per pod
```

**Requirements:**

- External metrics adapter (e.g., KEDA, Datadog, Azure Monitor Adapter)
- Connection to external data source

**Common use cases:**

- Cloud message queues (SQS, Azure Queue, Pub/Sub)
- Database connection pools
- External API rate limits
- CDN hit rates

### Multiple Metrics

You can combine multiple metrics; HPA scales to satisfy **all** of them:

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
- type: Pods
  pods:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "1000"
```

**Logic:** HPA calculates desired replicas for each metric, then uses the **maximum** value.

- CPU suggests 5 replicas
- Memory suggests 7 replicas
- HTTP requests suggest 4 replicas
- **Result:** Scale to 7 replicas (max of all)

---

## Scaling Behaviors

Scaling behaviors control **how** and **when** scaling occurs, not just the target metrics.

### Scale-Up Configuration

#### Stabilization Window

```yaml
scaleUp:
  stabilizationWindowSeconds: 0    # Default: 0 (no delay)
```

- `0`: React immediately to spikes (recommended for most workloads)
- `60`: Wait 60s and only scale if metrics stay high (conservative)
- Use case for non-zero: Avoid scaling for brief spikes

#### Policies

**Percentage-based:**

```yaml
policies:
- type: Percent
  value: 50              # Increase by 50% of current replicas
  periodSeconds: 60      # Can happen every 60 seconds
```

**Pod-count-based:**

```yaml
policies:
- type: Pods
  value: 4               # Add 4 pods at a time
  periodSeconds: 60      # Can happen every 60 seconds
```

**Multiple policies example:**

```yaml
scaleUp:
  stabilizationWindowSeconds: 0
  policies:
  - type: Percent
    value: 100           # Double replicas
    periodSeconds: 15
  - type: Pods
    value: 4             # Or add 4 pods
    periodSeconds: 15
  selectPolicy: Max      # Choose whichever scales faster
```

**Scenarios:**

- 2 replicas: Max(100% = 4 total, +4 pods = 6 total) = **6 replicas**
- 10 replicas: Max(100% = 20 total, +4 pods = 14 total) = **20 replicas**

#### Select Policy Options

```yaml
selectPolicy: Max       # Most aggressive (default for scale-up)
selectPolicy: Min       # Most conservative
selectPolicy: Disabled  # Disable scale-up entirely
```

### Scale-Down Configuration

#### Stabilization Window

```yaml
scaleDown:
  stabilizationWindowSeconds: 300    # Default: 300 (5 minutes)
```

- **Critical for stability:** Prevents thrashing during fluctuating load
- HPA looks at highest metric value in the window
- Only scales down if metrics stayed low for entire window
- Typical values: 60-600 seconds

**Example:**

```text
Time    CPU%    Action
0:00    80%     Scale up to 4 pods
0:15    60%     No action (stabilization window)
1:00    50%     No action (within 5min window)
5:01    50%     Now can scale down (window passed)
```

#### Policies

Conservative scale-down:

```yaml
scaleDown:
  stabilizationWindowSeconds: 300
  policies:
  - type: Percent
    value: 50            # Remove at most 50% of pods
    periodSeconds: 60    # Every minute
  selectPolicy: Min      # Conservative approach
```

Aggressive scale-down (cost optimization):

```yaml
scaleDown:
  stabilizationWindowSeconds: 60   # Shorter window
  policies:
  - type: Percent
    value: 100           # Can remove all pods above min
    periodSeconds: 15    # Fast scale-down
  selectPolicy: Max      # Aggressive
```

### Complete Behavior Example

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
    - type: Pods
      value: 4
      periodSeconds: 15
    selectPolicy: Max
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
    - type: Percent
      value: 50
      periodSeconds: 60
    - type: Pods
      value: 2
      periodSeconds: 60
    selectPolicy: Min
```

**Behavior:**

- **Scale-up:** Aggressive (double or +4 pods every 15s)
- **Scale-down:** Conservative (max 50% or 2 pods per minute, wait 5 min)
- **Result:** Quick response to load, slow stabilization

---

## HPA Formula and Calculations

### Basic Formula

```text
desiredReplicas = ceil[currentReplicas × (currentMetricValue / targetMetricValue)]
```

### CPU Utilization Example

**Setup:**

- Current replicas: 3
- CPU request per pod: 100m
- Target CPU utilization: 70%
- Current CPU usage: 210m total (70m per pod)

**Calculation:**

```text
Current utilization = (70m / 100m) × 100 = 70%
Desired replicas = ceil[3 × (70% / 70%)] = ceil[3 × 1.0] = 3
Action: No scaling (at target)
```

**Load increases to 240m total (80m per pod):**

```text
Current utilization = (80m / 100m) × 100 = 80%
Desired replicas = ceil[3 × (80% / 70%)] = ceil[3 × 1.14] = ceil[3.42] = 4
Action: Scale up to 4 pods
```

**After scaling, load stays same (240m now spread over 4 pods):**

```text
Current utilization = (60m / 100m) × 100 = 60%
Desired replicas = ceil[4 × (60% / 70%)] = ceil[4 × 0.86] = ceil[3.44] = 4
Action: Stay at 4 pods (within tolerance)
```

### Tolerance and Threshold

HPA won't scale if the desired change is small:

```text
if |1.0 - (currentMetricValue / targetMetricValue)| < tolerance:
    no scaling
```

Default tolerance: **0.1 (10%)**

**Example with tolerance:**

```text
Current replicas: 4
Current metric: 75%
Target metric: 70%
Ratio: 75/70 = 1.07
Difference from 1.0: |1.0 - 1.07| = 0.07 < 0.1
Action: No scaling (within tolerance)
```

### Multiple Metrics Calculation

When multiple metrics are configured:

```text
For each metric:
    calculate desired_replicas_i

final_desired_replicas = max(desired_replicas_1, desired_replicas_2, ..., desired_replicas_n)
```

**Example:**

```yaml
metrics:
- CPU target: 70%
- Memory target: 80%
- Custom metric target: 1000 RPS
```

```text
Current state:
- 3 replicas
- CPU: 60% → desired = ceil[3 × (60/70)] = 3
- Memory: 90% → desired = ceil[3 × (90/80)] = ceil[3.375] = 4
- RPS: 3600 total = 1200/pod → desired = ceil[3 × (1200/1000)] = 4

Final desired replicas = max(3, 4, 4) = 4
```

### Absent/Unavailable Metrics

If a metric is unavailable:

- **Scale-up:** Metric is skipped (ignored)
- **Scale-down:** Assumes metric is at target (prevents scale-down)

This prevents scaling down due to monitoring failures.

### Ready Pods Calculation

HPA only considers **Ready** pods:

```text
currentMetricValue = sum(metric for ready pods) / count(ready pods)
```

**Example:**

- 4 pods total
- 3 ready, 1 not ready
- Metric sum: 180
- Average = 180 / 3 = 60 (ignores the not-ready pod)

### Pending Pods Factor

When pods are pending (being created):

```text
If scaling up and pods are pending:
    HPA waits for pods to become Ready before next scale decision
```

This prevents "runaway scaling" where HPA keeps adding pods before previous ones start.

---

## Best Practices

### 1. Always Define Resource Requests

**Bad:**

```yaml
containers:
- name: app
  image: myapp:latest
  # No resources defined - HPA can't calculate utilization!
```

**Good:**

```yaml
containers:
- name: app
  image: myapp:latest
  resources:
    requests:
      cpu: 100m        # Required for CPU-based HPA
      memory: 128Mi    # Required for memory-based HPA
    limits:
      cpu: 200m
      memory: 256Mi
```

### 2. Set Appropriate Min/Max Replicas

```yaml
minReplicas: 2    # At least 2 for high availability
maxReplicas: 50   # Prevent cost overruns, should handle peak × 1.5
```

**Considerations:**

- **minReplicas:** Ensure baseline availability and performance
- **maxReplicas:** Consider infrastructure limits, cost budgets, downstream capacity
- Monitor actual usage and adjust over time

### 3. Use Conservative Scale-Down

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300    # 5 minutes
    policies:
    - type: Percent
      value: 50              # Remove max 50% at a time
      periodSeconds: 60      # Every minute
```

**Why:**

- Users experience scale-up lag gracefully (slight slowdown)
- Users experience scale-down errors badly (connection failures)
- Conservative scale-down = better user experience

### 4. Combine Multiple Metrics Wisely

**Good combination:**

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
- type: Pods
  pods:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "500"
```

**Why:** CPU catches compute-bound load, RPS catches I/O-bound load.

**Avoid:**

```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      averageUtilization: 80    # Memory is hard to release
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 70    # CPU fluctuates more
```

**Why:** Memory-based scaling often leads to constant scale-up (memory leaks, caches not released).

### 5. Start Conservative, Tune Over Time

**Initial HPA:**

```yaml
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 50              # Start with 50% increases
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 25              # Start with 25% decreases
        periodSeconds: 120
```

**After monitoring:**

- Increase scale-up aggressiveness if response time suffers
- Decrease if you see thrashing
- Adjust stabilization windows based on traffic patterns

### 6. Use Metrics Server Properly

```bash
# Verify metrics server is running
kubectl get deployment metrics-server -n kube-system

# Check metrics are available
kubectl top nodes
kubectl top pods -n your-namespace
```

If metrics are unavailable, HPA won't work correctly.

### 7. Consider Application Startup Time

For apps with slow startup (30+ seconds):

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60    # Wait for metrics to stabilize
    policies:
    - type: Pods
      value: 2                         # Add fewer pods at a time
      periodSeconds: 60
```

### 8. Use Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: worker-service-pdb
spec:
  minAvailable: 1     # Or use maxUnavailable
  selector:
    matchLabels:
      app: worker-service
```

This prevents HPA scale-down from breaking your availability guarantees.

### 9. Monitor HPA Events

```bash
kubectl describe hpa worker-service-hpa -n hello-apis
```

Look for:

- `ScalingReplicaSet` events
- Warning messages about missing metrics
- Failed scaling attempts

### 10. Test Scaling Behavior

**Load test script:**

```bash
# Generate load
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://worker-service; done"

# Watch HPA
kubectl get hpa worker-service-hpa -w

# Clean up
kubectl delete pod load-generator
```

---

## Common Pitfalls

### 1. Missing Resource Requests

**Problem:**

```yaml
containers:
- name: app
  # No resources defined
```

**Error:**

```text
missing request for cpu
```

**Solution:**
Always define CPU/memory requests for HPA to work.

### 2. Metrics Server Not Installed

**Symptom:**

```bash
kubectl top nodes
error: Metrics API not available
```

**Solution:**

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 3. Conflicting HPAs

**Problem:**

```yaml
# HPA 1
scaleTargetRef:
  name: my-deployment

# HPA 2 - targets same deployment!
scaleTargetRef:
  name: my-deployment
```

**Result:** Unpredictable scaling, conflicts.

**Solution:** Only one HPA per deployment.

### 4. Too Aggressive Scaling

**Problem:**

```yaml
behavior:
  scaleUp:
    policies:
    - type: Percent
      value: 200              # Triple replicas
      periodSeconds: 15
  scaleDown:
    stabilizationWindowSeconds: 30    # Too short
```

**Result:** Constant thrashing, pod churn, unstable service.

**Solution:** Start conservative, tune gradually.

### 5. Memory-Based Scaling

**Problem:**

```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
```

**Issue:** Memory often isn't freed even after load decreases (caches, garbage collection delays).

**Result:** HPA scales up but never scales down.

**Solution:**

- Prefer CPU or custom metrics
- If using memory, combine with CPU and set as secondary metric
- Use very high utilization targets (85-90%)
- Ensure your app releases memory properly

### 6. Ignoring Scaling Delays

**Problem:** Expecting instant scaling.

**Reality:**

```text
Load spike → HPA detects (15s) → Pod scheduled (5-30s) → Container starts (10-60s) → Ready (5-30s)
Total: 35-135 seconds
```

**Solution:**

- Set `minReplicas` high enough for baseline load
- Use aggressive scale-up policies
- Consider pod priority classes for faster scheduling
- Optimize container startup time

### 7. Wrong Target Type

**Problem:**

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 500    # This is 500% - doesn't make sense!
```

**Solution:**

- Use `Utilization` for percentages (1-100)
- Use `AverageValue` for absolute values (e.g., `500m`)

### 8. Not Testing Under Load

**Problem:** Deploying HPA without load testing.

**Consequence:** Discovering scaling issues in production.

**Solution:**

```bash
# Load test with hey, wrk, or k6
hey -z 5m -c 50 http://your-service

# Monitor during test
watch kubectl get hpa,pods
```

### 9. Ignoring Downstream Limits

**Problem:** HPA scales to 50 pods, but database only handles 20 connections.

**Result:** Database overwhelmed, cascading failures.

**Solution:**

- Consider downstream capacity when setting `maxReplicas`
- Implement connection pooling
- Use circuit breakers
- Monitor dependencies

### 10. Misunderstanding Multiple Metrics

**Misunderstanding:** "HPA will scale based on whichever metric triggers first."

**Reality:** HPA calculates desired replicas for **each** metric and uses the **maximum**.

**Example:**

```yaml
metrics:
- CPU: Suggests 3 replicas
- Memory: Suggests 8 replicas
Result: Scales to 8 replicas (not 3)
```

---

## Monitoring and Debugging

### Checking HPA Status

```bash
# View HPA status
kubectl get hpa -n hello-apis

# Expected output:
NAME                  REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
worker-service-hpa    Deployment/worker-service   45%/70%   1         10        3          5d
```

**Fields:**

- `TARGETS`: Current / Target metric value
- `REPLICAS`: Current replica count

### Detailed HPA Information

```bash
kubectl describe hpa worker-service-hpa -n hello-apis
```

**Key sections:**

```yaml
Metrics:
  Resource cpu on pods (as a percentage of request):  45% (45m) / 70%

Conditions:
  Type            Status  Reason              Message
  ----            ------  ------              -------
  AbleToScale     True    ReadyForNewScale    recommended size matches current size
  ScalingActive   True    ValidMetricFound    the HPA was able to successfully calculate a replica count
  ScalingLimited  False   DesiredWithinRange  the desired count is within the acceptable range

Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  5m    horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization above target
```

### Viewing Current Metrics

```bash
# Pod-level metrics
kubectl top pods -n hello-apis

# Node-level metrics
kubectl top nodes

# Specific deployment
kubectl top pods -n hello-apis -l app=worker-service
```

### HPA Controller Logs

```bash
# Find controller manager pod
kubectl get pods -n kube-system | grep controller-manager

# View logs
kubectl logs -n kube-system kube-controller-manager-xxx | grep -i hpa
```

### Common Status Conditions

#### AbleToScale = False

**Meaning:** HPA cannot scale right now.

**Reasons:**

- `BackoffBoth`: Recently scaled, waiting for stabilization
- `BackoffUpscale`: Recently scaled up, waiting
- `BackoffDownscale`: Recently scaled down, waiting

**Action:** This is normal, wait for backoff period.

#### ScalingActive = False

**Meaning:** HPA cannot fetch metrics.

**Reasons:**

- `FailedGetResourceMetric`: Metrics Server unavailable
- `InvalidSelector`: Selector doesn't match pods
- `FailedGetPodsMetric`: Custom metrics unavailable

**Action:**

```bash
# Check metrics server
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# Check pod selector
kubectl get pods -n hello-apis -l app=worker-service
```

#### ScalingLimited = True

**Meaning:** HPA wanted to scale but hit limits.

**Reasons:**

- `TooManyReplicas`: At `maxReplicas`
- `TooFewReplicas`: At `minReplicas`

**Action:** Consider adjusting limits if this happens frequently.

### Debugging Checklist

**HPA not scaling:**

1. ✅ Metrics Server installed? `kubectl get deployment metrics-server -n kube-system`
2. ✅ Metrics available? `kubectl top pods -n <namespace>`
3. ✅ Resource requests defined? `kubectl get pod <pod-name> -o yaml | grep requests`
4. ✅ HPA targeting correct deployment? `kubectl describe hpa`
5. ✅ Current metrics vs target? `kubectl get hpa`
6. ✅ Any error events? `kubectl describe hpa`

**HPA scaling too much:**

1. Check stabilization windows
2. Review scaling policies
3. Verify metric targets are realistic
4. Check for metric spikes in monitoring

**HPA scaling too slow:**

1. Increase scale-up aggressiveness
2. Reduce stabilization windows
3. Check pod startup time
4. Consider increasing `minReplicas`

### Grafana Dashboard Query Examples

**HPA Metrics (Prometheus):**

```promql
# Current replicas
kube_horizontalpodautoscaler_status_current_replicas{horizontalpodautoscaler="worker-service-hpa"}

# Desired replicas
kube_horizontalpodautoscaler_status_desired_replicas{horizontalpodautoscaler="worker-service-hpa"}

# Target vs actual metric
rate(container_cpu_usage_seconds_total{pod=~"worker-service-.*"}[5m]) / on(pod) kube_pod_container_resource_requests{resource="cpu"}
```

### Monitoring Best Practices

**Key metrics to track:**

1. Current vs desired replicas (scaling effectiveness)
2. Scaling events per hour (stability)
3. Time between scaling events (thrashing indicator)
4. Metric value vs target (margin)
5. Pod startup time (scale-up latency)

**Alert examples:**

```yaml
- alert: HPAMaxedOut
  expr: kube_horizontalpodautoscaler_status_current_replicas >= kube_horizontalpodautoscaler_spec_max_replicas
  for: 15m
  annotations:
    summary: HPA at max replicas for 15+ minutes

- alert: HPAScalingFrequent
  expr: rate(kube_horizontalpodautoscaler_status_desired_replicas[5m]) > 0.1
  for: 30m
  annotations:
    summary: HPA scaling too frequently (thrashing)
```

---

## KEDA for Advanced Scaling

### What is KEDA?

**Kubernetes Event-Driven Autoscaling (KEDA)** extends HPA to support:

- **Event-driven scaling:** React to queue depth, stream lag, etc.
- **Scale to zero:** Reduce costs by scaling to 0 replicas when idle
- **External metrics:** 50+ built-in scalers (SQS, Kafka, RabbitMQ, Azure Queue, etc.)
- **Sophisticated triggers:** Multiple event sources, complex logic

### KEDA Architecture

```text
┌─────────────────────────────────────────────────────┐
│                   KEDA Operator                      │
│  ┌──────────────────┐  ┌─────────────────────────┐ │
│  │  Metrics Server  │  │  ScaledObject Controller│ │
│  │  (Custom Metrics)│  │  (Manages HPAs)         │ │
│  └──────────────────┘  └─────────────────────────┘ │
└─────────────────┬──────────────────────────────────┘
                  │
                  ├──> Queries External Systems
                  │    • Message queues (SQS, RabbitMQ, Kafka)
                  │    • Databases (PostgreSQL, MySQL, MongoDB)
                  │    • Metrics systems (Prometheus, Datadog)
                  │    • Cloud services (Azure Monitor, AWS CloudWatch)
                  │
                  └──> Creates/Manages HPA
                       • Dynamically generates HPA
                       • Injects external metrics
                       • Handles scale-to-zero
```

### Installation

#### 1. Install KEDA using Helm

```bash
# Add KEDA Helm repository
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Install KEDA in keda namespace
helm install keda kedacore/keda --namespace keda --create-namespace

# Verify installation
kubectl get pods -n keda
```

**Expected output:**

```text
NAME                                      READY   STATUS    RESTARTS   AGE
keda-operator-5d8f8c7b6c-xxxxx            1/1     Running   0          1m
keda-metrics-apiserver-6f8d9b8b7d-xxxxx   1/1     Running   0          1m
```

#### 2. Verify KEDA API Services

```bash
kubectl get apiservice | grep keda
```

**Expected:**

```text
v1beta1.external.metrics.k8s.io    keda/keda-metrics-apiserver   True        1m
```

### KEDA ScaledObject Example

#### RabbitMQ Queue-Based Scaling

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: worker-service-scaledobject
  namespace: hello-apis
spec:
  # ═══════════════════════════════════════════════════════════
  # Scale Target (same as HPA)
  # ═══════════════════════════════════════════════════════════
  scaleTargetRef:
    name: worker-service
    kind: Deployment
  
  # ═══════════════════════════════════════════════════════════
  # Scaling Boundaries
  # ═══════════════════════════════════════════════════════════
  minReplicaCount: 0           # Scale to zero when queue is empty!
  maxReplicaCount: 30          # Maximum scale-out
  
  # ═══════════════════════════════════════════════════════════
  # Idle Time Before Scale-to-Zero
  # ═══════════════════════════════════════════════════════════
  cooldownPeriod: 300          # Wait 5 minutes of idle before scaling to 0
  
  # ═══════════════════════════════════════════════════════════
  # Polling Interval
  # ═══════════════════════════════════════════════════════════
  pollingInterval: 30          # Check external metrics every 30 seconds
  
  # ═══════════════════════════════════════════════════════════
  # Triggers (Event Sources)
  # ═══════════════════════════════════════════════════════════
  triggers:
  - type: rabbitmq
    metadata:
      host: "amqp://rabbitmq.hello-apis.svc.cluster.local:5672"
      queueName: "orders"      # Monitor this queue
      queueLength: "30"        # Target: 30 messages per pod
      # When queue has 60 messages → scale to 2 pods
      # When queue has 90 messages → scale to 3 pods
      # When queue empty for 5 min → scale to 0
    authenticationRef:
      name: rabbitmq-auth      # Secret reference for credentials
```

#### AWS SQS Scaling

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sqs-worker-scaledobject
  namespace: hello-apis
spec:
  scaleTargetRef:
    name: worker-service
  minReplicaCount: 1
  maxReplicaCount: 50
  triggers:
  - type: aws-sqs-queue
    metadata:
      queueURL: "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue"
      queueLength: "5"         # 5 messages per pod
      awsRegion: "us-east-1"
      identityOwner: "operator"  # Use IAM role from operator
```

#### Kafka Consumer Lag Scaling

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaledobject
  namespace: hello-apis
spec:
  scaleTargetRef:
    name: worker-service
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: "kafka.kafka.svc.cluster.local:9092"
      consumerGroup: "my-consumer-group"
      topic: "orders"
      lagThreshold: "50"       # Scale when lag > 50 messages per pod
```

#### Prometheus Metric Scaling

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaledobject
  namespace: hello-apis
spec:
  scaleTargetRef:
    name: worker-service
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: "http://prometheus.monitoring.svc:9090"
      metricName: "http_requests_per_second"
      query: |
        sum(rate(http_requests_total{job="worker-service"}[1m]))
      threshold: "1000"        # Scale when > 1000 RPS total
```

### KEDA Authentication

For external systems requiring credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-auth
  namespace: hello-apis
type: Opaque
data:
  username: dXNlcg==          # base64 encoded
  password: cGFzc3dvcmQ=      # base64 encoded
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: rabbitmq-auth
  namespace: hello-apis
spec:
  secretTargetRef:
  - parameter: host
    name: rabbitmq-auth
    key: host
```

### Monitoring KEDA

```bash
# List ScaledObjects
kubectl get scaledobject -n hello-apis

# Describe ScaledObject
kubectl describe scaledobject worker-service-scaledobject -n hello-apis

# View generated HPA
kubectl get hpa -n hello-apis

# KEDA metrics
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1 | jq .
```

### KEDA vs Standard HPA

| Feature | Standard HPA | KEDA |
|---------|--------------|------|
| Scale to zero | ❌ | ✅ |
| CPU/Memory metrics | ✅ | ✅ |
| External event sources | Limited | 50+ built-in |
| Queue-based scaling | Manual setup | Native support |
| Multiple triggers | Complex | Simple |
| Custom metrics | Requires adapter | Built-in |
| Complexity | Lower | Moderate |

### When to Use KEDA

**Use KEDA when:**

- Need scale-to-zero (cost optimization)
- Scaling based on message queues
- External metrics from cloud services
- Event-driven workloads
- Multiple scaling triggers

**Stick with HPA when:**

- Simple CPU/memory scaling
- Metrics Server sufficient
- Don't need scale-to-zero
- Minimizing dependencies

---

## Performance Tuning

### 1. HPA Controller Configuration

The HPA controller has global settings that affect all HPAs:

```yaml
# kube-controller-manager flags
--horizontal-pod-autoscaler-sync-period=15s          # How often HPA runs (default: 15s)
--horizontal-pod-autoscaler-tolerance=0.1            # Scale if >10% difference (default: 0.1)
--horizontal-pod-autoscaler-downscale-stabilization=5m  # Deprecated: Use behavior.scaleDown instead
--horizontal-pod-autoscaler-cpu-initialization-period=5m  # Wait for CPU metrics after pod start
--horizontal-pod-autoscaler-initial-readiness-delay=30s  # Ignore pods for 30s after creation
```

**Note:** These are cluster-wide settings, typically managed by cluster admins.

### 2. Optimize Metrics Collection

#### Metrics Server Configuration

```yaml
# Increase metrics-server resources for large clusters
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: metrics-server
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        args:
        - --kubelet-preferred-address-types=InternalIP
        - --metric-resolution=15s    # Match HPA sync period
```

### 3. Pod Resource Right-Sizing

**Problem:** Over-provisioned requests lead to under-utilization and less aggressive scaling.

```yaml
# Bad: Request way higher than actual usage
resources:
  requests:
    cpu: 1000m      # Pod actually uses 100m
  limits:
    cpu: 2000m

# HPA with 70% target:
# Actual: 100m usage / 1000m request = 10% utilization
# Won't scale up until 700m usage (7x current load!)
```

**Solution:** Right-size requests based on actual usage.

```yaml
# Good: Request close to actual usage
resources:
  requests:
    cpu: 150m       # Pod uses 100-120m typically
  limits:
    cpu: 300m

# HPA with 70% target:
# Actual: 100m usage / 150m request = 67% utilization
# Will scale at 105m usage (only 5% more load)
```

**How to find right size:**

```bash
# Monitor actual usage over time
kubectl top pods -n hello-apis --sort-by=cpu

# Use VPA (Vertical Pod Autoscaler) in recommendation mode
kubectl get vpa worker-service-vpa -o yaml
```

### 4. Tuning Target Utilization

**Lower target = more headroom, less efficient:**

```yaml
target:
  averageUtilization: 50    # 50% target = 2x overhead
```

- Pros: Fast response, always have capacity
- Cons: Higher cost, lower efficiency

**Higher target = less headroom, more efficient:**

```yaml
target:
  averageUtilization: 80    # 80% target = 1.25x overhead
```

- Pros: Lower cost, higher efficiency
- Cons: Slower response, closer to limits

**Recommendation:**

- **CPU:** 70-80% (CPU scales quickly)
- **Memory:** 60-70% (memory scales slowly, need buffer)
- **Custom metrics:** Depends on metric characteristics

### 5. Optimize Scaling Policies

**For bursty workloads:**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - type: Percent
      value: 100              # Double quickly
      periodSeconds: 15
    selectPolicy: Max
  scaleDown:
    stabilizationWindowSeconds: 600    # Long window for bursts
    policies:
    - type: Percent
      value: 25               # Slow scale-down
      periodSeconds: 120
```

**For steady workloads:**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60    # Smooth out noise
    policies:
    - type: Percent
      value: 50               # Moderate growth
      periodSeconds: 60
    selectPolicy: Max
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
    - type: Percent
      value: 50
      periodSeconds: 60
```

### 6. Application Optimization

#### Fast Startup

```dockerfile
# Optimize container startup time
FROM golang:1.21-alpine AS builder
# ... build app ...

FROM alpine:3.18
# Small base image = faster pull
COPY --from=builder /app /app
CMD ["/app"]
```

**Techniques:**

- Use slim base images
- Pre-pull images on nodes
- Optimize application initialization
- Use readiness probes correctly

#### Graceful Shutdown

```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 60    # Allow time for shutdown
      containers:
      - name: worker
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 5"]    # Delay to finish requests
```

**Why:** Prevents errors during scale-down.

### 7. Node Autoscaling Coordination

HPA scales pods, but **Cluster Autoscaler** scales nodes:

```yaml
# Configure Cluster Autoscaler
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler
  namespace: kube-system
data:
  scan-interval: "10s"               # How often to check for unschedulable pods
  scale-down-delay-after-add: "10m"  # Wait before scale-down after scale-up
  scale-down-unneeded-time: "10m"    # Node idle time before removal
```

**Best practice:** Coordinate HPA max with node capacity:

- If node has 4 CPU cores, max pods per node ≈ 10-20 (depending on requests)
- Set HPA `maxReplicas` considering node scale-up time

### 8. Multiple HPAs for Different Times

**Use case:** Different scaling during business hours vs off-hours.

**Not directly supported by HPA, but can use:**

```bash
# CronJob to update HPA
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hpa-business-hours
spec:
  schedule: "0 8 * * 1-5"    # 8 AM weekdays
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl
            command:
            - kubectl
            - patch
            - hpa
            - worker-service-hpa
            - -n
            - hello-apis
            - -p
            - '{"spec":{"minReplicas":5}}'
          restartPolicy: OnFailure
```

### 9. Predictive Scaling

HPA is reactive, but you can layer predictive scaling:

**Options:**

- **KEDA with cron triggers:** Scale up before known traffic patterns
- **Custom controllers:** Use ML models to predict load
- **Manual pre-scaling:** Scale up before known events

**Example with KEDA:**

```yaml
triggers:
- type: cron
  metadata:
    timezone: America/New_York
    start: "0 8 * * 1-5"       # Scale up at 8 AM weekdays
    end: "0 18 * * 1-5"        # Scale down at 6 PM
    desiredReplicas: "10"
```

### 10. Load Balancing Considerations

HPA works best with proper load balancing:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: worker-service
spec:
  type: ClusterIP
  sessionAffinity: None          # Don't use ClientIP (causes imbalance)
  ports:
  - port: 8080
  selector:
    app: worker-service
```

**Best practices:**

- Use `sessionAffinity: None` for even distribution
- Consider connection pooling for databases
- Use readiness probes to exclude pods not ready
- Configure load balancer health checks appropriately

---

## Summary Checklist

### Before Deploying HPA

- [ ] Resource requests defined for all containers
- [ ] Metrics Server installed and working
- [ ] Baseline load testing completed
- [ ] Min/max replicas set appropriately
- [ ] Target metrics realistic for your workload
- [ ] Scaling behaviors configured (not using defaults blindly)
- [ ] Monitoring and alerting set up
- [ ] Pod Disruption Budget defined
- [ ] Graceful shutdown implemented
- [ ] Load testing under autoscaling conditions

### After Deploying HPA

- [ ] Verify HPA status is healthy
- [ ] Check metrics are being collected
- [ ] Monitor first scaling events
- [ ] Validate scale-up speed meets SLOs
- [ ] Validate scale-down doesn't cause errors
- [ ] Review cost vs performance tradeoffs
- [ ] Tune based on real traffic patterns
- [ ] Document final configuration and rationale

---

## Additional Resources

### Official Documentation

- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [KEDA Documentation](https://keda.sh/docs/)

### Tools

- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [KEDA](https://keda.sh/)
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Goldilocks (VPA recommendations)](https://github.com/FairwindsOps/goldilocks)

### Monitoring

- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards for HPA](https://grafana.com/grafana/dashboards/)
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)

---

**Last Updated:** 2024
**Version:** Kubernetes 1.23+ (autoscaling/v2)
**Maintained by:** RustAksDemoLab Project
