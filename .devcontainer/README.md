# Dev Container Configuration

This dev container provides a complete development environment for the Rust AKS Demo Lab project, including all necessary tools and dependencies for Rust, C#, Docker, Kubernetes, and Azure development.

## What's Included

### Languages & Runtimes
- **Rust** (latest stable) with rustfmt, clippy, and cargo tools
- **.NET 10 SDK** for C# development  
- **PowerShell** for script automation

### Development Tools
- **Docker-in-Docker** for container development
- **Azure CLI** with Bicep support
- **kubectl** for Kubernetes management
- **Git** with common aliases pre-configured

### VS Code Extensions
- **Rust**: rust-analyzer, LLDB debugger, crates management
- **C#**: C# Dev Kit, OmniSharp, runtime support
- **Azure**: Azure Account, Bicep, AKS tools
- **Kubernetes**: Kubernetes tools and manifests support
- **Containers**: Docker extension and remote containers
- **General**: YAML, JSON, Markdown, and documentation tools

## Quick Start

1. **Open in Dev Container**: When you open this project in VS Code, you'll be prompted to "Reopen in Container"
2. **Wait for Setup**: The post-create script will install additional dependencies and set up the environment
3. **Start Development Services**: Run `docker-compose up` to start RabbitMQ and other services
4. **Begin Development**: Navigate to the labs and start coding!

## Port Forwarding

The following ports are automatically forwarded:
- **5672** - RabbitMQ AMQP
- **15672** - RabbitMQ Management UI (opens automatically)
- **8080** - Rust API
- **5000/5001** - C# API (HTTP/HTTPS)

## Development Aliases

The container comes with helpful aliases pre-configured:

### Rust Development
```bash
c           # cargo
cb          # cargo build
cbr         # cargo build --release
cr          # cargo run
ct          # cargo test
cw          # cargo watch
```

### .NET Development
```bash
dn          # dotnet
dnb         # dotnet build
dnr         # dotnet run
dnt         # dotnet test
```

### Docker & Kubernetes
```bash
dc          # docker-compose
dcu         # docker-compose up
dcd         # docker-compose down
k           # kubectl
kg          # kubectl get
kd          # kubectl describe
ka          # kubectl apply
```

### Azure CLI
```bash
azl         # az login
azg         # az group
azaks       # az aks
```

## Project Structure Support

The dev container is optimized for this project structure:
- **src/rust-api/** - Rust API development with full toolchain
- **src/csharp-api/** - C# API with .NET 10 support
- **src/worker-service/** - Worker service development
- **k8s/** - Kubernetes manifests with kubectl support
- **infra/** - Bicep templates with Azure CLI and Bicep tools

## Environment Variables

Pre-configured environment variables:
- `RUST_LOG=debug` - Enable Rust logging 
- `DOTNET_NOLOGO=true` - Disable .NET welcome message
- `DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true` - Skip first-time setup
- `DOTNET_CLI_TELEMETRY_OPTOUT=true` - Disable telemetry

## Additional Services (Optional)

The dev container includes optional services that can be enabled with profiles:

```bash
# Start with additional services (Redis, PostgreSQL)
docker-compose --profile extended up
```

## Troubleshooting

### Common Issues

**Container Build Failures**
If the dev container fails to build, ensure you have:
- Docker Desktop running and up-to-date
- Sufficient disk space for container images
- Network access to pull base images and features

**Rust Compilation Issues**
```bash
# Update Rust toolchain
rustup update
```

**.NET Trust Issues**
```bash
# Trust dev certificates
dotnet dev-certs https --trust
```

### Getting Help

1. Check the [main README](../README.md) for project overview
2. Review [Lab 1 Guide](../docs/LabExperimentGuide.md) for basic setup
3. Review [Lab 2 Guide](../docs/Lab2-MessageQueue.md) for advanced features
4. Check container logs: `docker-compose logs [service-name]`

## Validation

After your dev container is set up, validate the environment:

### Quick Validation
```bash
# In dev container terminal (Linux)
./validate.sh

# Or on Windows
.\validate.ps1
```

### What Gets Validated
- ✅ All development tools (Rust, .NET, Docker, Azure CLI, kubectl)
- ✅ Project builds (Rust API, C# API, Worker Service)
- ✅ Infrastructure templates (Kubernetes manifests, Bicep)
- ✅ Development services (RabbitMQ, port forwarding)
- ✅ Environment configuration

### Detailed Validation
See [validation.md](validation.md) for comprehensive testing procedures and troubleshooting.

## Next Steps

1. **Validate Environment**: Run `./validate.sh` to ensure everything works
2. **Start with Lab 1**: Follow the [Lab 1 Guide](../docs/LabExperimentGuide.md)
3. **Local Development**: Use `docker-compose up` to start services locally
4. **Azure Development**: Configure Azure CLI with `az login`
5. **Kubernetes Development**: Connect to your AKS cluster with `az aks get-credentials`

Happy coding! 🦀💻☁️