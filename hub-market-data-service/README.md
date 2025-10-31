# Hub Market Data Service

**Microservice for Market Data and Real-time Quotes**

## Overview

The Hub Market Data Service is a standalone microservice extracted from the HubInvestments monolith. It provides:

- **Market Data Queries**: Fetch instrument details (symbol, name, price, category)
- **Real-time Quotes**: WebSocket streaming of live price updates
- **Caching**: High-performance Redis caching (>95% hit rate)
- **gRPC API**: Internal service-to-service communication
- **HTTP REST API**: External client access via API Gateway

## Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  (HTTP REST, gRPC, WebSocket)                               │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                    Application Layer                        │
│  (Use Cases, DTOs)                                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                      Domain Layer                           │
│  (Models, Repository Interfaces, Business Logic)            │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                  Infrastructure Layer                       │
│  (PostgreSQL, Redis, WebSocket Manager)                     │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

- **Language**: Go 1.22+
- **Database**: PostgreSQL 16
- **Cache**: Redis 7
- **Communication**: gRPC, HTTP REST, WebSocket
- **Containerization**: Docker, Docker Compose
- **Observability**: Prometheus metrics, structured logging

## Getting Started

### Prerequisites

- Go 1.22 or higher
- Docker and Docker Compose
- PostgreSQL 16 (or use Docker)
- Redis 7 (or use Docker)

### Local Development

#### 1. Clone the Repository

```bash
git clone https://github.com/RodriguesYan/hub-market-data-service.git
cd hub-market-data-service
```

#### 2. Install Dependencies

```bash
go mod download
```

#### 3. Set Up Environment Variables

Copy the example environment file and update with your values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# ====================================
# SERVER CONFIGURATION
# ====================================
SERVER_PORT=8083
SERVER_READ_TIMEOUT=15s
SERVER_WRITE_TIMEOUT=15s
SERVER_SHUTDOWN_TIMEOUT=10s

# ====================================
# DATABASE CONFIGURATION (PostgreSQL)
# ====================================
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=hub_market_data
DB_SSLMODE=disable

# ====================================
# REDIS CONFIGURATION
# ====================================
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# ====================================
# GRPC CONFIGURATION
# ====================================
GRPC_PORT=50053

# ====================================
# CACHE CONFIGURATION
# ====================================
CACHE_TTL_MINUTES=5

# ====================================
# PRICE OSCILLATION SERVICE
# ====================================
PRICE_UPDATE_INTERVAL=4
PRICE_OSCILLATION_PERCENT=0.01

# ====================================
# LOGGING
LOG_LEVEL=info
LOG_FORMAT=json

# Metrics
METRICS_ENABLED=true
METRICS_PORT=9090
```

#### 4. Run with Docker Compose

```bash
docker-compose up -d
```

This will start:
- PostgreSQL database
- Redis cache
- Market Data Service

#### 5. Run Locally (without Docker)

```bash
# Start PostgreSQL and Redis (if not using Docker)
# Then run the service
go run cmd/server/main.go
```

### Running Tests

#### Unit Tests

```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run tests with verbose output
go test -v ./...

# Run unit tests only
make test-unit

# Run integration tests (requires Docker)
go test -tags=integration ./...
```

#### Streaming Integration Tests

```bash
# Run all streaming tests (automated unit/integration tests)
make test-streaming

# Or run the test script directly:
./scripts/test_streaming.sh
```

#### Standalone Streaming Test Clients

These are interactive test clients for manual testing and load testing:

```bash
# Run single streaming client test
./scripts/run_streaming_tests.sh client

# With custom parameters:
./scripts/run_streaming_tests.sh client --symbols AAPL,GOOGL,MSFT --duration 60s

# Run load test (100 concurrent clients by default)
./scripts/run_streaming_tests.sh load

# Load test with custom parameters:
./scripts/run_streaming_tests.sh load --clients 200 --duration 2m

# Run both tests sequentially:
./scripts/run_streaming_tests.sh both
```

**Test Client Options:**
- `--server <address>` - gRPC server address (default: localhost:50054)
- `--symbols <list>` - Comma-separated symbols (default: AAPL,GOOGL,MSFT)
- `--duration <time>` - Test duration (default: 30s)
- `--clients <number>` - Number of concurrent clients for load test (default: 100)

**Test Coverage:**
- Subscribe and receive quotes
- Multiple subscriptions
- Unsubscribe from symbols
- Heartbeat mechanism (30s interval)
- Graceful reconnection
- Context cancellation
- Concurrent clients (10, 100, 1000+)
- Symbol scaling (up to 20 symbols)
- Data structure validation

### Building

```bash
# Build binary
go build -o bin/market-data-service cmd/server/main.go

# Build Docker image
docker build -t hub-market-data-service:latest .

