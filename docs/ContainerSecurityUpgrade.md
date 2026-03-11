# Container Security Upgrade Runbook

## Overview

This document describes the process for publishing patched container images to Azure Container Registry (ACR) to address security vulnerabilities.

## Current Upgrade: March 2026

**Target ACR:** `acrhelloapis202601221030.azurecr.io`
**Subscription:** `9af68032-509a-4b77-b062-acbd56c079d7`
**Image:** `hello-csharp-api:latest`

### Vulnerabilities Addressed

| Vuln ID   | Description                                          |
|-----------|------------------------------------------------------|
| 5007559   | Alpine Linux 3.23 Security Update for OpenSSL        |
| 92355     | Alpine Linux 3.23 Security Update for OpenSSL        |
| 6561246   | Microsoft .NET Security Update for February 2026     |

### Remediation Strategy

1. **Alpine OpenSSL fix:** Added `RUN apk upgrade --no-cache` to the Dockerfile runtime stage so Alpine packages (including OpenSSL) are upgraded at build time.
2. **.NET security update:** Building with `docker build --pull` forces pulling the latest `mcr.microsoft.com/dotnet/aspnet:10.0-alpine` base image, which includes the .NET 10.0.3 February 2026 security patches.

## Future Upgrades

Use the reusable upgrade script:

```powershell
# Upgrade a single image
.\.build\Upgrade-ContainerImages.ps1 `
    -AcrName "acrhelloapis202601221030" `
    -SubscriptionId "9af68032-509a-4b77-b062-acbd56c079d7" `
    -Images "csharp-api"

# Upgrade all images
.\.build\Upgrade-ContainerImages.ps1 `
    -AcrName "acrhelloapis202601221030" `
    -SubscriptionId "9af68032-509a-4b77-b062-acbd56c079d7" `
    -Images "all"

# Upgrade with a specific version tag
.\.build\Upgrade-ContainerImages.ps1 `
    -AcrName "acrhelloapis202601221030" `
    -SubscriptionId "9af68032-509a-4b77-b062-acbd56c079d7" `
    -Images "rust-api,csharp-api" `
    -Version "v2.0.0"
```

### Script Parameters

| Parameter         | Required | Default  | Description                                              |
|-------------------|----------|----------|----------------------------------------------------------|
| `-AcrName`        | Yes      | —        | ACR name (without `.azurecr.io`)                         |
| `-SubscriptionId` | No       | —        | Azure subscription ID (sets context if provided)         |
| `-Images`         | No       | `all`    | Comma-separated: `rust-api`, `csharp-api`, `worker-service`, or `all` |
| `-Version`        | No       | `latest` | Image version tag                                        |

## Dockerfile Security Patterns

All Dockerfiles in this project should include `apk upgrade --no-cache` in the runtime stage to ensure OS-level security patches are applied at build time, even if the base image hasn't been refreshed:

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runtime
# Apply latest Alpine security patches
RUN apk upgrade --no-cache
```
