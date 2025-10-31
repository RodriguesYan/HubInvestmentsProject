#!/bin/bash

# Production Deployment Script
# Deploys the Market Data Service to production environment

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
echo "  Market Data Service - Production Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$SCRIPT_DIR"

# Check if .env.prod file exists
if [ ! -f ".env.prod" ]; then
    echo -e "${RED}❌ .env.prod file not found${NC}"
    echo ""
    echo "Please create .env.prod from .env.prod.example:"
    echo "  cp .env.prod.example .env.prod"
    echo "  # Edit .env.prod and set production values"
    echo ""
    exit 1
fi

# Validate required environment variables
echo -e "${BLUE}🔍 Validating environment variables...${NC}"
source .env.prod

REQUIRED_VARS=(
    "DB_PASSWORD"
    "REDIS_PASSWORD"
    "VERSION"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

echo -e "${GREEN}✅ Environment variables validated${NC}"

# Confirm deployment
echo ""
echo -e "${YELLOW}⚠️  You are about to deploy to PRODUCTION${NC}"
echo ""
echo "Version: ${VERSION}"
echo "Environment: ${ENVIRONMENT:-production}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Build production image
echo -e "${BLUE}🔨 Building production Docker image...${NC}"
cd "$PROJECT_ROOT"

BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

docker build \
    --build-arg VERSION="${VERSION}" \
    --build-arg BUILD_TIME="${BUILD_TIME}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    -t "${DOCKER_REGISTRY:-}hub-market-data-service:${VERSION}" \
    -t "${DOCKER_REGISTRY:-}hub-market-data-service:latest" \
    -f Dockerfile \
    .

echo -e "${GREEN}✅ Image built successfully${NC}"

# Push to registry (if registry is configured)
if [ -n "$DOCKER_REGISTRY" ]; then
    echo ""
    echo -e "${BLUE}📤 Pushing image to registry...${NC}"
    docker push "${DOCKER_REGISTRY}hub-market-data-service:${VERSION}"
    docker push "${DOCKER_REGISTRY}hub-market-data-service:latest"
    echo -e "${GREEN}✅ Image pushed to registry${NC}"
fi

# Deploy with docker-compose
echo ""
echo -e "${BLUE}🚀 Deploying to production...${NC}"
cd "$SCRIPT_DIR"

# Create backup of current state
echo -e "${BLUE}💾 Creating backup...${NC}"
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup database (if running)
if docker-compose -f docker-compose.prod.yml ps market-data-db | grep -q "Up"; then
    echo "  Backing up database..."
    docker-compose -f docker-compose.prod.yml exec -T market-data-db \
        pg_dump -U "${DB_USER}" "${DB_NAME}" > "$BACKUP_DIR/database.sql" || true
fi

echo -e "${GREEN}✅ Backup created${NC}"

# Pull latest images (if using registry)
if [ -n "$DOCKER_REGISTRY" ]; then
    echo ""
    echo -e "${BLUE}📥 Pulling latest images...${NC}"
    docker-compose -f docker-compose.prod.yml --env-file .env.prod pull
fi

# Deploy
echo ""
echo -e "${BLUE}🚀 Starting services...${NC}"
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d

# Wait for services to be healthy
echo ""
echo -e "${BLUE}⏳ Waiting for services to be healthy...${NC}"
sleep 10

MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose -f docker-compose.prod.yml ps market-data-service | grep -q "healthy\|Up"; then
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Service did not become healthy in time${NC}"
    echo ""
    echo "Logs:"
    docker-compose -f docker-compose.prod.yml logs --tail=50 market-data-service
    exit 1
fi

# Verify deployment
echo ""
echo -e "${BLUE}🏥 Verifying deployment...${NC}"

# Check gRPC endpoint
if nc -z localhost ${GRPC_PORT:-50054} 2>/dev/null; then
    echo -e "${GREEN}✅ gRPC endpoint is accessible${NC}"
else
    echo -e "${RED}❌ gRPC endpoint is not accessible${NC}"
    exit 1
fi

# Show deployment summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Production deployment successful!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Deployment Details:"
echo "  Version:           ${VERSION}"
echo "  Build Time:        ${BUILD_TIME}"
echo "  Git Commit:        ${GIT_COMMIT}"
echo "  Environment:       ${ENVIRONMENT:-production}"
echo ""
echo "Service URLs:"
echo "  📊 gRPC Server:    localhost:${GRPC_PORT:-50054}"
echo "  🌐 HTTP Server:    localhost:${SERVER_PORT:-8083}"
echo "  📈 Metrics:        localhost:${METRICS_PORT:-9090}"
echo ""
echo "Monitoring:"
echo "  View logs:         docker-compose -f docker-compose.prod.yml logs -f market-data-service"
echo "  View status:       docker-compose -f docker-compose.prod.yml ps"
echo "  View metrics:      curl http://localhost:${METRICS_PORT:-9090}/metrics"
echo ""
echo "Rollback (if needed):"
echo "  Restore backup:    psql -U ${DB_USER} ${DB_NAME} < $BACKUP_DIR/database.sql"
echo "  Redeploy previous: VERSION=<previous-version> ./deploy-prod.sh"
echo ""

