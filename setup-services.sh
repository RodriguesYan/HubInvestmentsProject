#!/bin/bash

# Setup script for Hub Services
# This script helps configure hub-api-gateway and hub-user-service

set -e

echo "🚀 Hub Services Setup Script"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# JWT Secret (must match across services)
JWT_SECRET="HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^"

echo "Step 1: Checking PostgreSQL setup..."
echo "-------------------------------------"

# Check if PostgreSQL is running
if ! command -v psql &> /dev/null; then
    echo -e "${RED}❌ PostgreSQL is not installed or not in PATH${NC}"
    echo "Please install PostgreSQL first"
    exit 1
fi

# Get current user
CURRENT_USER=$(whoami)
echo -e "${GREEN}✓${NC} Current user: $CURRENT_USER"

# Check if postgres role exists
if psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q 1; then
    echo -e "${GREEN}✓${NC} PostgreSQL role 'postgres' exists"
    DB_USER="postgres"
    DB_PASSWORD="postgres"
else
    echo -e "${YELLOW}⚠${NC}  PostgreSQL role 'postgres' does not exist"
    echo "Would you like to:"
    echo "  1) Create 'postgres' role with password 'postgres'"
    echo "  2) Use current user '$CURRENT_USER' (no password)"
    read -p "Enter choice (1 or 2): " choice
    
    if [ "$choice" = "1" ]; then
        echo "Creating postgres role..."
        psql postgres -c "CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;" || true
        DB_USER="postgres"
        DB_PASSWORD="postgres"
        echo -e "${GREEN}✓${NC} Created postgres role"
    else
        DB_USER="$CURRENT_USER"
        DB_PASSWORD=""
        echo -e "${GREEN}✓${NC} Will use user: $DB_USER"
    fi
fi

# Check if database exists
if psql -lqt | cut -d \| -f 1 | grep -qw hub_investments; then
    echo -e "${GREEN}✓${NC} Database 'hub_investments' exists"
else
    echo -e "${YELLOW}⚠${NC}  Database 'hub_investments' does not exist"
    read -p "Create database 'hub_investments'? (y/n): " create_db
    if [ "$create_db" = "y" ]; then
        createdb hub_investments
        echo -e "${GREEN}✓${NC} Created database 'hub_investments'"
    else
        echo -e "${RED}❌ Database is required. Exiting.${NC}"
        exit 1
    fi
fi

echo ""
echo "Step 2: Configuring hub-user-service..."
echo "----------------------------------------"

# Update hub-user-service config.env
USER_SERVICE_CONFIG="$SCRIPT_DIR/hub-user-service/config.env"

if [ -f "$USER_SERVICE_CONFIG" ]; then
    echo "Updating $USER_SERVICE_CONFIG..."
    
    # Backup existing config
    cp "$USER_SERVICE_CONFIG" "$USER_SERVICE_CONFIG.backup"
    
    # Update DB_USER and DB_PASSWORD
    sed -i.tmp "s/^DB_USER=.*/DB_USER=$DB_USER/" "$USER_SERVICE_CONFIG"
    if [ -z "$DB_PASSWORD" ]; then
        sed -i.tmp "s/^DB_PASSWORD=.*/DB_PASSWORD=/" "$USER_SERVICE_CONFIG"
    else
        sed -i.tmp "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" "$USER_SERVICE_CONFIG"
    fi
    rm -f "$USER_SERVICE_CONFIG.tmp"
    
    echo -e "${GREEN}✓${NC} Updated hub-user-service configuration"
else
    echo -e "${RED}❌ Config file not found: $USER_SERVICE_CONFIG${NC}"
    exit 1
fi

echo ""
echo "Step 3: Configuring hub-api-gateway..."
echo "---------------------------------------"

# Create .env file for hub-api-gateway (if it doesn't exist)
GATEWAY_ENV="$SCRIPT_DIR/hub-api-gateway/.env"

echo "Creating $GATEWAY_ENV..."
cat > "$GATEWAY_ENV" << EOF
# Hub API Gateway Environment Variables
JWT_SECRET=$JWT_SECRET
CONFIG_PATH=config/config.yaml
EOF

echo -e "${GREEN}✓${NC} Created hub-api-gateway .env file"

echo ""
echo "Step 4: Running database migrations..."
echo "---------------------------------------"

cd "$SCRIPT_DIR/hub-user-service"
if [ -f "Makefile" ]; then
    if make migrate-up 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Database migrations completed"
    else
        echo -e "${YELLOW}⚠${NC}  Migration command failed or not configured (this may be okay if migrations already ran)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No Makefile found, skipping migrations"
fi

echo ""
echo "=============================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "=============================="
echo ""
echo "Configuration Summary:"
echo "  Database User: $DB_USER"
echo "  Database Name: hub_investments"
echo "  JWT Secret: Set (matching across services)"
echo ""
echo "To start the services:"
echo ""
echo "  Terminal 1 - hub-user-service:"
echo "    cd $SCRIPT_DIR/hub-user-service"
echo "    make run"
echo ""
echo "  Terminal 2 - hub-api-gateway:"
echo "    cd $SCRIPT_DIR/hub-api-gateway"
echo "    export JWT_SECRET=\"$JWT_SECRET\""
echo "    make run"
echo ""
echo "Or use the provided start scripts:"
echo "  ./start-user-service.sh"
echo "  ./start-api-gateway.sh"
echo ""

