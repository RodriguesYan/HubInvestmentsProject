#!/bin/bash

# Start All Services for Step 4.6.6 Testing
# This script starts the monolith, user service, and API gateway

set -e

echo "=========================================="
echo "Starting All Services for Step 4.6.6"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if port is in use
check_port() {
    if lsof -i :$1 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port $1 is already in use${NC}"
        return 1
    fi
    return 0
}

# Function to wait for service to start
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    echo "Waiting for $service_name to start on port $port..."
    while [ $attempt -lt $max_attempts ]; do
        if lsof -i :$port > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is running on port $port${NC}"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ $service_name failed to start on port $port${NC}"
    return 1
}

# Stop any existing services
echo "Stopping any existing services..."
pkill -f "bin/server" 2>/dev/null || true
pkill -f "bin/gateway" 2>/dev/null || true
pkill -f "bin/hub-user-service" 2>/dev/null || true
sleep 2

echo ""
echo "=========================================="
echo "1. Starting HubInvestments Monolith"
echo "=========================================="

cd /Users/yanrodrigues/Documents/HubInvestmentsProject/HubInvestmentsServer

if [ ! -f "bin/server" ]; then
    echo "Building monolith..."
    go build -o bin/server .
fi

echo "Starting monolith..."
./bin/server > /tmp/monolith.log 2>&1 &
MONOLITH_PID=$!

if wait_for_service 50060 "Monolith gRPC"; then
    echo -e "${GREEN}✅ Monolith started successfully (PID: $MONOLITH_PID)${NC}"
    echo "   - HTTP: localhost:8080"
    echo "   - gRPC: localhost:50060"
    echo "   - Logs: /tmp/monolith.log"
else
    echo -e "${RED}❌ Failed to start monolith${NC}"
    cat /tmp/monolith.log
    exit 1
fi

echo ""
echo "=========================================="
echo "2. Starting Hub User Service"
echo "=========================================="

cd /Users/yanrodrigues/Documents/HubInvestmentsProject/hub-user-service

if [ ! -f "bin/hub-user-service" ]; then
    echo "Building user service..."
    go build -o bin/hub-user-service ./cmd/server
fi

echo "Starting user service..."
echo -e "${YELLOW}⚠️  Note: User service requires PostgreSQL database${NC}"
echo -e "${YELLOW}⚠️  If database is not available, service will fail${NC}"
echo -e "${YELLOW}⚠️  This is OK for Step 4.6.6 testing (not required)${NC}"

./bin/hub-user-service > /tmp/user-service.log 2>&1 &
USER_SERVICE_PID=$!

sleep 3

if lsof -i :50051 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ User Service started successfully (PID: $USER_SERVICE_PID)${NC}"
    echo "   - HTTP: localhost:8080"
    echo "   - gRPC: localhost:50051"
    echo "   - Logs: /tmp/user-service.log"
else
    echo -e "${YELLOW}⚠️  User Service failed to start (database issue)${NC}"
    echo -e "${YELLOW}⚠️  This is OK - not required for Step 4.6.6 testing${NC}"
    tail -5 /tmp/user-service.log
fi

echo ""
echo "=========================================="
echo "3. Starting API Gateway"
echo "=========================================="

cd /Users/yanrodrigues/Documents/HubInvestmentsProject/hub-api-gateway

if [ ! -f "bin/gateway" ]; then
    echo "Building gateway..."
    go build -o bin/gateway ./cmd/server
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found, creating it...${NC}"
    cat > .env << 'EOF'
JWT_SECRET=HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^
HTTP_PORT=8080
USER_SERVICE_ADDRESS=localhost:50051
HUB_MONOLITH_ADDRESS=localhost:50060
EOF
fi

echo "Starting gateway..."
# Load environment variables from .env file
export $(cat .env | grep -v '^#' | xargs)

./bin/gateway > /tmp/gateway.log 2>&1 &
GATEWAY_PID=$!

if wait_for_service 8080 "API Gateway"; then
    echo -e "${GREEN}✅ API Gateway started successfully (PID: $GATEWAY_PID)${NC}"
    echo "   - HTTP: localhost:8080"
    echo "   - Logs: /tmp/gateway.log"
else
    echo -e "${RED}❌ Failed to start gateway${NC}"
    cat /tmp/gateway.log
    exit 1
fi

echo ""
echo "=========================================="
echo "All Services Started!"
echo "=========================================="
echo ""
echo "Running Services:"
echo "  1. Monolith:"
echo "     - HTTP: http://localhost:8080 (monolith direct)"
echo "     - gRPC: localhost:50060"
echo "     - PID: $MONOLITH_PID"
echo ""
echo "  2. User Service:"
if lsof -i :50051 > /dev/null 2>&1; then
    echo "     - gRPC: localhost:50051"
    echo "     - PID: $USER_SERVICE_PID"
else
    echo "     - Status: Not running (database issue)"
fi
echo ""
echo "  3. API Gateway:"
echo "     - HTTP: http://localhost:8080 (gateway)"
echo "     - PID: $GATEWAY_PID"
echo ""
echo "Logs:"
echo "  - Monolith: /tmp/monolith.log"
echo "  - User Service: /tmp/user-service.log"
echo "  - Gateway: /tmp/gateway.log"
echo ""
echo "Test Commands:"
echo "  # Health check"
echo "  curl http://localhost:8080/health"
echo ""
echo "  # Market data (via gateway → monolith)"
echo "  curl http://localhost:8080/api/v1/market-data/AAPL"
echo ""
echo "  # Run all tests"
echo "  cd /Users/yanrodrigues/Documents/HubInvestmentsProject/HubInvestmentsServer"
echo "  ./test_step_4_6_6_complete.sh"
echo ""
echo "To stop all services:"
echo "  pkill -f 'bin/server|bin/gateway|bin/hub-user-service'"
echo ""
echo "🎉 Ready for Step 4.6.6 testing!"

