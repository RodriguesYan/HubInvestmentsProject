#!/bin/bash

# ============================================================================
# Start Infrastructure Services (Redis & RabbitMQ)
# ============================================================================
# This script starts Redis and RabbitMQ for HubInvestments services
# ============================================================================

set -e

echo "🚀 Starting Infrastructure Services..."
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================================================
# Redis
# ============================================================================

echo "📦 Starting Redis..."

# Check if Redis is already running
if lsof -Pi :6379 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${YELLOW}⚠️  Redis is already running on port 6379${NC}"
else
    # Try to start Redis
    if command -v redis-server &> /dev/null; then
        # Start Redis as daemon
        redis-server --daemonize yes --port 6379 --bind 127.0.0.1 --protected-mode yes
        
        # Wait for Redis to start
        sleep 2
        
        # Verify Redis is running
        if redis-cli ping > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Redis started successfully on port 6379${NC}"
        else
            echo -e "${RED}❌ Redis failed to start${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Redis is not installed${NC}"
        echo "Install Redis:"
        echo "  macOS: brew install redis"
        echo "  Ubuntu: sudo apt install redis-server"
        exit 1
    fi
fi

echo ""

# ============================================================================
# RabbitMQ
# ============================================================================

echo "🐰 Starting RabbitMQ..."

# Check if RabbitMQ is already running
if lsof -Pi :5672 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${YELLOW}⚠️  RabbitMQ is already running on port 5672${NC}"
else
    # Try to start RabbitMQ
    if command -v rabbitmq-server &> /dev/null; then
        # Start RabbitMQ in detached mode
        rabbitmq-server -detached > /dev/null 2>&1
        
        # Wait for RabbitMQ to start (it takes longer than Redis)
        echo "   Waiting for RabbitMQ to initialize..."
        sleep 5
        
        # Verify RabbitMQ is running
        if lsof -Pi :5672 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
            echo -e "${GREEN}✅ RabbitMQ started successfully${NC}"
            echo "   AMQP Port: 5672"
            echo "   Management UI: http://localhost:15672"
            echo "   Default credentials: guest/guest"
        else
            echo -e "${RED}❌ RabbitMQ failed to start${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ RabbitMQ is not installed${NC}"
        echo "Install RabbitMQ:"
        echo "  macOS: brew install rabbitmq"
        echo "  Ubuntu: sudo apt install rabbitmq-server"
        exit 1
    fi
fi

echo ""
echo "======================================"
echo -e "${GREEN}✅ Infrastructure services are running!${NC}"
echo ""
echo "📊 Service Status:"
echo "  Redis:    localhost:6379"
echo "  RabbitMQ: localhost:5672"
echo "  RabbitMQ Management: http://localhost:15672"
echo ""
echo "To stop services:"
echo "  Redis:    redis-cli shutdown"
echo "  RabbitMQ: rabbitmqctl stop"
echo ""