# Build with version
docker build -t hub-market-data-service:v1.0.0 --build-arg VERSION=v1.0.0 .
```

## API Documentation

### gRPC API

**Service**: `MarketDataService`

**Methods**:
- `GetMarketData(symbols []string) -> MarketDataResponse`
- `StreamMarketData(symbols []string) -> stream MarketDataUpdate` (future)

**Proto Definition**: `internal/infrastructure/grpc/proto/market_data.proto`

### HTTP REST API

**Base URL**: `http://localhost:8080/api/v1`

#### Endpoints

1. **Get Market Data**
   ```
   GET /market-data?symbols=AAPL,MSFT
   Authorization: Bearer <JWT_TOKEN>
   ```

2. **Invalidate Cache** (Admin)
   ```
   POST /admin/market-data/cache/invalidate
   Authorization: Bearer <ADMIN_JWT_TOKEN>
   Content-Type: application/json

   {
     "symbols": ["AAPL", "MSFT"]
   }
   ```

3. **Warm Cache** (Admin)
   ```
   POST /admin/market-data/cache/warm
   Authorization: Bearer <ADMIN_JWT_TOKEN>
   Content-Type: application/json

   {
     "symbols": ["AAPL", "MSFT", "TSLA"]
   }
   ```

### WebSocket API

**Endpoint**: `ws://localhost:8082/ws/quotes`

**Query Parameters**:
- `symbols`: Comma-separated list of symbols (e.g., `AAPL,MSFT`)
- `token`: JWT authentication token

**Message Format**: JSON Patch (RFC 6902)

**Example Initial Message**:
```json
{
  "type": "quotes_patch",
  "operations": [
    {
      "op": "add",
      "path": "/quotes/AAPL",
      "value": {
        "symbol": "AAPL",
        "current_price": 150.25,
        "change": 1.50,
        "change_percent": 1.01,
        "last_updated": "2024-07-20T10:30:00Z"
      }
    }
  ]
}
```

**Example Update Message**:
```json
{
  "type": "quotes_patch",
  "operations": [
    {
      "op": "replace",
      "path": "/quotes/AAPL/current_price",
      "value": 150.75
    }
  ]
}
```

## Project Structure

```
hub-market-data-service/
├── cmd/
│   └── server/
│       └── main.go                 # Application entry point
├── internal/
│   ├── domain/
│   │   ├── model/                  # Domain models
│   │   ├── repository/             # Repository interfaces
│   │   └── service/                # Domain services
│   ├── application/
│   │   ├── usecase/                # Use cases (business logic)
│   │   └── dto/                    # Data transfer objects
│   ├── infrastructure/
│   │   ├── persistence/            # Database repositories
│   │   ├── cache/                  # Redis cache
│   │   ├── grpc/                   # gRPC server
│   │   ├── http/                   # HTTP REST handlers
│   │   └── websocket/              # WebSocket handlers
│   └── config/
│       └── config.go               # Configuration management
├── pkg/
│   ├── logger/                     # Logging utilities
│   └── errors/                     # Error handling
├── scripts/
│   ├── setup_database.sh           # Database setup script
│   └── migrate_data.sh             # Data migration script
├── deployments/
│   ├── docker-compose.yml          # Docker Compose configuration
│   └── kubernetes/                 # Kubernetes manifests
├── docs/
│   ├── API.md                      # API documentation
│   ├── ARCHITECTURE.md             # Architecture overview
│   └── DEPLOYMENT.md               # Deployment guide
├── .env.example                    # Example environment variables
├── .gitignore                      # Git ignore rules
├── Dockerfile                      # Docker image definition
├── Makefile                        # Build automation
├── go.mod                          # Go module definition
├── go.sum                          # Go module checksums
└── README.md                       # This file
```

## Configuration

The service can be configured using environment variables or a `config.yaml` file. Environment variables take precedence over config file values.

### Configuration Files

1. **`.env.example`**: Template for environment variables (copy to `.env`)
2. **`config.yaml`**: Structured YAML configuration with defaults

### Environment Variables

#### Server Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVER_PORT` | HTTP server port | `8083` |
| `SERVER_READ_TIMEOUT` | HTTP read timeout | `15s` |
| `SERVER_WRITE_TIMEOUT` | HTTP write timeout | `15s` |
| `SERVER_SHUTDOWN_TIMEOUT` | Graceful shutdown timeout | `10s` |

#### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_USER` | PostgreSQL user | `postgres` |
| `DB_PASSWORD` | PostgreSQL password | `postgres` |
| `DB_NAME` | Database name | `hub_market_data` |
| `DB_SSLMODE` | SSL mode (disable, require, verify-ca, verify-full) | `disable` |

#### Redis Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_PASSWORD` | Redis password | `` |
| `REDIS_DB` | Redis database number | `0` |

#### gRPC Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `GRPC_PORT` | gRPC server port | `50053` |

#### Cache Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `CACHE_TTL_MINUTES` | Cache TTL in minutes | `5` |

#### Price Oscillation Service

| Variable | Description | Default |
|----------|-------------|---------|
| `PRICE_UPDATE_INTERVAL` | Price update interval (seconds) | `4` |
| `PRICE_OSCILLATION_PERCENT` | Price oscillation percentage (e.g., 0.01 = ±1%) | `0.01` |

