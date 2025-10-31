#!/bin/bash

# Test Script for gRPC Streaming Integration Tests
# This script runs comprehensive streaming tests for the Market Data Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "============================================"
echo "Market Data Service - Streaming Tests"
echo "============================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if service is running
echo "Checking if Market Data Service is running..."
if ! nc -z localhost 50054 2>/dev/null; then
    echo -e "${RED}❌ Market Data Service is not running on port 50054${NC}"
    echo ""
    echo "Please start the service first:"
    echo "  cd hub-market-data-service"
    echo "  make run"
    echo ""
    exit 1
fi
echo -e "${GREEN}✅ Service is running${NC}"
echo ""

# Run integration tests
echo "============================================"
echo "Running Streaming Integration Tests"
echo "============================================"
echo ""

echo "Test Suite 1: Basic Streaming Lifecycle"
echo "----------------------------------------"
go test -v -run TestStreamQuotesIntegration ./internal/presentation/grpc/

echo ""
echo "Test Suite 2: Reconnection Scenarios"
echo "----------------------------------------"
go test -v -run TestStreamQuotesReconnection ./internal/presentation/grpc/

echo ""
echo "Test Suite 3: Concurrency (10 concurrent clients)"
echo "----------------------------------------"
go test -v -run TestStreamQuotesConcurrency ./internal/presentation/grpc/

echo ""
echo "Test Suite 4: Scaling (20 symbols)"
echo "----------------------------------------"
go test -v -run TestStreamQuotesScaling ./internal/presentation/grpc/

echo ""
echo "Test Suite 5: Data Validation"
echo "----------------------------------------"
go test -v -run TestStreamQuotesDataValidation ./internal/presentation/grpc/

echo ""
echo "============================================"
echo "Running All Streaming Tests Together"
echo "============================================"
echo ""
go test -v -run "TestStreamQuotes.*" ./internal/presentation/grpc/

echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
echo ""

# Run tests and capture results
if go test -run "TestStreamQuotes.*" ./internal/presentation/grpc/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ All streaming tests passed!${NC}"
    echo ""
    echo "Tested scenarios:"
    echo "  ✓ Subscribe and receive quotes"
    echo "  ✓ Multiple subscriptions"
    echo "  ✓ Unsubscribe from symbols"
    echo "  ✓ Heartbeat mechanism (30s interval)"
    echo "  ✓ Graceful reconnection"
    echo "  ✓ Context cancellation"
    echo "  ✓ 10 concurrent clients"
    echo "  ✓ 20 symbols scaling"
    echo "  ✓ Data structure validation"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Run with verbose output:"
    echo "  go test -v -run TestStreamQuotes ./internal/presentation/grpc/"
    echo ""
    exit 1
fi


