use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
use serde::Serialize;
use std::env;

/// Response structure for the hello endpoint
#[derive(Serialize)]
struct HelloResponse {
    message: String,
    language: String,
    framework: String,
}

/// Response structure for the health endpoint
#[derive(Serialize)]
struct HealthResponse {
    status: String,
    service: String,
}

/// Response structure for the info endpoint
#[derive(Serialize)]
struct InfoResponse {
    name: String,
    version: String,
    language: String,
    framework: String,
    runtime: String,
}

/// Hello World endpoint - Returns a greeting message
#[get("/")]
async fn hello() -> impl Responder {
    log::info!("Hello endpoint called");
    
    let response = HelloResponse {
        message: "Hello, World!".to_string(),
        language: "Rust".to_string(),
        framework: "Actix-web".to_string(),
    };
    
    HttpResponse::Ok().json(response)
}

/// Health check endpoint - Used by Kubernetes for liveness/readiness probes
#[get("/health")]
async fn health() -> impl Responder {
    log::debug!("Health check called");
    
    let response = HealthResponse {
        status: "healthy".to_string(),
        service: "rust-hello-api".to_string(),
    };
    
    HttpResponse::Ok().json(response)
}

/// Info endpoint - Returns detailed information about the API
#[get("/info")]
async fn info() -> impl Responder {
    log::info!("Info endpoint called");
    
    let response = InfoResponse {
        name: "Hello Rust API".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        language: "Rust".to_string(),
        framework: "Actix-web 4.x".to_string(),
        runtime: format!("Rust {}", rustc_version_runtime::version()),
    };
    
    HttpResponse::Ok().json(response)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logger
    env_logger::init_from_env(env_logger::Env::default().default_filter_or("info"));
    
    // Get port from environment variable or use default
    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse()
        .expect("PORT must be a valid number");
    
    let bind_address = format!("0.0.0.0:{}", port);
    
    log::info!("Starting Rust Hello API server on {}", bind_address);
    
    HttpServer::new(|| {
        App::new()
            .service(hello)
            .service(health)
            .service(info)
    })
    .bind(&bind_address)?
    .run()
    .await
}
