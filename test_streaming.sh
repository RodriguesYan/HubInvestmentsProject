#!/bin/bash

echo "🧪 Testing Market Data Streaming"
echo "================================"
echo ""

# Test 1: Direct gRPC streaming (30 seconds to ensure we catch updates)
echo "1️⃣  Testing direct gRPC streaming (30 seconds)..."
cd /Users/yanrodrigues/Documents/HubInvestmentsProject/hub-market-data-service
timeout 35s go run scripts/test_streaming_client/main.go \
  -server=localhost:50054 \
  -symbols=AAPL,GOOGL,MSFT,AMZN,TSLA \
  -duration=30s 2>&1 | tee /tmp/streaming_test.log

echo ""
echo "================================"
echo ""

# Check results
if grep -q "Total Quotes: 0" /tmp/streaming_test.log; then
  echo "❌ FAILED: No quotes received"
  echo ""
  echo "Checking service logs..."
  docker logs hub-market-data-service 2>&1 | tail -30
  exit 1
else
  echo "✅ SUCCESS: Quotes received!"
  grep "Total Quotes:" /tmp/streaming_test.log
  exit 0
fi



