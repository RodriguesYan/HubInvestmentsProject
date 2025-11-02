# Multi-stage Dockerfile for Hub Market Data Service

# ==============================================================================
# Stage 1: Builder
# ==============================================================================
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /app

# Allow Go to auto-download required toolchain
ENV GOTOOLCHAIN=auto

# Copy go mod files from hub-market-data-service directory
COPY hub-market-data-service/go.mod hub-market-data-service/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code from hub-market-data-service directory
COPY hub-market-data-service/ .

# Build arguments
ARG VERSION=dev
ARG BUILD_TIME
ARG GIT_COMMIT

# Build the application
# Build for the target architecture (auto-detected)
RUN CGO_ENABLED=0 go build \
    -ldflags="-w -s -X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME} -X main.GitCommit=${GIT_COMMIT}" \
    -o /app/bin/market-data-service \
    ./cmd/server/main.go

# ==============================================================================
# Stage 2: Runtime
# ==============================================================================
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/bin/market-data-service /app/market-data-service

# Copy configuration files (if any)
# COPY --from=builder /app/configs /app/configs

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose ports
# 8083: HTTP server (if implemented)
# 50054: gRPC server
EXPOSE 8083 50054

# Health check
# Note: Health check endpoint needs to be implemented
# For now, we check if the gRPC port is listening
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD nc -z localhost 50054 || exit 1

# Set entrypoint
ENTRYPOINT ["/app/market-data-service"]

