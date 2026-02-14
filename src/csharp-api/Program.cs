using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System;
using System.Runtime.InteropServices;

var builder = WebApplication.CreateBuilder(args);

// Configure Kestrel to listen on all interfaces
builder.WebHost.ConfigureKestrel(options =>
{
    var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
    options.ListenAnyIP(int.Parse(port));
});

// Add services
builder.Services.AddEndpointsApiExplorer();

var app = builder.Build();

// Hello World endpoint - Returns a greeting message
app.MapGet("/", (ILogger<Program> logger) =>
{
    logger.LogInformation("Hello endpoint called");
    
    return Results.Ok(new
    {
        message = "Hello, World!",
        language = "C#",
        framework = "ASP.NET Core"
    });
});

// Health check endpoint - Used by Kubernetes for liveness/readiness probes
app.MapGet("/health", (ILogger<Program> logger) =>
{
    logger.LogDebug("Health check called");
    
    return Results.Ok(new
    {
        status = "healthy",
        service = "csharp-hello-api"
    });
});

// Info endpoint - Returns detailed information about the API
app.MapGet("/info", (ILogger<Program> logger) =>
{
    logger.LogInformation("Info endpoint called");

    return Results.Ok(new
    {
        name = "Hello C# API",
        version = "1.0.0",
        language = "C#",
        framework = "ASP.NET Core",
        runtime = RuntimeInformation.FrameworkDescription  // ".NET 10.0.0"
    });
});

app.Logger.LogInformation("Starting C# Hello API server on port {Port}", 
    Environment.GetEnvironmentVariable("PORT") ?? "8080");

app.Run();
