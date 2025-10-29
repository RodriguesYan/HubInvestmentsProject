#!/bin/bash

# Market Data Service - Data Migration Script
# This script copies market data from the monolith database to the microservice database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Microservice Database Configuration
TARGET_DB_NAME="${TARGET_DB_NAME:-hub_market_data_service}"
TARGET_DB_USER="${TARGET_DB_USER:-market_data_user}"
TARGET_DB_PASSWORD="${TARGET_DB_PASSWORD:-market_data_password}"
TARGET_DB_HOST="${TARGET_DB_HOST:-localhost}"
TARGET_DB_PORT="${TARGET_DB_PORT:-5432}"

# Monolith Database Configuration
SOURCE_DB_NAME="${SOURCE_DB_NAME:-hub_investments}"
SOURCE_DB_USER="${SOURCE_DB_USER:-postgres}"
SOURCE_DB_PASSWORD="${SOURCE_DB_PASSWORD:-postgres}"
SOURCE_DB_HOST="${SOURCE_DB_HOST:-localhost}"
SOURCE_DB_PORT="${SOURCE_DB_PORT:-5432}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Market Data - Data Migration${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check source database connectivity
echo -e "${YELLOW}[1/5] Checking source database (monolith)...${NC}"
if ! PGPASSWORD="$SOURCE_DB_PASSWORD" psql -h "$SOURCE_DB_HOST" -p "$SOURCE_DB_PORT" -U "$SOURCE_DB_USER" -d "$SOURCE_DB_NAME" -c '\q' 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to source database${NC}"
    echo -e "${RED}Host: $SOURCE_DB_HOST:$SOURCE_DB_PORT${NC}"
    echo -e "${RED}Database: $SOURCE_DB_NAME${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Source database accessible${NC}"
echo ""

# Check target database connectivity
echo -e "${YELLOW}[2/5] Checking target database (microservice)...${NC}"
if ! PGPASSWORD="$TARGET_DB_PASSWORD" psql -h "$TARGET_DB_HOST" -p "$TARGET_DB_PORT" -U "$TARGET_DB_USER" -d "$TARGET_DB_NAME" -c '\q' 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to target database${NC}"
    echo -e "${RED}Host: $TARGET_DB_HOST:$TARGET_DB_PORT${NC}"
    echo -e "${RED}Database: $TARGET_DB_NAME${NC}"
    echo -e "${YELLOW}Run 'make setup-db' first to create the database${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Target database accessible${NC}"
echo ""

# Count records in source
echo -e "${YELLOW}[3/5] Analyzing source data...${NC}"
SOURCE_COUNT=$(PGPASSWORD="$SOURCE_DB_PASSWORD" psql -h "$SOURCE_DB_HOST" -p "$SOURCE_DB_PORT" -U "$SOURCE_DB_USER" -d "$SOURCE_DB_NAME" -t -c "SELECT COUNT(*) FROM market_data" 2>/dev/null || echo "0")
SOURCE_COUNT=$(echo "$SOURCE_COUNT" | tr -d ' ')

if [ "$SOURCE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No data found in source database${NC}"
    echo -e "${YELLOW}This is normal if the monolith hasn't been populated yet${NC}"
    echo ""
    echo -e "${BLUE}Would you like to continue with test data only? (y/n)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Migration cancelled${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}✓ Found $SOURCE_COUNT records in source database${NC}"
fi
echo ""

# Migrate data
if [ "$SOURCE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}[4/5] Migrating data...${NC}"
    
    # Export data from source
    PGPASSWORD="$SOURCE_DB_PASSWORD" psql -h "$SOURCE_DB_HOST" -p "$SOURCE_DB_PORT" -U "$SOURCE_DB_USER" -d "$SOURCE_DB_NAME" -c "\COPY (SELECT symbol, name, category, last_quote, created_at, updated_at FROM market_data) TO '/tmp/market_data_export.csv' WITH CSV HEADER"
    
    # Import data to target (with conflict handling)
    PGPASSWORD="$TARGET_DB_PASSWORD" psql -h "$TARGET_DB_HOST" -p "$TARGET_DB_PORT" -U "$TARGET_DB_USER" -d "$TARGET_DB_NAME" <<EOF
-- Temporary table for import
CREATE TEMP TABLE temp_market_data (
    symbol VARCHAR(50),
    name VARCHAR(255),
    category INTEGER,
    last_quote DECIMAL(10, 2),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Import CSV data
\COPY temp_market_data FROM '/tmp/market_data_export.csv' WITH CSV HEADER

-- Insert with conflict handling (update if exists)
INSERT INTO market_data (symbol, name, category, last_quote, created_at, updated_at)
SELECT symbol, name, category, last_quote, created_at, updated_at
FROM temp_market_data
ON CONFLICT (symbol) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    last_quote = EXCLUDED.last_quote,
    updated_at = EXCLUDED.updated_at;

-- Clean up
DROP TABLE temp_market_data;
EOF
    
    # Clean up temp file
    rm -f /tmp/market_data_export.csv
    
    echo -e "${GREEN}✓ Data migrated successfully${NC}"
else
    echo -e "${YELLOW}[4/5] Skipping data migration (no source data)${NC}"
fi
echo ""

# Verify migration
echo -e "${YELLOW}[5/5] Verifying migration...${NC}"
TARGET_COUNT=$(PGPASSWORD="$TARGET_DB_PASSWORD" psql -h "$TARGET_DB_HOST" -p "$TARGET_DB_PORT" -U "$TARGET_DB_USER" -d "$TARGET_DB_NAME" -t -c "SELECT COUNT(*) FROM market_data")
TARGET_COUNT=$(echo "$TARGET_COUNT" | tr -d ' ')

echo -e "${GREEN}✓ Target database now has $TARGET_COUNT records${NC}"
echo ""

# Show sample data
echo -e "${YELLOW}Sample data in target database:${NC}"
PGPASSWORD="$TARGET_DB_PASSWORD" psql -h "$TARGET_DB_HOST" -p "$TARGET_DB_PORT" -U "$TARGET_DB_USER" -d "$TARGET_DB_NAME" -c "SELECT symbol, name, category, last_quote FROM market_data LIMIT 5"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Data Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo -e "Source records:  ${BLUE}$SOURCE_COUNT${NC}"
echo -e "Target records:  ${BLUE}$TARGET_COUNT${NC}"
echo ""

if [ "$SOURCE_COUNT" -gt 0 ] && [ "$TARGET_COUNT" -ge "$SOURCE_COUNT" ]; then
    echo -e "${GREEN}✓ Migration successful - all data copied${NC}"
elif [ "$TARGET_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Target database populated with test data${NC}"
else
    echo -e "${YELLOW}⚠ No data in target database${NC}"
fi
echo ""

