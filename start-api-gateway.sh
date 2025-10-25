#!/bin/bash

# Start script for hub-api-gateway

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting Hub API Gateway...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to service directory
cd "$SCRIPT_DIR/hub-api-gateway"

# JWT Secret (must match hub-user-service)
export JWT_SECRET="HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^"

# Load .env file if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
    echo "✓ Loaded environment from .env"
fi

# Start the service
echo "Starting gateway on port 8080"
echo ""

if [ -f "Makefile" ]; then
    make run
else
    go run cmd/server/main.go
fi

