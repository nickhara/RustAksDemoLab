use actix_web::{get, post, web, App, HttpResponse, HttpServer, Responder};
use serde::{Deserialize, Serialize};
use std::env;
use std::sync::Arc;
use lapin::{
    options::*, types::FieldTable, BasicProperties, Channel, Connection,
    ConnectionProperties,
};
use uuid::Uuid;
use chrono::Utc;

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

/// Task message structure for RabbitMQ
#[derive(Serialize, Deserialize, Clone)]
struct TaskMessage {
    id: String,
    task_type: String,
    payload: serde_json::Value,
    timestamp: String,
}

/// Request structure for sending messages
#[derive(Deserialize)]
struct SendMessageRequest {
    task_type: String,
    payload: serde_json::Value,
}

/// Response structure for send endpoint
#[derive(Serialize)]
struct SendMessageResponse {
    success: bool,
    message_id: String,
    message: String,
}

/// Application state containing RabbitMQ channel
struct AppState {
    rabbitmq_channel: Arc<Channel>,
    queue_name: String,
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

/// Send message endpoint - Publishes a message to RabbitMQ
#[post("/send")]
async fn send_message(
    req: web::Json<SendMessageRequest>,
    data: web::Data<AppState>,
) -> impl Responder {
    let message_id = Uuid::new_v4().to_string();
    
    let task_message = TaskMessage {
        id: message_id.clone(),
        task_type: req.task_type.clone(),
        payload: req.payload.clone(),
        timestamp: Utc::now().to_rfc3339(),
    };
    
    match serde_json::to_vec(&task_message) {
        Ok(payload) => {
            let result = data.rabbitmq_channel
                .basic_publish(
                    "".into(),
                    data.queue_name.as_str().into(),
                    BasicPublishOptions::default(),
                    &payload,
                    BasicProperties::default(),
                )
                .await;
            
            match result {
                Ok(_) => {
                    log::info!("Message {} published to queue", message_id);
                    HttpResponse::Ok().json(SendMessageResponse {
                        success: true,
                        message_id,
                        message: "Message sent to queue successfully".to_string(),
                    })
                }
                Err(e) => {
                    log::error!("Failed to publish message: {}", e);
                    HttpResponse::InternalServerError().json(SendMessageResponse {
                        success: false,
                        message_id,
                        message: format!("Failed to publish message: {}", e),
                    })
                }
            }
        }
        Err(e) => {
            log::error!("Failed to serialize message: {}", e);
            HttpResponse::InternalServerError().json(SendMessageResponse {
                success: false,
                message_id,
                message: format!("Failed to serialize message: {}", e),
            })
        }
    }
}

async fn setup_rabbitmq(rabbitmq_url: &str, queue_name: &str) -> Result<Channel, Box<dyn std::error::Error>> {
    log::info!("Connecting to RabbitMQ at {}", rabbitmq_url);
    
    let conn = Connection::connect(
        rabbitmq_url,
        ConnectionProperties::default(),
    )
    .await?;
    
    let channel = conn.create_channel().await?;
    
    channel
        .queue_declare(
            queue_name.into(),
            QueueDeclareOptions {
                durable: true,
                ..Default::default()
            },
            FieldTable::default(),
        )
        .await?;
    
    log::info!("RabbitMQ connection established, queue '{}' ready", queue_name);
    
    Ok(channel)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::default().default_filter_or("info"));
    
    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse()
        .expect("PORT must be a valid number");
    
    let rabbitmq_url = env::var("RABBITMQ_URL")
        .unwrap_or_else(|_| "amqp://admin:admin123@localhost:5672".to_string());
    
    let queue_name = env::var("RABBITMQ_QUEUE")
        .unwrap_or_else(|_| "task-queue".to_string());
    
    let bind_address = format!("0.0.0.0:{}", port);
    
    log::info!("Starting Rust Hello API server on {}", bind_address);
    
    let channel = setup_rabbitmq(&rabbitmq_url, &queue_name)
        .await
        .expect("Failed to connect to RabbitMQ");
    
    let app_state = web::Data::new(AppState {
        rabbitmq_channel: Arc::new(channel),
        queue_name: queue_name.clone(),
    });
    
    HttpServer::new(move || {
        App::new()
            .app_data(app_state.clone())
            .service(hello)
            .service(health)
            .service(info)
            .service(send_message)
    })
    .bind(&bind_address)?
    .run()
    .await
}
