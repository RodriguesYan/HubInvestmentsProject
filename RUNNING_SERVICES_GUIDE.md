# Hub Investments - Running Services Guide

## 🎯 Quick Start (TL;DR)

```bash
# Terminal 1: Start User Service
cd hub-user-service && go run cmd/server/main.go

# Terminal 2: Start Monolith
cd HubInvestmentsServer && go run main.go

# Terminal 3: Start API Gateway
cd hub-api-gateway && go run cmd/server/main.go

# Terminal 4: Test everything
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Client                               │
│                    (Web, Mobile, CLI)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTP REST
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway                             │
│                    localhost:8080                            │
│                                                               │
│  - Authentication routing                                    │
│  - Token validation & caching                                │
│  - Request routing to services                               │
│  - Circuit breakers & metrics                                │
└─────────────────────────────────────────────────────────────┘
                ↓ gRPC                    ↓ gRPC
┌─────────────────────────────┐ ┌─────────────────────────────┐
│      User Service           │ │        Monolith             │
│    localhost:50051          │ │    localhost:50060          │
│                             │ │                             │
│  - User authentication      │ │  - Portfolio management     │
│  - JWT token generation     │ │  - Order management         │
│  - Token validation         │ │  - Position tracking        │
│  - User management          │ │  - Balance management       │
│                             │ │  - Market data              │
└─────────────────────────────┘ └─────────────────────────────┘
                ↓                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                       │
│                      localhost:5432                          │
│                                                               │
│  - hub_user_service (User Service DB)                       │
│  - hub_investments (Monolith DB)                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Starting Services

### Prerequisites
```bash
# Install dependencies
brew install go postgresql redis protobuf

# Install Go proto plugins
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Verify installations
go version        # Should be 1.21+
psql --version    # Should be 15+
redis-cli --version
protoc --version
```

### 1. Start Database & Redis

#### Option A: Using Docker (Recommended)
```bash
# Start PostgreSQL
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=hub_investments \
  -p 5432:5432 \
  postgres:15

# Start Redis
docker run -d \
  --name redis \
  -p 6379:6379 \
  redis:7-alpine

# Verify
docker ps
```

#### Option B: Using Local Installation
```bash
# Start PostgreSQL (macOS)
brew services start postgresql@15

# Start Redis (macOS)
brew services start redis

# Verify
psql -h localhost -U postgres -d hub_investments
redis-cli ping  # Should return PONG
```

### 2. Start User Service (Port 50051)

```bash
cd /Users/yanrodrigues/Documents/HubInvestmentsProject/hub-user-service

# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=hub_user_service
export DB_USER=postgres
export DB_PASSWORD=postgres
export MY_JWT_SECRET=your-secret-key-here
export GRPC_PORT=localhost:50051

# Create database (first time only)
make setup-db

# Run migrations (first time only)
make migrate-up

# Start service
go run cmd/server/main.go
```

**Expected Output:**
```
2025/10/20 10:00:00 ✅ Database connection established
2025/10/20 10:00:00 ✅ User Service gRPC server started on :50051
```

### 3. Start Monolith (Port 50060 gRPC, 8081 HTTP)

```bash
cd /Users/yanrodrigues/Documents/HubInvestmentsProject/HubInvestmentsServer

# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=hub_investments
export DB_USER=postgres
export DB_PASSWORD=postgres
export MY_JWT_SECRET=your-secret-key-here
export GRPC_PORT=localhost:50060
export HTTP_PORT=8081

# Run migrations (first time only)
make migrate

# Start monolith
go run main.go
```

**Expected Output:**
```
2025/10/20 10:00:05 ✅ Database connection established
2025/10/20 10:00:05 ✅ Redis connection established
2025/10/20 10:00:05 ✅ RabbitMQ connection established
2025/10/20 10:00:05 ✅ HTTP Server started on :8081
2025/10/20 10:00:05 ✅ gRPC Server started on :50060
```

### 4. Start API Gateway (Port 8080)

```bash
cd /Users/yanrodrigues/Documents/HubInvestmentsProject/hub-api-gateway

