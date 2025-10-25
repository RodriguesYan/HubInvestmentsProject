#!/bin/bash

# Start script for hub-user-service

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting Hub User Service...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to service directory
cd "$SCRIPT_DIR/hub-user-service"

# Check if config.env exists
if [ ! -f "config.env" ]; then
    echo -e "${YELLOW}⚠️  config.env not found. Please run setup-services.sh first${NC}"
    exit 1
fi

# Load environment variables from config.env
set -a
source config.env
set +a

# Start the service
echo "Starting service on:"
echo "  HTTP: $HTTP_PORT"
echo "  gRPC: $GRPC_PORT"
echo ""

if [ -f "Makefile" ]; then
    make run
else
    go run cmd/server/main.go
fi

