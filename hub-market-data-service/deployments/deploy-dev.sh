#!/bin/bash

# Development Deployment Script
# Deploys the Market Data Service to development environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Market Data Service - Development Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$SCRIPT_DIR"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found, creating from .env.example...${NC}"
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        cp "$PROJECT_ROOT/.env.example" ".env"
        echo -e "${GREEN}✅ Created .env file${NC}"
    else
        echo -e "${RED}❌ .env.example not found${NC}"
        exit 1
    fi
fi

# Stop existing containers
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker-compose down || true

# Build images
echo ""
echo -e "${BLUE}🔨 Building Docker images...${NC}"
docker-compose build --no-cache

# Start services
echo ""
echo -e "${BLUE}🚀 Starting services...${NC}"
docker-compose up -d

# Wait for services to be healthy
echo ""
echo -e "${BLUE}⏳ Waiting for services to be healthy...${NC}"
sleep 5

# Check service health
echo ""
echo -e "${BLUE}🏥 Checking service health...${NC}"

# Check database
if docker-compose ps market-data-db | grep -q "healthy"; then
    echo -e "${GREEN}✅ Database is healthy${NC}"
else
    echo -e "${RED}❌ Database is not healthy${NC}"
    docker-compose logs market-data-db
    exit 1
fi

# Check Redis
if docker-compose ps market-data-redis | grep -q "healthy"; then
    echo -e "${GREEN}✅ Redis is healthy${NC}"
else
    echo -e "${RED}❌ Redis is not healthy${NC}"
    docker-compose logs market-data-redis
    exit 1
fi

# Check Market Data Service
sleep 10
if docker-compose ps market-data-service | grep -q "Up"; then
    echo -e "${GREEN}✅ Market Data Service is running${NC}"
else
    echo -e "${RED}❌ Market Data Service is not running${NC}"
    docker-compose logs market-data-service
    exit 1
fi

# Show service URLs
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Deployment successful!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Service URLs:"
echo "  📊 gRPC Server:    localhost:50054"
echo "  🌐 HTTP Server:    localhost:8083"
echo "  🗄️  PostgreSQL:     localhost:5433"
echo "  💾 Redis:          localhost:6380"
echo ""
echo "Useful commands:"
echo "  View logs:         docker-compose logs -f market-data-service"
echo "  Stop services:     docker-compose down"
echo "  Restart service:   docker-compose restart market-data-service"
echo "  View status:       docker-compose ps"
echo ""
echo "Test gRPC connection:"
echo "  grpcurl -plaintext localhost:50054 list"
echo ""