# Set environment variables
export SERVER_PORT=8080
export USER_SERVICE_ADDRESS=localhost:50051
export HUB_MONOLITH_ADDRESS=localhost:50060
export REDIS_HOST=localhost
export REDIS_PORT=6379
export JWT_SECRET=your-secret-key-here

# Start gateway
go run cmd/server/main.go
```

**Expected Output:**
```
2025/10/20 10:00:10 ✅ Configuration loaded
2025/10/20 10:00:10 ✅ Connected to User Service (localhost:50051)
2025/10/20 10:00:10 ✅ Connected to Hub Monolith (localhost:50060)
2025/10/20 10:00:10 ✅ Redis cache enabled
2025/10/20 10:00:10 ✅ API Gateway started on :8080
2025/10/20 10:00:10 📋 Loaded 13 routes
```

---

## 🧪 Testing the Setup

### Test 1: Health Checks
```bash
# API Gateway health
curl http://localhost:8080/health
# Expected: {"status":"healthy"}

# User Service health (via grpcurl)
grpcurl -plaintext localhost:50051 list
# Expected: List of services

# Monolith health
curl http://localhost:8081/health
# Expected: {"status":"healthy"}
```

### Test 2: Authentication Flow
```bash
# Login to get JWT token
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# Expected response:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 600,
  "userId": "user-uuid",
  "email": "test@example.com"
}
```

### Test 3: Protected Endpoints
```bash
# Save token from previous step
TOKEN="your-jwt-token-here"

# Get portfolio summary
curl -X GET http://localhost:8080/api/v1/portfolio/summary \
  -H "Authorization: Bearer $TOKEN"

# Get balance
curl -X GET http://localhost:8080/api/v1/balance \
  -H "Authorization: Bearer $TOKEN"

# Get positions
curl -X GET http://localhost:8080/api/v1/positions \
  -H "Authorization: Bearer $TOKEN"
```

### Test 4: Public Endpoints
```bash
# Get market data (no auth required)
curl http://localhost:8080/api/v1/market-data/AAPL
```

---

## 🐛 Troubleshooting

### Service Won't Start

#### Check Port Availability
```bash
# Check if ports are in use
lsof -i :8080   # API Gateway
lsof -i :50051  # User Service
lsof -i :50060  # Monolith gRPC
lsof -i :8081   # Monolith HTTP

# Kill process if needed
kill -9 <PID>
```

#### Check Database Connection
```bash
# Test PostgreSQL connection
psql -h localhost -U postgres -d hub_investments

# If connection fails, check if PostgreSQL is running
docker ps | grep postgres
# or
brew services list | grep postgresql
```

#### Check Environment Variables
```bash
# Print all environment variables
env | grep -E "DB_|JWT_|GRPC_|SERVER_"

# Verify JWT secret is set
echo $MY_JWT_SECRET
```

### Authentication Errors (401)

#### JWT Secret Mismatch
```bash
# All services MUST use the same JWT secret
# Check each service's config

# User Service
cd hub-user-service && grep JWT_SECRET config.env

# Monolith
cd HubInvestmentsServer && grep JWT_SECRET config.env

# API Gateway
cd hub-api-gateway && grep JWT_SECRET config/config.yaml
```

#### Token Expired
```bash
# Tokens expire after 10 minutes
# Get a new token by logging in again
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### gRPC Connection Errors

#### Service Not Reachable
```bash
# Test gRPC connectivity
grpcurl -plaintext localhost:50051 list  # User Service
grpcurl -plaintext localhost:50060 list  # Monolith

# If fails, check if service is running
ps aux | grep "go run"
```

#### Proto Files Out of Sync
```bash
# Sync proto files from source services
cd hub-api-gateway
./scripts/sync_proto_files.sh

# Rebuild gateway
go build ./...
```

### Database Errors

