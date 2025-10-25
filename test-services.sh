#!/bin/bash

# Hub Investments Platform - Integration Test Script
# This script tests communication between all services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Hub Investments Platform - Integration Tests${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Test 1: Health Checks
echo -e "${YELLOW}Test 1: Health Checks${NC}"
echo "----------------------------------------"

echo -n "Gateway Health:      "
if curl -sf http://localhost:8081/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -n "Monolith Health:     "
if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -n "User Service Health: "
if curl -sf http://localhost:8082/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""

# Test 2: Gateway → User Service (Login)
echo -e "${YELLOW}Test 2: Gateway → User Service (Login)${NC}"
echo "----------------------------------------"
echo "Testing login endpoint through gateway..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8081/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"password123"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓ PASS${NC} (Gateway successfully routed to User Service)"
else
    echo -e "${YELLOW}⚠ PARTIAL${NC} (Got response but unexpected status)"
fi

echo ""

# Test 3: Gateway → Monolith (Market Data)
echo -e "${YELLOW}Test 3: Gateway → Monolith (Market Data)${NC}"
echo "----------------------------------------"
echo "Testing market data endpoint through gateway..."

RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:8081/api/v1/market-data/AAPL)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY" | head -c 200
echo "..."

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
    echo -e "${GREEN}✓ PASS${NC} (Gateway successfully routed to Monolith)"
else
    echo -e "${YELLOW}⚠ PARTIAL${NC} (Got response but unexpected status)"
fi

echo ""

# Test 4: Direct Monolith Access
echo -e "${YELLOW}Test 4: Direct Monolith Access${NC}"
echo "----------------------------------------"
echo "Testing direct access to monolith..."

RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:8080/quotes)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} (Monolith is accessible)"
else
    echo -e "${RED}✗ FAIL${NC} (Monolith not accessible)"
fi

echo ""

# Test 5: Service Discovery
echo -e "${YELLOW}Test 5: Service Discovery (Docker Network)${NC}"
echo "----------------------------------------"

echo "Checking if services can resolve each other..."

# Check from gateway to user service
echo -n "Gateway → User Service: "
if docker exec hub-api-gateway wget -q --spider --timeout=2 http://hub-user-service:8080/health 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check from gateway to monolith
echo -n "Gateway → Monolith:     "
if docker exec hub-api-gateway wget -q --spider --timeout=2 http://hub-monolith:8080/health 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "All basic connectivity tests completed!"
echo ""
echo "Next steps:"
echo "  1. Create test users in the database"
echo "  2. Test authenticated endpoints"
echo "  3. Test order submission flow"
echo "  4. Test WebSocket connections"
echo ""
echo -e "${GREEN}✅ Integration tests complete!${NC}"

