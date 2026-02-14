# Dev Container Validation Guide

This guide provides comprehensive testing procedures to validate that your dev container is properly configured and all components are working correctly.

## Quick Validation Checklist

- [ ] Container builds successfully
- [ ] All development tools are installed
- [ ] VS Code extensions are working
- [ ] Port forwarding is configured
- [ ] Development services start correctly
- [ ] Project builds complete without errors

## 1. Container Setup Validation

### Expected Build Output
When opening the dev container, you should see:
```
🚀 Setting up Rust AKS Demo Lab development environment...
📦 Installing additional development tools...
🦀 Setting up Rust development environment...
💻 Setting up .NET development environment...
☁️ Installing Azure CLI extensions...
⚓ Setting up kubectl auto-completion...
🔧 Setting up PowerShell environment...
📝 Setting up development aliases...
📋 Setting up Git configuration...
🏗️  Initializing project...
📦 Pre-building Rust dependencies...
📦 Restoring .NET dependencies...
✅ Dev container setup complete!
```

### Container Access Test
```bash
# Verify you're in the dev container
echo $USER
# Expected: codespace

# Check working directory
pwd
# Expected: /workspaces/RustAksDemoLab
```

## 2. Development Tools Validation

### Rust Environment
```bash
# Check Rust installation
rustc --version
# Expected: rustc 1.x.x (stable)

cargo --version
# Expected: cargo 1.x.x

# Check Rust components
rustup component list --installed
# Expected: rustfmt, clippy, rust-analyzer, etc.

# Check targets
rustup target list --installed
# Expected: x86_64-unknown-linux-gnu, x86_64-unknown-linux-musl

# Test Rust project compilation
cd src/rust-api
cargo check
# Expected: Finished dev [unoptimized + debuginfo] target(s)
```

### .NET Environment
```bash
# Check .NET version
dotnet --version
# Expected: 10.x.x

# Check .NET info
dotnet --info
# Expected: SDK version, runtime info

# Test C# API build
cd src/csharp-api
dotnet build
# Expected: Build succeeded. 0 Warning(s) 0 Error(s)

# Test Worker Service build
cd ../worker-service/WorkerService
dotnet build
# Expected: Build succeeded. 0 Warning(s) 0 Error(s)

# Check global tools
dotnet tool list -g
# Expected: dotnet-ef, libman
```

### Container & Kubernetes Tools
```bash
# Check Docker
docker --version
# Expected: Docker version 24.x.x

docker-compose --version
# Expected: Docker Compose version v2.x.x

# Check Kubernetes tools
kubectl version --client
# Expected: Client Version: v1.x.x

# Check Azure CLI
az --version
# Expected: azure-cli 2.x.x, with extensions

# Check Bicep
az bicep version
# Expected: Bicep CLI version 0.x.x
```

### PowerShell Environment
```bash
# Check PowerShell
pwsh --version
# Expected: PowerShell 7.x.x

# Check Az module (run in PowerShell)
pwsh -Command "Get-Module -ListAvailable Az"
# Expected: Az module versions listed
```

## 3. VS Code Extensions Validation

### Rust Extensions
1. Open `src/rust-api/src/main.rs`
2. **Expected Results:**
   - Syntax highlighting active
   - IntelliSense suggestions appear
   - Error squiggles for invalid syntax
   - Hover tooltips show type information
   - Code formatting works (Right-click → Format Document)

### C# Extensions
1. Open `src/csharp-api/Program.cs`
2. **Expected Results:**
   - C# syntax highlighting
   - IntelliSense and autocomplete
   - Error detection
   - Debugging icons in gutter

### Azure & Kubernetes Extensions
1. Open `infra/main.bicep`
2. **Expected Results:**
   - Bicep syntax highlighting
   - IntelliSense for Azure resources

3. Open `k8s/namespace.yaml`
4. **Expected Results:**
   - YAML syntax highlighting
   - Kubernetes resource validation

## 4. Development Services Validation

### Start Development Services
```bash
# Start RabbitMQ and other services
docker-compose up -d

# Check running containers
docker ps
# Expected: rabbitmq-dev container running

# Check service health
docker-compose ps
# Expected: All services healthy/running
```

### RabbitMQ Validation
```bash
# Check RabbitMQ is responding
curl -f http://localhost:15672
# Expected: HTTP 200 response

# Test RabbitMQ management UI
# Browser: http://localhost:15672
# Login: admin / admin123
# Expected: RabbitMQ Management interface loads
```

### Port Forwarding Validation
```bash
# Check forwarded ports
netstat -tulpn | grep -E ":(5672|15672|8080)"
# Expected: Ports 5672, 15672, and 8080 listening

# In VS Code: Check PORTS tab
# Expected: Ports appear as forwarded with labels
```

## 5. Project Build Validation

