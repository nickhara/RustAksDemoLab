#!/bin/bash

# Build local Docker images for Kubernetes deployment
# This script builds all services as Docker images with 'local' tags

set -e

echo "🐳 Building local Docker images for Kubernetes deployment..."

# Build Rust API image
echo "🦀 Building Rust API Docker image..."
cd src/rust-api
docker build -t hello-rust-api:local .
cd ../..

# Build C# Worker Service image  
echo "💼 Building C# Worker Service Docker image..."
cd src/worker-service
docker build -t hello-worker-service:local .
cd ../..

# Build C# API image
echo "🌐 Building C# API Docker image..."
cd src/csharp-api  
docker build -t hello-csharp-api:local .
cd ../..

echo "✅ All Docker images built successfully!" 
echo ""
echo "📋 Built images:"
echo "   • hello-rust-api:local"
echo "   • hello-worker-service:local" 
echo "   • hello-csharp-api:local"
echo ""
echo "🔍 Verify images:"
docker images | grep ":local"
echo ""
echo "🚀 Ready to deploy to Kubernetes with: kubectl apply -f ./src/k8s/local/"