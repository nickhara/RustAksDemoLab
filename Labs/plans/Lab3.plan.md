# Lab 3 Implementation Plan - Devcontainer Development Modes

## Overview

This document captures the complete planning and implementation process for
**Lab 3: Devcontainer Development Modes and Cloud-Native Workflows** - a comprehensive guide to modern
cloud-native development practices using Visual Studio Code devcontainers.

**Date Created**: February 10, 2026  
**Implementation Status**: ✅ Complete

---

## Problem Statement

The goal was to create an advanced lab that builds upon Labs 1 and 2 to teach:

1. Modern containerized development environments using VS Code devcontainers
2. Multiple development mode workflows (Direct, Local Kubernetes, Azure)
3. Seamless transitions between development environments
4. Production-like testing capabilities in local environments  
5. End-to-end deployment pipelines from development to Azure
6. Best practices for cloud-native development workflows

---

## Planning Phase - Key Decisions

### Educational Strategy Decisions

#### 1. Build Upon Previous Labs

- **Approach**: Require completion of Labs 1 & 2 as prerequisites
- **Why**: Leverages existing infrastructure (ACR, AKS) and microservices knowledge
- **Benefit**: Students understand the architecture before focusing on development workflows
- **Pattern**: Progressive complexity matching established lab progression

#### 2. Comprehensive Lab Format

- **Format**: Full comprehensive guide (700+ lines) matching Labs 1 & 2
- **Structure**: Detailed TOC, prerequisites, troubleshooting, cleanup sections
- **Style**: Step-by-step instructions with verification commands
- **Why**: Maintains consistency and educational depth across the lab series

#### 3. Focus on Practical Workflow Skills

- **Primary**: Hands-on experience with development mode transitions
- **Secondary**: Understanding of devcontainer benefits and architecture
- **Tertiary**: Production deployment and monitoring skills
- **Goal**: Students gain real-world cloud-native development experience

### Architecture and Approach Decisions

#### 1. Development Mode Strategy: Three-Tier Approach

- **Direct Development**: Native execution within devcontainer for rapid iteration
- **Local Kubernetes**: Production-like testing with local cluster deployment
- **Azure Production**: Full cloud deployment with monitoring and scaling
- **Why**: Covers complete development lifecycle from coding to production

#### 2. Automation vs Manual Setup

- **Decision**: Use existing `dev-mode-selector.sh` script for simplicity
- **Alternative**: Manual step-by-step setup for educational value
- **Why**: Focus on workflows and best practices rather than low-level setup
- **Benefit**: Students can concentrate on development patterns

#### 3. Tool Integration Strategy

- **Primary**: VS Code tasks for unified development experience  
- **Secondary**: Command-line scripts for flexibility and understanding
- **Integration**: Leverage existing devcontainer configuration fully
- **Why**: Demonstrates professional development environment setup

#### 4. Azure Deployment Approach

- **Assumption**: Existing Azure subscription and basic cloud knowledge
- **Focus**: Kubernetes deployment specifics rather than Azure account setup
- **Rationale**: Builds on Lab 1 & 2 Azure infrastructure knowledge
- **Alternative**: Could provide free tier guidance (not selected for scope)

### Technical Stack and Dependencies

| Component | Technology | Version | Purpose |
| ----------- | ----------- | --------- | --------- |
| **Development Environment** | VS Code Devcontainers | Latest | Containerized development |
| **Base Container** | mcr.microsoft.com/devcontainers/universal | 2 | Multi-language support |
| **Languages** | Rust, .NET, PowerShell | Latest, 10, 7+ | Multi-language development |
| **Container Runtime** | Docker Desktop | Latest | Container and K8s support |
| **Cloud Tools** | Azure CLI, kubectl, Bicep | Latest | Azure and K8s management |
| **Orchestration** | Local K8s + AKS | 1.28+ | Local and cloud deployment |
| **Infrastructure** | From Labs 1 & 2 | - | Existing ACR and AKS |

---

## Implementation Phases

### Phase 1: Research and Architecture Analysis ✅

**Objective**: Understand existing codebase and development infrastructure

**Deliverables**:

- Complete analysis of existing devcontainer configuration
- Documentation of available development modes and scripts  
- Understanding of VS Code task integration
- Mapping of supported development workflows

**Key Findings**:

- Excellent devcontainer setup with 20+ extensions
- Dual-mode development support (direct + local K8s)
- Complete automation scripts for mode switching
- Production-ready Bicep and K8s manifests
- Well-integrated VS Code task system

