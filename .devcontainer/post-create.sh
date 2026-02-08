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
echo "🎯 Getting started:"
echo "   • Use 'docker-compose up' to start local development services"
echo "   • Use 'cargo run' in src/rust-api to start the Rust API"
echo "   • Use 'dotnet run' in src/csharp-api to start the C# API"
echo "   • Use 'kubectl get pods' to check Kubernetes resources"
echo ""
echo "📚 Available labs:"
echo "   • Lab 1: ./docs/LabExperimentGuide.md"
echo "   • Lab 2: ./docs/Lab2-MessageQueue.md"
echo ""
echo "💡 Tip: Run the validation script to ensure everything is working!"
echo ""