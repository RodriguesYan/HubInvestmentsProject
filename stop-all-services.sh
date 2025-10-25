#!/bin/bash

# Stop all Hub services
# This script kills any Go processes running on ports 8080 and 50051

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping all Hub services...${NC}"
echo ""

# Function to kill process on a port (only Go processes)
kill_port() {
    local port=$1
    local service_name=$2
    
    if lsof -ti:$port > /dev/null 2>&1; then
        echo -e "${YELLOW}Found service on port $port ($service_name)${NC}"
        local pids=$(lsof -ti:$port)
        for pid in $pids; do
            # Check if it's a Go process (avoid killing Postman, browsers, etc.)
            local process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "")
            if [[ "$process_name" == *"server"* ]] || [[ "$process_name" == *"main"* ]] || [[ "$process_name" == *"gateway"* ]] || [[ "$process_name" == *"user-service"* ]] || [[ "$process_name" == *"HubInvest"* ]]; then
                echo -e "  Killing process $pid ($process_name)..."
                kill -9 $pid 2>/dev/null || true
            else
                echo -e "  ${BLUE}Skipping process $pid ($process_name) - not a Hub service${NC}"
            fi
        done
        echo -e "${GREEN}  ✅ Stopped $service_name${NC}"
    else
        echo -e "${GREEN}✅ Port $port is free ($service_name not running)${NC}"
    fi
}

# Kill common Go server processes
echo "Checking for Go server processes..."
if pgrep -f "go run cmd/server/main.go" > /dev/null 2>&1; then
    echo -e "${YELLOW}Found Go server processes${NC}"
    pkill -9 -f "go run cmd/server/main.go" || true
    echo -e "${GREEN}  ✅ Stopped Go server processes${NC}"
fi

if pgrep -f "go run main.go" > /dev/null 2>&1; then
    echo -e "${YELLOW}Found Go main processes${NC}"
    pkill -9 -f "go run main.go" || true
    echo -e "${GREEN}  ✅ Stopped Go main processes${NC}"
fi

# Kill processes on specific ports
echo ""
echo "Checking ports..."
kill_port 3000 "API Gateway"
kill_port 8080 "HTTP Server (Monolith)"
kill_port 50051 "gRPC Server (hub-user-service)"
kill_port 50060 "gRPC Server (HubInvestmentsServer)"

# Check for any remaining Go build processes
echo ""
echo "Checking for orphaned Go build processes..."
if ps aux | grep -E "go-build.*main" | grep -v grep > /dev/null 2>&1; then
    echo -e "${YELLOW}Found orphaned Go build processes${NC}"
    ps aux | grep -E "go-build.*main" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    echo -e "${GREEN}  ✅ Cleaned up orphaned processes${NC}"
else
    echo -e "${GREEN}✅ No orphaned processes found${NC}"
fi

echo ""
echo -e "${GREEN}✅ All services stopped!${NC}"
echo ""
echo "Verify ports are free:"
echo "  lsof -ti:8080  # Should be empty"
echo "  lsof -ti:50051 # Should be empty"
echo ""

