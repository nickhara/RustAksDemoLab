#!/bin/bash

# Post-create setup script for Rust AKS Demo Lab dev container
echo "🚀 Setting up Rust AKS Demo Lab development environment..."

# Update package lists
sudo apt-get update

# Install additional development tools
echo "📦 Installing additional development tools..."
sudo apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    tree \
    htop

# Install Rust components
echo "🦀 Setting up Rust development environment..."
rustup component add rustfmt clippy
rustup target add x86_64-unknown-linux-musl

# Install cargo tools for development
cargo install cargo-watch cargo-edit

# Setup .NET development environment
echo "💻 Setting up .NET development environment..."
# Trust the development certificate for HTTPS
dotnet dev-certs https --trust

# Install global .NET tools
dotnet tool install -g dotnet-ef
dotnet tool install -g Microsoft.Web.LibraryManager.Cli

# Install additional Azure CLI extensions
echo "☁️ Installing Azure CLI extensions..."
az extension add --name aks-preview --allow-preview true
az extension add --name azure-devops

# Setup kubectl auto-completion
echo "⚓ Setting up kubectl auto-completion..."
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc

# Setup PowerShell aliases and environment
echo "🔧 Setting up PowerShell environment..."
pwsh -Command "Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser"

# Create useful aliases
echo "📝 Setting up development aliases..."
cat << 'EOF' >> ~/.bashrc

# Rust development aliases
alias c='cargo'
alias cb='cargo build'
alias cbr='cargo build --release'
alias cr='cargo run'
alias ct='cargo test'
alias cw='cargo watch'

# .NET development aliases
alias dn='dotnet'
alias dnb='dotnet build'
alias dnr='dotnet run'
alias dnt='dotnet test'

# Docker aliases
alias dc='docker-compose'
alias dcu='docker-compose up'
alias dcd='docker-compose down'

# Kubernetes aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias ka='kubectl apply'

# Azure aliases
alias azl='az login'
alias azg='az group'
alias azaks='az aks'

EOF

# Setup Git configuration (if not already set)
echo "📋 Setting up Git configuration..."
if [ -z "$(git config --global user.email)" ]; then
    echo "⚠️  Git user.email not set. You may want to configure it:"
    echo "   git config --global user.email 'your-email@example.com'"
fi

if [ -z "$(git config --global user.name)" ]; then
    echo "⚠️  Git user.name not set. You may want to configure it:"
    echo "   git config --global user.name 'Your Name'"
fi

# Initialize the project
echo "🏗️  Initializing project..."

# Build Rust dependencies (this will download and compile dependencies)
cd /workspaces/RustAksDemoLab/src/rust-api
echo "📦 Pre-building Rust dependencies..."
cargo fetch

# Restore .NET dependencies
cd /workspaces/RustAksDemoLab/src
echo "📦 Restoring .NET dependencies..."
dotnet restore

echo ""
echo "✅ Dev container setup complete!"
echo ""
echo "🔍 Validate your environment:"
echo "   • Run: ./.devcontainer/validate.sh"
echo "   • This will test all tools and build all projects"
echo ""
echo "🎯 Choose your development mode:"
echo "   • All-in-one: ./.devcontainer/dev-mode-selector.sh"
echo "   • Direct mode: ./.devcontainer/start-dev.sh"
echo ""
echo "📋 Available Development Modes:"
echo ""
echo "1️⃣  Direct Execution Mode (Default)"
echo "     • Services run directly in dev container"
echo "     • Fast iteration with hot reload"
echo "     • Easy debugging with VS Code"
echo "     • Tasks: 'Start All Services', 'Start Rust API', etc."
echo ""
echo "2️⃣  Local Kubernetes Mode"  
echo "     • All services deployed to local K8s cluster"
echo "     • Test Kubernetes manifests locally"
echo "     • Production-like environment"
echo "     • Tasks: '☸️ Full K8s Setup', '🐳 Build Local Docker Images'"
echo ""
echo "🎮 VS Code Tasks (Ctrl+Shift+P → 'Tasks: Run Task'):"
echo "   Direct Mode:"
echo "     • 'Start All Services' - infrastructure + all services"
echo "     • 'Start Infrastructure' - just RabbitMQ"  
echo "     • 'Start Rust API' - Rust service with debugging"
echo "     • 'Start C# Worker' - worker service with debugging"
echo ""
echo "   Kubernetes Mode:"
echo "     • '☸️ Full K8s Setup' - build images + deploy + port-forward"
echo "     • '🐳 Build Local Docker Images' - build container images"
echo "     • '☸️ Deploy to Local K8s' - deploy to cluster"
echo "     • '🔌 Start K8s Port Forwarding' - expose services"
echo "     • '📊 K8s Status' - check deployment status"
echo ""
echo "🐞 Debugging:"
echo "   • Direct Mode: F5 → select service to debug natively"
echo "   • K8s Mode: kubectl logs <pod> -f for log streaming"
echo ""
echo "📦 Service URLs (both modes):"
echo "   • RabbitMQ Management: http://localhost:15672 (admin/admin123)"
echo "   • Rust API: http://localhost:8080"
echo "   • C# API: http://localhost:5000"
echo ""
echo "📚 Available labs:"
echo "   • Lab 1: ./Labs/Lab1.RustAksDemo.md"
echo "   • Lab 2: ./Labs/Lab2.MessageQueue.md"
echo ""
echo "🔄 Service Management:"
echo "   • Mode selector: ./.devcontainer/dev-mode-selector.sh"
echo "   • Direct start: ./.devcontainer/start-dev.sh"
echo "   • Stop all: ./.devcontainer/stop-dev.sh"
echo "   • K8s status: ./.devcontainer/k8s-status.sh"
echo ""
echo "💡 New dual-mode workflow:"
echo "   🏃 Use Direct Execution for fast development"
echo "   ☸️  Use Kubernetes Mode for integration testing"
echo ""