#### Logging Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `LOG_LEVEL` | Logging level (debug, info, warn, error) | `info` |
| `LOG_FORMAT` | Log format (json, text) | `json` |

#### Environment

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment (development, staging, production) | `development` |

### Configuration Example

**Using `.env` file**:

```bash
# Copy example and edit
cp .env.example .env

# Edit with your values
nano .env
```

**Using `config.yaml`**:

```yaml
server:
  port: 8083
  read_timeout: 15s

database:
  host: localhost
  port: 5432
  user: postgres
  dbname: hub_market_data

grpc:
  port: 50053

cache:
  ttl_minutes: 5

price_oscillation:
  update_interval_seconds: 4
  oscillation_percent: 0.01
```

## Monitoring and Observability

### Metrics

Prometheus metrics are exposed at `http://localhost:9090/metrics`:

- `market_data_requests_total` - Total number of market data requests
- `market_data_request_duration_seconds` - Request duration histogram
- `market_data_cache_hits_total` - Cache hit count
- `market_data_cache_misses_total` - Cache miss count
- `market_data_websocket_connections` - Active WebSocket connections
- `market_data_errors_total` - Total error count

### Health Checks

- **Liveness**: `GET /health/live` - Returns 200 if service is running
- **Readiness**: `GET /health/ready` - Returns 200 if service is ready to accept traffic

### Logging

Structured JSON logging with the following fields:
- `timestamp`: ISO 8601 timestamp
- `level`: Log level (debug, info, warn, error)
- `message`: Log message
- `service`: Service name (`market-data-service`)
- `trace_id`: Distributed tracing ID (if available)
- `user_id`: User ID (if available)
- `error`: Error details (if applicable)

## Deployment

### Docker

```bash
# Build image
docker build -t hub-market-data-service:latest .

# Run container
docker run -d \
  --name market-data-service \
  -p 8080:8080 \
  -p 50051:50051 \
  -p 8082:8082 \
  --env-file .env \
  hub-market-data-service:latest
```

### Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f market-data-service

# Stop all services
docker-compose down
```

### Kubernetes

```bash
# Apply manifests
kubectl apply -f deployments/kubernetes/

# Check deployment status
kubectl get pods -l app=market-data-service

# View logs
kubectl logs -l app=market-data-service -f
```

## Performance

### Benchmarks

- **gRPC Latency**: p95 < 50ms, p99 < 100ms
- **HTTP REST Latency**: p95 < 100ms, p99 < 200ms
- **WebSocket Latency**: p95 < 25ms, p99 < 50ms
- **Cache Hit Rate**: >95%
- **Throughput**: 1000+ requests/second
- **Concurrent WebSocket Connections**: 10,000+

### Optimization

- **Caching**: Redis cache-aside pattern with 5-minute TTL
- **Connection Pooling**: PostgreSQL connection pool (max 25 connections)
- **Horizontal Scaling**: Stateless design allows easy horizontal scaling
- **Redis Pub/Sub**: For WebSocket scaling across multiple instances

## Security

- **Authentication**: JWT token validation via User Service
- **Authorization**: Role-based access control (RBAC) for admin endpoints
- **Network Isolation**: Service should not be publicly accessible (behind API Gateway)
- **Input Validation**: All inputs are validated and sanitized
- **Rate Limiting**: Configurable rate limits per user/IP
- **TLS**: Support for TLS/SSL encryption (production)

## Contributing

### Development Workflow

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make changes and commit: `git commit -am 'Add my feature'`
3. Push to the branch: `git push origin feature/my-feature`
4. Create a Pull Request

### Code Style

- Follow [Effective Go](https://golang.org/doc/effective_go.html) guidelines
- Use `gofmt` for formatting: `gofmt -w .`
- Use `golint` for linting: `golint ./...`
- Use `go vet` for static analysis: `go vet ./...`

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Test changes
- `chore:` Build/tooling changes

## Troubleshooting

### Common Issues

**Issue**: Service fails to start with "connection refused" error
**Solution**: Ensure PostgreSQL and Redis are running and accessible

**Issue**: WebSocket connections fail with "authentication failed"
**Solution**: Verify JWT token is valid and User Service is accessible

**Issue**: Cache hit rate is low (<90%)
**Solution**: Check Redis memory usage and TTL settings

**Issue**: High latency (>200ms p95)
**Solution**: Check database connection pool, Redis performance, and network latency

### Debug Mode

Enable debug logging:

```bash
export LOG_LEVEL=debug
go run cmd/server/main.go
```

## License

Copyright © 2024 HubInvestments. All rights reserved.

## Contact

- **Team**: HubInvestments Development Team
- **Email**: support@hubinvestments.com
- **Documentation**: [docs/](./docs/)
- **Issues**: [GitHub Issues](https://github.com/RodriguesYan/hub-market-data-service/issues)