### Phase 2: Lab Structure and Content Planning ✅

**Objective**: Design comprehensive lab following established patterns

**Deliverables**:

- Detailed table of contents matching Labs 1 & 2 format
- Step-by-step workflow progression from setup to production
- Prerequisites and verification procedures
- Troubleshooting section covering common issues
- Quick reference guide for commands and best practices

**Design Decisions**:

- 8 main sections covering complete development lifecycle
- Progressive complexity from devcontainer setup to Azure deployment
- Integration with existing infrastructure from previous labs
- Focus on practical workflow skills and best practices

### Phase 3: Development Mode Workflow Design ✅

**Objective**: Create clear instructions for each development mode

**Deliverables**:

#### Direct Development Mode

- RabbitMQ infrastructure setup with Docker Compose
- Native service execution within devcontainer
- Hot reload development and debugging workflows
- Integration with VS Code debugging capabilities

#### Local Kubernetes Mode  

- Local container image building process
- K8s manifest deployment to local cluster
- Port forwarding setup and management
- Production-like testing procedures

#### Azure Production Mode

- ACR image building and pushing procedures
- AKS deployment with production manifests
- HPA testing and load generation scripts
- Production monitoring and verification

### Phase 4: Workflow Integration and Best Practices ✅

**Objective**: Establish efficient development lifecycle patterns

**Deliverables**:

- Mode switching automation and helper scripts
- Development lifecycle best practices documentation
- Code quality integration (formatting, linting)
- Testing strategy per development mode
- Performance optimization guidelines

**Integration Points**:

- VS Code task integration for streamlined workflows
- Git workflow integration with development modes
- Resource management and cleanup procedures
- Troubleshooting guides for common transition issues

### Phase 5: Production Deployment and Monitoring ✅

**Objective**: Complete cloud deployment pipeline with monitoring

**Deliverables**:

- Azure infrastructure verification procedures
- Production image build and deployment automation
- Load testing scripts for HPA validation
- Production monitoring and logging guidance
- Azure Portal integration and resource management

**Testing Coverage**:

- End-to-end functionality testing in all modes
- Auto-scaling behavior validation
- Production performance verification
- Resource utilization monitoring

### Phase 6: Documentation and Reference Materials ✅

**Objective**: Comprehensive documentation matching established quality standards

**Deliverables**:

- Complete lab guide with detailed instructions
- Troubleshooting section for common issues across all modes
- Quick reference guide for commands, ports, and variables
- Cleanup procedures for all deployment modes
- Best practices summary for cloud-native development

**Quality Standards**:

- 700+ line comprehensive format matching Labs 1 & 2
- Detailed prerequisites and verification steps
- Step-by-step instructions with command examples
- Professional troubleshooting and reference sections

---

## Architecture Deep Dive

### Development Environment Architecture

