#!/bin/bash

# Standalone Streaming Test Runners
# This script provides easy commands to run streaming client tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo "Usage: $0 [client|load|both]"
    echo ""
    echo "Commands:"
    echo "  client  - Run single streaming client test"
    echo "  load    - Run load test with multiple concurrent clients"
    echo "  both    - Run both tests sequentially"
    echo ""
    echo "Options:"
    echo "  --server <address>  - gRPC server address (default: localhost:50054)"
    echo "  --symbols <list>    - Comma-separated symbols (default: AAPL,GOOGL,MSFT)"
    echo "  --duration <time>   - Test duration (default: 30s)"
    echo "  --clients <number>  - Number of concurrent clients for load test (default: 100)"
    echo ""
    echo "Examples:"
    echo "  $0 client"
    echo "  $0 client --symbols AAPL,TSLA,NVDA --duration 60s"
    echo "  $0 load --clients 200 --duration 2m"
    echo "  $0 both"
}

check_service() {
    echo -e "${BLUE}Checking if Market Data Service is running...${NC}"
    if ! nc -z localhost 50054 2>/dev/null; then
        echo -e "${RED}❌ Market Data Service is not running on port 50054${NC}"
        echo ""
        echo "Please start the service first:"
        echo "  cd $PROJECT_ROOT"
        echo "  make run"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✅ Service is running${NC}"
    echo ""
}

run_client_test() {
    echo "============================================"
    echo "Running Streaming Client Test"
    echo "============================================"
    echo ""
    
    cd "$SCRIPT_DIR/test_streaming_client"
    go run main.go "$@"
}

run_load_test() {
    echo "============================================"
    echo "Running Load Test"
    echo "============================================"
    echo ""
    
    cd "$SCRIPT_DIR/test_streaming_load"
    go run main.go "$@"
}

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

check_service

case "$1" in
    client)
        shift
        run_client_test "$@"
        ;;
    load)
        shift
        run_load_test "$@"
        ;;
    both)
        shift
        echo -e "${YELLOW}Running both tests...${NC}"
        echo ""
        run_client_test "$@"
        echo ""
        echo ""
        run_load_test "$@"
        ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Test completed successfully!${NC}"