#### Migration Not Applied
```bash
# Check migration status
cd hub-user-service
make migrate-status

cd HubInvestmentsServer
make migrate-status

# Apply migrations
make migrate-up
```

#### Connection Pool Exhausted
```bash
# Check active connections
psql -h localhost -U postgres -d hub_investments \
  -c "SELECT count(*) FROM pg_stat_activity;"

# Restart services to reset connection pool
```

---

## 📝 Environment Variables Reference

### User Service
| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | hub_user_service | Database name |
| `DB_USER` | postgres | Database user |
| `DB_PASSWORD` | postgres | Database password |
| `MY_JWT_SECRET` | (required) | JWT signing secret |
| `GRPC_PORT` | localhost:50051 | gRPC server port |

### Monolith
| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | hub_investments | Database name |
| `DB_USER` | postgres | Database user |
| `DB_PASSWORD` | postgres | Database password |
| `MY_JWT_SECRET` | (required) | JWT signing secret |
| `GRPC_PORT` | localhost:50060 | gRPC server port |
| `HTTP_PORT` | 8081 | HTTP server port |
| `REDIS_HOST` | localhost | Redis host |
| `REDIS_PORT` | 6379 | Redis port |

### API Gateway
| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | 8080 | HTTP server port |
| `USER_SERVICE_ADDRESS` | localhost:50051 | User Service gRPC address |
| `HUB_MONOLITH_ADDRESS` | localhost:50060 | Monolith gRPC address |
| `REDIS_HOST` | localhost | Redis host |
| `REDIS_PORT` | 6379 | Redis port |
| `JWT_SECRET` | (required) | JWT validation secret |

---

## 🔧 Development Tips

### Use tmux for Multiple Terminals
```bash
# Install tmux
brew install tmux

# Create session with 4 panes
tmux new-session \; \
  split-window -h \; \
  split-window -v \; \
  select-pane -t 0 \; \
  split-window -v

# Pane 1: User Service
# Pane 2: Monolith
# Pane 3: API Gateway
# Pane 4: Testing
```

### Use Environment Files
```bash
# Create .env file in each service
cat > hub-user-service/.env <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hub_user_service
DB_USER=postgres
DB_PASSWORD=postgres
MY_JWT_SECRET=your-secret-key-here
GRPC_PORT=localhost:50051
EOF

# Load environment variables
source .env
go run cmd/server/main.go
```

### Use Make Commands
```bash
# User Service
cd hub-user-service
make run          # Start service
make test         # Run tests
make migrate-up   # Apply migrations

# Monolith
cd HubInvestmentsServer
make run          # Start service
make test         # Run tests
make migrate      # Apply migrations

# API Gateway
cd hub-api-gateway
make run          # Start gateway
make test         # Run tests
make sync-proto   # Sync proto files
```

---

## 📚 Additional Resources

- **API Gateway Quick Start**: `hub-api-gateway/QUICKSTART_GUIDE.md`
- **Contract Management**: `hub-api-gateway/docs/CONTRACT_MANAGEMENT.md`
- **User Service README**: `hub-user-service/README.md`
- **Monolith README**: `HubInvestmentsServer/README.md`

---

## ✅ Checklist for First-Time Setup

- [ ] Install Go 1.21+
- [ ] Install PostgreSQL 15+
- [ ] Install Redis
- [ ] Install Protocol Buffers compiler
- [ ] Install Go proto plugins
- [ ] Start PostgreSQL and Redis
- [ ] Create databases (hub_user_service, hub_investments)
- [ ] Run migrations for User Service
- [ ] Run migrations for Monolith
- [ ] Set JWT_SECRET environment variable (same for all services)
- [ ] Start User Service (verify port 50051)
- [ ] Start Monolith (verify ports 50060, 8081)
- [ ] Start API Gateway (verify port 8080)
- [ ] Test login endpoint
- [ ] Test protected endpoints
- [ ] Celebrate! 🎉

---

**Need help?** Check the troubleshooting section or review service-specific documentation.