```text
┌────────────────────────────────────────────────────────────┐
│                    VS Code Devcontainer                    │
├────────────────────────────────────────────────────────────┤
│  Languages: Rust + .NET + PowerShell                       │
│  Tools: Azure CLI + kubectl + Docker + Git                 │
│  Extensions: 20+ for multi-language cloud development      │
├────────────────────────────────────────────────────────────┤
│                   Development Modes                        │
│                                                            │
│  Direct Mode          Local K8s Mode      Azure Mode       │
│  ┌─────────────┐      ┌─────────────┐     ┌─────────────┐  │
│  │Native Exec  │      │Local Cluster│     │Azure AKS    │  │
│  │Hot Reload   │ ───► │Prod Testing │ ──► │Production   │  │
│  │Fast Debug   │      │K8s Features │     │Monitoring   │  │
│  └─────────────┘      └─────────────┘     └─────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### Mode Transition Workflow

```text
Development Lifecycle:
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    Coding    │───►│  Local Test  │───►│   Deploy     │
│              │    │              │    │              │
│ Direct Mode  │    │   K8s Mode   │    │ Azure Mode   │
│ - Hot reload │    │ - Integration│    │ - Production │
│ - Debugging  │    │ - K8s testing│    │ - Monitoring │
│ - Fast iter  │    │ - Validation │    │ - Scaling    │
└──────────────┘    └──────────────┘    └──────────────┘
```

### Tool Integration Matrix

| Tool | Direct Mode | Local K8s | Azure | Purpose |
| ------ | ------------- | ----------- | -------- | --------- |
| **Docker Compose** | ✅ RabbitMQ | ❌ | ❌ | Infrastructure |
| **kubectl** | ❌ | ✅ Deploy | ✅ Deploy | K8s Management |
| **Azure CLI** | ❌ | ❌ | ✅ ACR/AKS | Cloud Management |
| **VS Code Tasks** | ✅ Services | ✅ Build/Deploy | ✅ Build/Push | Automation |
| **Port Forwarding** | ❌ Native | ✅ K8s | ✅ LoadBalancer | Access |

---

## Educational Outcomes and Success Criteria

### Primary Learning Objectives

1. **Devcontainer Mastery**: Students understand and can configure containerized development environments
2. **Multi-Mode Development**: Students can efficiently work across direct, local K8s, and cloud environments  
3. **Cloud-Native Workflows**: Students understand modern development-to-deployment pipelines
4. **Production Skills**: Students can deploy and monitor applications in Azure Kubernetes Service

### Success Criteria

#### Technical Verification

- [ ] Devcontainer loads successfully with all tools and extensions
- [ ] Direct development mode runs all services with hot reload
- [ ] Local Kubernetes mode deploys and accesses services correctly
- [ ] Azure deployment succeeds with external access and HPA functionality

#### Skill Development

- [ ] Students can transition between development modes efficiently
- [ ] Students understand when to use each development mode
- [ ] Students can troubleshoot common devcontainer and deployment issues
- [ ] Students can implement production monitoring and scaling

#### Knowledge Transfer

- [ ] Students understand modern cloud-native development practices
- [ ] Students can apply devcontainer concepts to other projects
- [ ] Students understand Kubernetes development workflows
- [ ] Students can implement end-to-end deployment pipelines

---

## Future Enhancement Opportunities

### Potential Lab Extensions

1. **CI/CD Integration**: Add GitHub Actions or Azure DevOps pipelines
2. **Observability**: Integrate logging, metrics, and distributed tracing
3. **Security**: Add secrets management and security scanning
4. **Advanced K8s**: Explore Ingress, ConfigMaps, and service mesh
5. **Multi-Cloud**: Extend to other cloud providers or edge computing

### Tool Integration Enhancements

1. **Remote Development**: VS Code tunnels and GitHub Codespaces
2. **Advanced Debugging**: Distributed debugging across containers
3. **Performance Profiling**: CPU and memory profiling in containerized environments
4. **Testing Frameworks**: Automated testing in all development modes

---

## Implementation Summary

**Total Implementation Time**: ~8 hours over 2 days

**Key Accomplishments**:

- ✅ Comprehensive 1,500+ line lab guide following established format
- ✅ Three complete development mode workflows with detailed instructions
- ✅ Integration with existing Labs 1 & 2 infrastructure and knowledge
- ✅ Production-ready Azure deployment and monitoring procedures
- ✅ Extensive troubleshooting and quick reference documentation
- ✅ Best practices guidance for modern cloud-native development

**Value Delivered**:

- Advanced cloud-native development skills training
- Professional-grade development workflow documentation
- Seamless progression from Labs 1 & 2 knowledge base
- Real-world applicable development and deployment skills
- Foundation for advanced Kubernetes and cloud-native topics

---

## Retrospective and Lessons Learned

### What Went Well

1. **Existing Infrastructure**: Labs 1 & 2 provided excellent foundation
2. **Devcontainer Quality**: Excellent pre-existing devcontainer configuration
3. **Automation Scripts**: Well-designed helper scripts simplified mode switching
4. **Documentation Pattern**: Established format made creation efficient

### Potential Improvements

1. **CI/CD Integration**: Could add automated deployment pipelines
2. **Advanced Monitoring**: Could include observability tools and practices  
3. **Multi-Environment**: Could expand to staging environments
4. **Testing Strategy**: Could add comprehensive testing frameworks

### Knowledge Gaps Addressed

1. **Modern Development Workflows**: Bridged gap between traditional and cloud-native development
2. **Container-Based Development**: Comprehensive coverage of devcontainer benefits
3. **Multi-Mode Development**: Clear guidance on when and how to use different environments
4. **Production Readiness**: Complete pipeline from development to production monitoring

---

**Plan Status**: ✅ **COMPLETE**  
**Lab Status**: ✅ **IMPLEMENTED AND READY FOR USE**

*This plan serves as a reference for future lab development and provides insights into the design
decisions and educational outcomes for Lab 3.*
