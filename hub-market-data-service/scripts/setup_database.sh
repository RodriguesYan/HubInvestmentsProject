#!/bin/bash

# Market Data Service - Database Setup Script
# This script creates the database, user, and grants permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_NAME="${DB_NAME:-hub_market_data_service}"
DB_USER="${DB_USER:-market_data_user}"
DB_PASSWORD="${DB_PASSWORD:-market_data_password}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Market Data Service - Database Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if PostgreSQL is running
echo -e "${YELLOW}[1/5] Checking PostgreSQL connectivity...${NC}"
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -c '\q' 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to PostgreSQL at $DB_HOST:$DB_PORT${NC}"
    echo -e "${RED}Please ensure PostgreSQL is running and credentials are correct${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is running${NC}"
echo ""

# Create database user if it doesn't exist
echo -e "${YELLOW}[2/5] Creating database user...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
EOF
echo -e "${GREEN}✓ User '$DB_USER' created/verified${NC}"
echo ""

# Create database if it doesn't exist
echo -e "${YELLOW}[3/5] Creating database...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" <<EOF
CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOF
echo -e "${GREEN}✓ Database '$DB_NAME' created/verified${NC}"
echo ""

# Grant permissions
echo -e "${YELLOW}[4/5] Granting permissions...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER" -d "$DB_NAME" <<EOF
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOF
echo -e "${GREEN}✓ Permissions granted${NC}"
echo ""

# Run initialization script
echo -e "${YELLOW}[5/5] Running database initialization...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$(dirname "$0")/init_db.sql"
echo -e "${GREEN}✓ Database initialized${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Database Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Database: ${GREEN}$DB_NAME${NC}"
echo -e "User:     ${GREEN}$DB_USER${NC}"
echo -e "Host:     ${GREEN}$DB_HOST:$DB_PORT${NC}"
echo ""
echo -e "${YELLOW}Connection string:${NC}"
echo -e "postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=disable"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update .env with database credentials"
echo -e "2. Run 'make migrate-data' to copy data from monolith (optional)"
echo -e "3. Run 'make run' to start the service"
echo ""

