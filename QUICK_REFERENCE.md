# HubInvestments Quick Reference Guide

## 📊 Architecture Diagram

See [architecture-diagram.png](./architecture-diagram.png) for the complete system architecture visualization.

Full documentation: [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## 🚀 Quick Start

### 1. Start Infrastructure
```bash
./start-infrastructure.sh
```

### 2. Start Services
```bash
# Terminal 1: User Service
cd hub-user-service && ./bin/user-service

# Terminal 2: API Gateway  
cd hub-api-gateway
export JWT_SECRET='HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^'
export CONFIG_PATH='config/config.yaml'
./bin/gateway

# Terminal 3: Monolith
cd HubInvestmentsServer && go run main.go
```

---

## 🔌 Service Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| **API Gateway** | 8080 | HTTP | Client entry point |
| **User Service** | 50051 | gRPC | Authentication |
| **Monolith** | 50060 | gRPC | Business logic |
| **PostgreSQL** | 5432 | TCP | Database |
| **Redis** | 6379 | TCP | Cache & keys |
| **RabbitMQ** | 5672 | AMQP | Message queue |
| **RabbitMQ Management** | 15672 | HTTP | Admin UI |

---

## 📡 API Endpoints

### Authentication
```bash
# Login
POST /api/v1/auth/login
{
  "email": "user@example.com",
  "password": "password123"
}

# Validate Token
POST /api/v1/auth/validate
{
  "token": "eyJhbGc..."
}
```

### Balance
```bash
# Get Balance (requires auth)
GET /api/v1/balance
Authorization: Bearer <token>
```

### Orders
```bash
# Submit Order (requires auth)
POST /api/v1/orders
{
  "symbol": "AAPL",
  "order_type": "MARKET",
  "order_side": "BUY",
  "quantity": 10
}

# Get Order Details
GET /api/v1/orders/{id}

# Get Order Status
GET /api/v1/orders/{id}/status

# Cancel Order
PUT /api/v1/orders/{id}/cancel

# Order History
GET /api/v1/orders/history
```

### Positions
```bash
# Get Positions
GET /api/v1/positions

# Get Position Details
GET /api/v1/positions/{id}

# Close Position
PUT /api/v1/positions/{id}/close
```

### Market Data
```bash
# Get Market Data (public)
GET /api/v1/market-data/{symbol}

# Get Asset Details (public)
GET /api/v1/market-data/{symbol}/details

# Batch Market Data (public)
POST /api/v1/market-data/batch
{
  "symbols": ["AAPL", "GOOGL", "MSFT"]
}
```

### Portfolio
```bash
# Get Portfolio Summary (requires auth)
GET /api/v1/portfolio/summary
```

---

## 🔐 Authentication

### Get Token
```bash
TOKEN=$(curl -X POST "http://localhost:8080/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"bla@bla.com","password":"12345678"}' \
  | jq -r '.token')
```

### Use Token
```bash
curl -X GET "http://localhost:8080/api/v1/balance" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🗄️ Database

### Connection
```bash
psql -U yanrodrigues -d hubinvestments
```

### Useful Queries
```sql
-- List users
SELECT id, email, name FROM users;

-- Check balance
SELECT * FROM balance WHERE user_id = '2';

-- Recent orders
SELECT * FROM orders ORDER BY created_at DESC LIMIT 10;

-- Active positions
SELECT * FROM positions WHERE status = 'ACTIVE';
```

---

## 📦 Redis

### Connect
```bash
redis-cli
```

### Useful Commands
```bash
# Check token cache
KEYS token_valid:*

# Check market data cache
KEYS market_data:*

# Check idempotency keys
KEYS idempotency:*

# Get cache stats
INFO stats
```

---

## 🐰 RabbitMQ

### Management UI
```
http://localhost:15672
Username: guest
Password: guest
```

### CLI Commands
```bash
# List queues
rabbitmqctl list_queues

# List exchanges
rabbitmqctl list_exchanges

# Purge queue
rabbitmqctl purge_queue orders.submit
```

---

## 🔧 Troubleshooting

### Check Services
```bash
# API Gateway
lsof -i :8080

# User Service
lsof -i :50051

# Monolith
lsof -i :50060

# Redis
redis-cli ping

# RabbitMQ
rabbitmqctl status

# PostgreSQL
psql -U yanrodrigues -d hubinvestments -c "SELECT 1"
```

### View Logs
```bash
# API Gateway
tail -f hub-api-gateway/gateway.log

# User Service
tail -f hub-user-service/user-service.log

# Monolith
tail -f HubInvestmentsServer/monolith.log
```

### Common Issues

#### Token Expired
```bash
# Get a fresh token
TOKEN=$(curl -X POST "http://localhost:8080/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"bla@bla.com","password":"12345678"}' \
  | jq -r '.token')
```

#### Redis Connection Error
```bash
# Start Redis
./start-infrastructure.sh
```

#### Service Not Running
```bash
# Check process
ps aux | grep <service-name>

# Restart service
cd <service-directory>
<start-command>
```

---

## 🧪 Testing

### Run Tests
```bash
# User Service tests
cd hub-user-service
go test ./... -v

# Specific test
go test ./internal/grpc/... -v
```

### Test Endpoints
```bash
# Health check
curl http://localhost:8080/health

# Metrics
curl http://localhost:8080/metrics
```

---

## 📈 Monitoring

### Prometheus Metrics
```
http://localhost:8080/metrics
```

### Key Metrics
- `hub_gateway_requests_total`: Total requests
- `hub_gateway_request_duration_seconds`: Request latency
- `hub_gateway_cache_hits_total`: Cache hits
- `hub_gateway_cache_misses_total`: Cache misses
- `hub_gateway_circuit_breaker_trips_total`: Circuit breaker trips

---

## 🛑 Stop Services

### Stop Infrastructure
```bash
# Redis
redis-cli shutdown

# RabbitMQ
rabbitmqctl stop
```

### Stop Application Services
```bash
# Find and kill processes
lsof -ti :8080 | xargs kill
lsof -ti :50051 | xargs kill
lsof -ti :50060 | xargs kill
```

### Stop All
```bash
./stop-all-services.sh
```

---

## 📚 Documentation

- [Architecture Overview](./ARCHITECTURE.md)
- [Architecture Diagram](./architecture-diagram.png)
- [Fixes Complete](./FIXES_COMPLETE.md)
- [All Services Running](./ALL_SERVICES_RUNNING.md)
- [Running Services Guide](./RUNNING_SERVICES_GUIDE.md)

---

## 🔗 Useful Links

- **API Gateway**: http://localhost:8080
- **RabbitMQ Management**: http://localhost:15672
- **Health Check**: http://localhost:8080/health
- **Metrics**: http://localhost:8080/metrics

---

**Last Updated**: October 21, 2025  
**Version**: 1.0.0

