#!/bin/bash

# Stop development environment
# This script stops all running services and cleans up

set -e

echo "🛑 Stopping RustAKS Demo Dev Environment..."

# Kill any running application services
echo "⏹️  Stopping application services..."

# Kill rust processes
pkill -f "cargo run" || true
pkill -f "rust-api" || true

# Kill dotnet processes
pkill -f "dotnet run" || true
pkill -f "WorkerService" || true
pkill -f "HelloApi" || true

# Stop Docker infrastructure
echo "📦 Stopping infrastructure services..."
docker-compose down

# Optional: Clean up build artifacts (uncomment if desired)
# echo "🧹 Cleaning build artifacts..."
# cd src/rust-api && cargo clean && cd ../..
# cd src && dotnet clean --nologo && cd ..

echo "✅ All services stopped!"
echo "💡 To start again, run: .devcontainer/start-dev.sh"