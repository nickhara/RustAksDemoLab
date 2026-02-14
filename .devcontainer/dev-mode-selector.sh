#!/bin/bash

# Development Mode Selector
# Choose between Direct Execution or Local Kubernetes modes

set -e

echo "🚀 RustAKS Demo Lab - Development Mode Selector"
echo "================================================"
echo ""
echo "Choose your development workflow:"
echo ""
echo "1️⃣  Direct Execution Mode (Default)"
echo "    💫 Services run directly in dev container"
echo "    ⚡ Fast iteration cycle"  
echo "    🐞 Easy debugging with IDE"
echo "    🔥 Hot reload support"
echo "    📍 Best for: Active development, debugging"
echo ""
echo "2️⃣  Local Kubernetes Mode"
echo "    ☸️  All services deployed to local K8s cluster"
echo "    🏭 Production-like environment"
echo "    🧪 Test Kubernetes manifests"
echo "    📦 Container-based deployment"
echo "    📍 Best for: K8s testing, integration testing"
echo ""
echo "3️⃣  Status & Information"
echo "    📊 Check current deployment status"
echo "    🔍 View running services"
echo ""

while true; do
    echo ""
    read -p "Select mode [1/2/3]: " mode
    case $mode in
        1)
            echo ""
            echo "🎯 Starting Direct Execution Mode..."
            ./.devcontainer/start-dev.sh
            break
            ;;
        2)
            echo ""
            echo "☸️ Setting up Local Kubernetes Mode..."
            
            # Check if kubectl is available
            if ! command -v kubectl &> /dev/null; then
                echo "❌ kubectl not found"
                echo "💡 Please ensure Kubernetes is installed and configured"
                echo "   • Docker Desktop with Kubernetes enabled"
                echo "   • minikube"
                echo "   • kind"
                exit 1
            fi
            
            # Check if cluster is accessible
            if ! kubectl cluster-info &> /dev/null; then
                echo "❌ Cannot connect to Kubernetes cluster"
                echo "💡 Please start your local cluster:"
                echo "   • Docker Desktop: Enable Kubernetes"
                echo "   • minikube: minikube start"
                echo "   • kind: kind create cluster"
                exit 1
            fi
            
            echo "✅ Kubernetes cluster detected"
            echo "🐳 Building Docker images..."
            ./.devcontainer/build-local-images.sh
            
            echo ""
            echo "☸️ Deploying to Kubernetes..."
            kubectl apply -f ./src/k8s/local/
            
            echo ""
            echo "🔌 Starting port forwarding..."
            ./.devcontainer/k8s-port-forward.sh &
            
            echo "✅ Local Kubernetes mode ready!"
            break
            ;;
        3)
            echo ""
            echo "📊 Checking status..."
            
            echo "🔍 Direct Execution Mode:"
            if docker ps | grep -q rabbitmq; then
                echo "✅ RabbitMQ container is running"
            else
                echo "❌ RabbitMQ container not running"
            fi
            
            if pgrep -f "cargo run" > /dev/null; then
                echo "✅ Rust services running"
            else
                echo "❌ No Rust services detected"
            fi
            
            if pgrep -f "dotnet run" > /dev/null; then
                echo "✅ .NET services running"  
            else
                echo "❌ No .NET services detected"
            fi
            
            echo ""
            echo "🔍 Kubernetes Mode:"
            if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
                if kubectl get namespace hello-apis-local &> /dev/null; then
                    echo "✅ K8s deployment detected"
                    kubectl get pods -n hello-apis-local
                else
                    echo "❌ K8s namespace not found" 
                fi
            else
                echo "❌ Kubernetes not available"
            fi
            
            echo ""
            echo "🔌 Port Forwarding:"
            if pgrep -f "kubectl port-forward" > /dev/null; then
                echo "✅ K8s port forwarding active"
            else
                echo "❌ No K8s port forwarding"
            fi
            
            continue
            ;;
        *)
            echo "❌ Invalid selection. Please choose 1, 2, or 3."
            continue
            ;;
    esac
done

echo ""
echo "🎉 Setup complete! Happy coding!"