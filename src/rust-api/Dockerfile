# Build stage
FROM rust:1.98-alpine AS builder

# Install build dependencies
RUN apk add --no-cache musl-dev

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock* ./

# Create a dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies (this layer will be cached)
RUN cargo build --release && rm -rf src

# Copy actual source code
COPY src ./src

# Build the actual application
RUN touch src/main.rs && cargo build --release

# Runtime stage
FROM alpine:3.23

# Install runtime dependencies and apply OS-level security patches
RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates wget

# Create non-root user for security
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/target/release/hello-rust-api /app/hello-rust-api

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Set environment variables
ENV PORT=8080
ENV RUST_LOG=info

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the binary
CMD ["./hello-rust-api"]
