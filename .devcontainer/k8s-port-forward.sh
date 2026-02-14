#!/bin/bash

# Start port forwarding for local Kubernetes services
# This makes services accessible on localhost

set -e

NAMESPACE="hello-apis-local"

echo "🔌 Starting port forwarding for local Kubernetes services..."

# Function to check if kubectl is available and cluster is accessible
check_kubernetes() {
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please ensure Kubernetes tools are installed."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Cannot connect to Kubernetes cluster."
        echo "💡 Make sure your local cluster is running (minikube, Docker Desktop K8s, kind, etc.)"
        exit 1
    fi
}

# Function to wait for pod to be ready
wait_for_pod() {
    local app_name=$1
    local timeout=60
    local counter=0
    
    echo "⏳ Waiting for $app_name pod to be ready..."
    
    while [ $counter -lt $timeout ]; do
        if kubectl get pods -n $NAMESPACE -l app=$app_name | grep -q "Running"; then
            echo "✅ $app_name is ready!"
            return 0
        fi
        
        sleep 2
        counter=$((counter + 2))
        echo "... waiting ($counter/${timeout}s)"
    done
    
    echo "⚠️ $app_name not ready after ${timeout}s, but continuing..."
    return 1
}

# Check prerequisites
check_kubernetes

# Wait for services to be ready
wait_for_pod "rabbitmq"
wait_for_pod "rust-hello-api" 
wait_for_pod "worker-service"

echo ""
echo "🚀 Starting port forwarding..."

# Start port forwarding in background
echo "📡 RabbitMQ Management UI (15672 → 15672)..."
kubectl port-forward -n $NAMESPACE service/rabbitmq 15672:15672 &

echo "🦀 Rust API (8080 → 8080)..."  
kubectl port-forward -n $NAMESPACE service/rust-hello-api 8080:8080 &

echo "🌐 C# API (5000 → 5000)..."
kubectl port-forward -n $NAMESPACE service/csharp-hello-api 5000:5000 &

# Store process IDs for cleanup
echo $! > /tmp/k8s-port-forward.pid

echo ""
echo "✅ Port forwarding started for all services!"
echo ""
echo "📊 Service URLs:"
echo "   • RabbitMQ Management: http://localhost:15672 (admin/admin123)"
echo "   • Rust API:           http://localhost:8080" 
echo "   • C# API:             http://localhost:5000"
echo ""
echo "📝 Worker service runs in background (no web interface)"
echo ""
echo "🛑 To stop port forwarding:"
echo "   • Kill this process (Ctrl+C)"
echo "   • Or run: pkill -f 'kubectl port-forward'"
echo ""
echo "⏳ Port forwarding running... (Ctrl+C to stop)"

# Keep script running
wait