### Full Project Build Test
```bash
# Test Rust API
cd src/rust-api
cargo build
# Expected: Compilation successful

cargo test
# Expected: All tests pass

# Test C# API
cd ../csharp-api
dotnet build
# Expected: Build succeeded

dotnet test
# Expected: Tests pass (if any)

# Test Worker Service
cd ../worker-service/WorkerService
dotnet build
# Expected: Build succeeded

# Test solution build
cd ../..
dotnet build
# Expected: All projects build successfully
```

### Runtime Validation
```bash
# Start Rust API
cd src/rust-api
cargo run &
RUST_PID=$!

# Wait a moment for startup
sleep 5

# Test Rust API endpoint
curl http://localhost:8080/health
# Expected: {"status":"healthy","timestamp":"..."}

# Stop Rust API
kill $RUST_PID

# Start C# API (if configured)
cd ../csharp-api
dotnet run &
CSHARP_PID=$!

sleep 5

# Test C# API (adjust port if needed)
curl http://localhost:5000/health || curl http://localhost:8081/health
# Expected: API response

kill $CSHARP_PID
```

## 6. Lab Scenario Validation

### Lab 1 Validation
```bash
# Verify Lab 1 components can build
echo "Testing Lab 1 components..."

cd src/rust-api
cargo build --release
echo "✓ Rust API builds"

cd ../csharp-api  
dotnet build --configuration Release
echo "✓ C# API builds"

# Test Kubernetes manifests
kubectl apply --dry-run=client -f ../../k8s/namespace.yaml
echo "✓ Kubernetes manifests are valid"

# Test Bicep template
az bicep build --file ../../infra/main.bicep
echo "✓ Bicep template compiles"
```

### Lab 2 Validation
```bash
# Test Lab 2 message queue setup
echo "Testing Lab 2 components..."

# Ensure RabbitMQ is running
docker-compose up -d rabbitmq-dev

# Test worker service build
cd src/worker-service/WorkerService
dotnet build
echo "✓ Worker service builds"

# Validate HPA manifest
kubectl apply --dry-run=client -f ../../k8s/worker-hpa.yaml
echo "✓ HPA manifest is valid"
```

## 7. Environment Variables & Configuration

### Check Environment Variables
```bash
# Verify dev container environment
echo "RUST_LOG: $RUST_LOG"
# Expected: debug

echo "DOTNET_NOLOGO: $DOTNET_NOLOGO"  
# Expected: true

echo "DOTNET_CLI_TELEMETRY_OPTOUT: $DOTNET_CLI_TELEMETRY_OPTOUT"
# Expected: true
```

### Check Aliases
```bash
# Test development aliases
type c
# Expected: c is aliased to `cargo'

type dn
# Expected: dn is aliased to `dotnet'

type k
# Expected: k is aliased to `kubectl'
```

## 8. Automated Validation Script

Save this as a validation script:

```bash
#!/bin/bash
echo "🔍 Running dev container validation..."

# Tool versions
echo "📋 Checking tool versions..."
echo "Rust: $(rustc --version)"
echo ".NET: $(dotnet --version)"
echo "Docker: $(docker --version)"
echo "Azure CLI: $(az --version | head -n1)"
echo "kubectl: $(kubectl version --client --short)"

# Project builds
echo ""
echo "🏗️ Testing project builds..."
cd src/rust-api && cargo check && echo "✓ Rust API" || echo "❌ Rust API"
cd ../csharp-api && dotnet build -v q && echo "✓ C# API" || echo "❌ C# API" 
cd ../worker-service/WorkerService && dotnet build -v q && echo "✓ Worker Service" || echo "❌ Worker Service"

# Services
echo ""
echo "🚀 Testing development services..."
cd ../../..
docker-compose up -d
sleep 10
curl -f http://localhost:15672 > /dev/null 2>&1 && echo "✓ RabbitMQ" || echo "❌ RabbitMQ"

echo ""
echo "✅ Validation complete!"
```

## Expected Final State

When all validations pass, you should have:

✅ **Development Environment**
- Rust stable with all components
- .NET 10 SDK with global tools
- All VS Code extensions active

✅ **Container Services**  
- RabbitMQ running on ports 5672/15672
- Docker-in-Docker working
- Port forwarding active

✅ **Project State**
- All projects build successfully
- Dependencies restored
- Kubernetes manifests valid
- Azure Bicep templates compile

✅ **Developer Experience**
- IntelliSense working in all languages
- Debugging available
- Code formatting active
- Aliases and shortcuts configured

## Troubleshooting Failed Validations

### Container Build Failures
- Check Docker Desktop is running
- Verify sufficient disk space
- Try: "Dev Containers: Rebuild Container"

### Tool Installation Failures  
- Check internet connectivity
- Verify post-create script permissions
- Review VS Code dev container logs

### Build Failures
- Check error messages for missing dependencies
- Verify file permissions
- Try clearing caches: `cargo clean`, `dotnet clean`

### Port Conflicts
- Check for other services using ports 5672, 15672, 8080
- Stop conflicting services
- Restart dev container

### Extension Issues
- Check VS Code extension logs
- Disable/re-enable problematic extensions
- Restart VS Code

Remember to run validations after any significant changes to the dev container configuration!