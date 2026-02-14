#!/bin/bash

# Check status of local Kubernetes deployment
# Shows pods, services, and useful debugging information

set -e

NAMESPACE="hello-apis-local"

echo "📊 Local Kubernetes Deployment Status"
echo "======================================"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "💡 Make sure your local cluster is running:"
    echo "   • Docker Desktop Kubernetes"  
    echo "   • minikube start"
    echo "   • kind create cluster"
    exit 1
fi

# Show cluster info
echo ""
echo "🏗️ Cluster Information:"
kubectl cluster-info | head -1

# Check namespace
echo ""
echo "📦 Namespace:"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "✅ Namespace '$NAMESPACE' exists"
else
    echo "❌ Namespace '$NAMESPACE' not found"
    echo "💡 Run the deployment first: kubectl apply -f ./src/k8s/local/"
    exit 1
fi

# Show pods status
echo ""
echo "🚀 Pods Status:"
kubectl get pods -n $NAMESPACE

# Show services
echo ""
echo "🔗 Services:"
kubectl get services -n $NAMESPACE

# Show detailed pod information if any are not running
echo ""
echo "🔍 Pod Details:"
pods_not_running=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running" | wc -l)

if [ $pods_not_running -gt 0 ]; then
    echo "⚠️ Found $pods_not_running pod(s) not in Running state:"
    kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running" | while read line; do
        pod_name=$(echo $line | awk '{print $1}')
        echo ""
        echo "📋 Pod: $pod_name"
        echo "--- Recent events ---"
        kubectl describe pod $pod_name -n $NAMESPACE | grep -A 10 "Events:"
        echo ""
        echo "--- Recent logs ---"
        kubectl logs $pod_name -n $NAMESPACE --tail=10 || echo "No logs available"
    done
else
    echo "✅ All pods are running successfully!"
fi

# Show persistent volumes
echo ""
echo "💾 Storage:"
kubectl get pvc -n $NAMESPACE

# Show resource usage if metrics are available
echo ""
echo "📈 Resource Usage (if metrics available):"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "💡 Metrics not available (install metrics-server for resource usage)"

# Check port forwarding
echo ""
echo "🔌 Port Forwarding Status:"
if pgrep -f "kubectl port-forward" > /dev/null; then
    echo "✅ Port forwarding processes are running:"
    ps aux | grep "kubectl port-forward" | grep -v grep || true
else
    echo "❌ No port forwarding detected"
    echo "💡 Start port forwarding with the task '🔌 Start K8s Port Forwarding'"
fi

echo ""
echo "🎯 Quick Actions:"
echo "   • View all resources:    kubectl get all -n $NAMESPACE"
echo "   • Check specific pod:    kubectl describe pod <pod-name> -n $NAMESPACE" 
echo "   • View pod logs:         kubectl logs <pod-name> -n $NAMESPACE -f"
echo "   • Delete deployment:     kubectl delete -f ./src/k8s/local/"
echo "   • Restart deployment:    kubectl rollout restart deployment -n $NAMESPACE"