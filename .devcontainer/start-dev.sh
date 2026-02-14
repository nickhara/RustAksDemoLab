#!/bin/bash

# Start development environment 
# This script starts infrastructure and all application services

set -e

echo "🚀 Starting RustAKS Demo Dev Environment..."
echo ""
echo "🔄 Choose your development mode:"
echo "   1️⃣  Direct Execution Mode (recommended for development)"
echo "       • Services run directly in dev container"
echo "       • Fast iteration, easy debugging"
echo "       • RabbitMQ runs in Docker"
echo ""
echo "   2️⃣  Local Kubernetes Mode (for K8s testing)"
echo "       • All services deployed to local K8s cluster"
echo "       • Test Kubernetes manifests locally"
echo "       • More production-like environment"
echo ""
echo "Starting Direct Execution Mode infrastructure..."

# Start infrastructure (RabbitMQ)
echo "📦 Starting infrastructure services..."
docker-compose up -d rabbitmq

# Wait for RabbitMQ to be ready
echo "⏳ Waiting for RabbitMQ to be ready..."
timeout 60 bash -c '
    until docker-compose exec rabbitmq rabbitmq-diagnostics ping > /dev/null 2>&1; do
        echo "Waiting for RabbitMQ..."
        sleep 2
    done
'

echo "✅ RabbitMQ is ready!"

# Build applications
echo "🔨 Building applications..."
cd src/rust-api && cargo build --quiet && cd ../..
cd src/worker-service/WorkerService && dotnet build --quiet --nologo && cd ../../..
cd src/csharp-api && dotnet build --quiet --nologo && cd ../..

echo "✅ Applications built successfully!"
echo ""
echo "🎯 Direct Execution Mode ready! Use VS Code tasks:"
echo "   - Ctrl+Shift+P → 'Tasks: Run Task' → 'Start All Services'"
echo "   - Or manually start individual services:"
echo "     • Start Rust API"
echo "     • Start C# Worker" 
echo "     • Start C# API"
echo ""
echo "☸️ Want to test in Kubernetes instead?"
echo "   - 'Tasks: Run Task' → '☸️ Full K8s Setup'"
echo "   - This builds Docker images and deploys to local K8s"
echo ""
echo "📊 Service URLs:"
echo "   • RabbitMQ Management: http://localhost:15672 (admin/admin123)"
echo "   • Rust API: http://localhost:8080"
echo "   • C# API: http://localhost:5000"
echo ""
echo "🐰 RabbitMQ is running in Docker, application services can run:"
echo "   📍 Directly (dev container) - for faster development"
echo "   ☸️  In Kubernetes - for testing K8s manifests"