# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["WorkerService.csproj", "./"]
RUN dotnet restore "WorkerService.csproj"

# Copy everything else and build
COPY . .
RUN dotnet build "WorkerService.csproj" -c Release -o /app/build

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish "WorkerService.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 3: Runtime
FROM mcr.microsoft.com/dotnet/runtime:9.0 AS final
WORKDIR /app

# Create non-root user
RUN groupadd -r workeruser && useradd -r -g workeruser workeruser
USER workeruser

COPY --from=publish /app/publish .

ENTRYPOINT ["dotnet", "WorkerService.dll"]
