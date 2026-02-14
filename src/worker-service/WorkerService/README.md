# Worker Service Configuration

This worker service processes messages from RabbitMQ. Configuration is managed through ASP.NET Core's configuration system.

## Configuration Sources (in order of precedence)

1. **Environment Variables** (highest priority)
2. **User Secrets** (Development environment only)
3. **appsettings.{Environment}.json**
4. **appsettings.json** (lowest priority)

## Required Configuration

### RabbitMQ Settings

| Setting | Description | Default | Required |
| --------- | ------------- | --------- | ---------- |
| `RabbitMQ__Host` | RabbitMQ server hostname | `localhost` | No |
| `RabbitMQ__Port` | RabbitMQ server port | `5672` | No |
| `RabbitMQ__Username` | RabbitMQ username | None | **Yes** |
| `RabbitMQ__Password` | RabbitMQ password | None | **Yes** |
| `RabbitMQ__Queue` | Queue name to consume from | `task-queue` | No |

### Processing Settings

| Setting | Description | Default |
| --------- | ------------- | --------- |
| `ProcessingDelayMs` | Simulated processing time (ms) | `2000` |

## Configuration by Environment

### Local Development

For local development, credentials are provided in `appsettings.Development.json`:

```json
{
  "RabbitMQ": {
    "Username": "admin",
    "Password": "admin123"
  }
}
```

> **Note**: These are intentionally simple credentials for lab/development use only.
> For production environments, always use strong, unique passwords stored in Kubernetes Secrets.

Alternatively, use **User Secrets** for better security:

```bash
dotnet user-secrets set "RabbitMQ:Username" "admin"
dotnet user-secrets set "RabbitMQ:Password" "admin123"
```

### Docker Compose

When running with docker-compose, credentials are set via environment variables:

```yaml
environment:
  RabbitMQ__Host: rabbitmq
  RabbitMQ__Username: admin
  RabbitMQ__Password: admin123
```

### Kubernetes (AKS)

In Kubernetes, credentials are loaded from **Kubernetes Secrets**:

```yaml
env:
- name: RabbitMQ__Username
  valueFrom:
    secretKeyRef:
      name: rabbitmq-secret
      key: username
- name: RabbitMQ__Password
  valueFrom:
    secretKeyRef:
      name: rabbitmq-secret
      key: password
```

Create the secret:

```bash
kubectl create secret generic rabbitmq-secret \
  --from-literal=username=your-secure-username \
  --from-literal=password=your-secure-password \
  -n hello-apis
```

## Security Best Practices

1. **Never commit real passwords** to `appsettings.json`
2. Use **placeholders** (e.g., `<RABBITMQ_PASSWORD>`) in `appsettings.json`
3. Use **User Secrets** for local development credentials
4. Use **Kubernetes Secrets** for production credentials
5. Use **Environment Variables** for container orchestration

## Running the Service

### Running Locally

```bash
cd src/worker-service/WorkerService
dotnet run
```

### Using Docker

```bash
docker build -t worker-service:latest ./src/worker-service
docker run -e RabbitMQ__Username=admin -e RabbitMQ__Password=admin123 worker-service:latest
```

### Using Docker Compose

```bash
docker-compose up worker-service
```
