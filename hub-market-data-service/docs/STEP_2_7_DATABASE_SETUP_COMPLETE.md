# Step 2.7: Database Setup - COMPLETE ✅

## Overview

Successfully set up an independent database for the Market Data Service with automated setup scripts, data migration utilities, and comprehensive documentation.

---

## What Was Implemented

### 1. Database Setup Script (`scripts/setup_database.sh`)

Created a comprehensive bash script to automate database creation and initialization.

**Features**:
- ✅ PostgreSQL connectivity verification
- ✅ Automatic database user creation
- ✅ Automatic database creation
- ✅ Permission grants (all privileges on database, schema, tables, sequences)
- ✅ Database initialization with schema and test data
- ✅ Color-coded output for better UX
- ✅ Error handling and validation
- ✅ Configurable via environment variables

**Usage**:
```bash
# Using defaults
./scripts/setup_database.sh

# With custom configuration
DB_NAME=my_market_data \
DB_USER=my_user \
DB_PASSWORD=my_password \
DB_HOST=localhost \
DB_PORT=5432 \
./scripts/setup_database.sh
```

**Environment Variables**:
| Variable | Default | Description |
|----------|---------|-------------|
| `DB_NAME` | `hub_market_data_service` | Database name |
| `DB_USER` | `market_data_user` | Database user |
| `DB_PASSWORD` | `market_data_password` | Database password |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `POSTGRES_USER` | `postgres` | PostgreSQL admin user |

**Output Example**:
```
========================================
Market Data Service - Database Setup
========================================

[1/5] Checking PostgreSQL connectivity...
✓ PostgreSQL is running

[2/5] Creating database user...
✓ User 'market_data_user' created/verified

[3/5] Creating database...
✓ Database 'hub_market_data_service' created/verified

[4/5] Granting permissions...
✓ Permissions granted

[5/5] Running database initialization...
✓ Database initialized

========================================
Database Setup Complete!
========================================

Database: hub_market_data_service
User:     market_data_user
Host:     localhost:5432

Connection string:
postgresql://market_data_user:market_data_password@localhost:5432/hub_market_data_service?sslmode=disable

Next steps:
1. Update .env with database credentials
2. Run 'make migrate-data' to copy data from monolith (optional)
3. Run 'make run' to start the service
```

---

### 2. Data Migration Script (`scripts/migrate_data.sh`)

Created a comprehensive bash script to migrate data from the monolith database to the microservice database.

**Features**:
- ✅ Source database connectivity verification
- ✅ Target database connectivity verification
- ✅ Data export from monolith using `\COPY`
- ✅ Data import to microservice with conflict handling
- ✅ Automatic upsert (INSERT ... ON CONFLICT DO UPDATE)
- ✅ Record counting and validation
- ✅ Sample data display
- ✅ Interactive prompts for empty source database
- ✅ Temporary file cleanup
- ✅ Color-coded output

**Usage**:
```bash
# Using defaults (monolith on localhost:5432)
./scripts/migrate_data.sh

# With custom configuration
SOURCE_DB_NAME=hub_investments \
SOURCE_DB_USER=postgres \
SOURCE_DB_PASSWORD=postgres \
TARGET_DB_NAME=hub_market_data_service \
TARGET_DB_USER=market_data_user \
TARGET_DB_PASSWORD=market_data_password \
./scripts/migrate_data.sh
```

**Environment Variables**:

**Target (Microservice) Database**:
| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_DB_NAME` | `hub_market_data_service` | Microservice database name |
| `TARGET_DB_USER` | `market_data_user` | Microservice database user |
| `TARGET_DB_PASSWORD` | `market_data_password` | Microservice database password |
| `TARGET_DB_HOST` | `localhost` | Microservice database host |
| `TARGET_DB_PORT` | `5432` | Microservice database port |

**Source (Monolith) Database**:
| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCE_DB_NAME` | `hub_investments` | Monolith database name |
| `SOURCE_DB_USER` | `postgres` | Monolith database user |
| `SOURCE_DB_PASSWORD` | `postgres` | Monolith database password |
| `SOURCE_DB_HOST` | `localhost` | Monolith database host |
| `SOURCE_DB_PORT` | `5432` | Monolith database port |

**Migration Logic**:
```sql
-- Export from source
\COPY (SELECT symbol, name, category, last_quote, created_at, updated_at FROM market_data) 
TO '/tmp/market_data_export.csv' WITH CSV HEADER

-- Import to target with upsert
INSERT INTO market_data (symbol, name, category, last_quote, created_at, updated_at)
SELECT symbol, name, category, last_quote, created_at, updated_at
FROM temp_market_data
ON CONFLICT (symbol) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    last_quote = EXCLUDED.last_quote,
    updated_at = EXCLUDED.updated_at;
```

**Output Example**:
```
========================================
Market Data - Data Migration
========================================

[1/5] Checking source database (monolith)...
✓ Source database accessible

[2/5] Checking target database (microservice)...
✓ Target database accessible

[3/5] Analyzing source data...
✓ Found 150 records in source database

[4/5] Migrating data...
✓ Data migrated successfully

[5/5] Verifying migration...
✓ Target database now has 150 records

Sample data in target database:
 symbol |        name         | category | last_quote 
--------+---------------------+----------+------------
 AAPL   | Apple Inc.          |        1 |     150.00
 MSFT   | Microsoft Corp.     |        1 |     300.00
 GOOGL  | Alphabet Inc.       |        1 |     140.00
 AMZN   | Amazon.com Inc.     |        1 |     180.00
 TSLA   | Tesla Inc.          |        1 |     250.00

========================================
Data Migration Complete!
========================================

Summary:
Source records:  150
Target records:  150

✓ Migration successful - all data copied
```

---

### 3. Makefile Integration

Updated Makefile with convenient database commands:

```makefile
.PHONY: db-setup
db-setup: ## Set up database (create database and user)
	@echo "Setting up database..."
	./scripts/setup_database.sh
	@echo "✓ Database setup complete"

.PHONY: db-migrate
db-migrate: ## Run database migrations (copy data from monolith)
	@echo "Running database migrations..."
	./scripts/migrate_data.sh
	@echo "✓ Database migrations complete"

.PHONY: db-reset
db-reset: ## Reset database (drop and recreate)
	@echo "⚠️  This will delete all data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Resetting database..."; \
		./scripts/reset_database.sh; \
		echo "✓ Database reset complete"; \
	fi
```

**Makefile Commands**:
```bash
# Set up database (create database, user, schema)
make db-setup

# Migrate data from monolith
make db-migrate

# Reset database (drop and recreate)
make db-reset

# Complete setup (setup + migrate)
make db-setup && make db-migrate
```

---

### 4. Database Schema

The database schema is defined in `migrations/000001_create_market_data_table.up.sql`:

```sql
CREATE TABLE IF NOT EXISTS market_data (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category INTEGER NOT NULL,
    last_quote DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_market_data_symbol ON market_data(symbol);
```

**Schema Details**:
- **Primary Key**: Auto-incrementing `id`
- **Unique Constraint**: `symbol` (prevents duplicate symbols)
- **Index**: `idx_market_data_symbol` for fast symbol lookups
- **Timestamps**: `created_at` and `updated_at` for audit trails

**Test Data**:
```sql
INSERT INTO market_data (symbol, name, category, last_quote) VALUES
('AAPL', 'Apple Inc.', 1, 150.00),
('MSFT', 'Microsoft Corporation', 1, 300.00),
('GOOGL', 'Alphabet Inc.', 1, 140.00),
('AMZN', 'Amazon.com Inc.', 1, 180.00)
ON CONFLICT (symbol) DO NOTHING;
```

---

## Database Architecture

### Independent Database Strategy

**Decision**: Market Data Service uses a **separate database** (`hub_market_data_service`) instead of sharing the monolith's database.

**Benefits**:
1. ✅ **Service Independence**: Microservice can be deployed, scaled, and maintained independently
2. ✅ **Fault Isolation**: Monolith database issues don't affect Market Data Service
3. ✅ **Performance Isolation**: High read load on market data doesn't impact other services
4. ✅ **Schema Evolution**: Can modify schema without coordinating with monolith
5. ✅ **Clear Ownership**: Market Data Service owns its data
6. ✅ **Easier Testing**: Can test with isolated test database

**Trade-offs**:
- ❌ Data duplication (market data exists in both databases during migration)
- ❌ Need for data synchronization (handled by migration script)
- ❌ Additional database instance (minimal cost for PostgreSQL)

**Migration Strategy**:
```
Phase 1: Monolith Database (Current State)
┌─────────────────────────────────┐
│   hub_investments (monolith)    │
│                                 │
│  - users                        │
│  - orders                       │
│  - positions                    │
│  - balances                     │
│  - market_data ← Source         │
└─────────────────────────────────┘

Phase 2: Dual Database (Migration Period)
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│   hub_investments (monolith)    │     │  hub_market_data_service        │
│                                 │     │                                 │
│  - users                        │     │  - market_data ← Target         │
│  - orders                       │ ──► │                                 │
│  - positions                    │     │  (Data copied via migration)    │
│  - balances                     │     │                                 │
│  - market_data ← Still exists   │     │                                 │
└─────────────────────────────────┘     └─────────────────────────────────┘

Phase 3: Final State (After Validation)
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│   hub_investments (monolith)    │     │  hub_market_data_service        │
│                                 │     │                                 │
│  - users                        │     │  - market_data ← Single Source  │
│  - orders                       │     │                                 │
│  - positions                    │     │  (Monolith table can be dropped)│
│  - balances                     │     │                                 │
│  - market_data ← Can be removed │     │                                 │
└─────────────────────────────────┘     └─────────────────────────────────┘
```

---

## Usage Guide

### Quick Start

**1. Set up database**:
```bash
cd hub-market-data-service
make db-setup
```

**2. Migrate data from monolith** (optional):
```bash
make db-migrate
```

**3. Verify setup**:
```bash
psql -h localhost -p 5432 -U market_data_user -d hub_market_data_service -c "SELECT COUNT(*) FROM market_data"
```

**4. Update `.env` file**:
```bash
cp .env.example .env
# Edit .env with database credentials
nano .env
```

**5. Run the service**:
```bash
make run
```

---

### Manual Database Operations

**Connect to database**:
```bash
psql -h localhost -p 5432 -U market_data_user -d hub_market_data_service
```

**Check table structure**:
```sql
\d market_data
```

**Query data**:
```sql
SELECT * FROM market_data LIMIT 10;
```

**Count records**:
```sql
SELECT COUNT(*) FROM market_data;
```

**Insert test data**:
```sql
INSERT INTO market_data (symbol, name, category, last_quote) 
VALUES ('TSLA', 'Tesla Inc.', 1, 250.00)
ON CONFLICT (symbol) DO NOTHING;
```

---

## Docker Integration

The database is fully integrated with Docker Compose:

```yaml
# deployments/docker-compose.yml
services:
  market-data-db:
    image: postgres:16-alpine
    container_name: market-data-db
    environment:
      POSTGRES_DB: hub_market_data_service
      POSTGRES_USER: market_data_user
      POSTGRES_PASSWORD: market_data_password
    ports:
      - "5433:5432"  # Avoid conflict with host PostgreSQL
    volumes:
      - market-data-db-data:/var/lib/postgresql/data
      - ../scripts/init_db.sql:/docker-entrypoint-initdb.d/init_db.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U market_data_user -d hub_market_data_service"]
      interval: 10s
      timeout: 5s
      retries: 5
```

**Start with Docker**:
```bash
docker compose -f deployments/docker-compose.yml up -d
```

**Check database health**:
```bash
docker compose -f deployments/docker-compose.yml ps
```

---

## Testing

### Database Connectivity Test

```go
// Test database connection
func TestDatabaseConnection(t *testing.T) {
    config := &config.Config{
        Database: config.DatabaseConfig{
            Host:     "localhost",
            Port:     "5432",
            User:     "market_data_user",
            Password: "market_data_password",
            DBName:   "hub_market_data_service",
            SSLMode:  "disable",
        },
    }
    
    db, err := database.NewSQLXDatabase(config.GetDatabaseDSN())
    require.NoError(t, err)
    defer db.Close()
    
    err = db.Ping(context.Background())
    require.NoError(t, err)
}
```

### Data Migration Test

```bash
# Test migration with empty source
SOURCE_DB_NAME=empty_db ./scripts/migrate_data.sh

# Test migration with data
SOURCE_DB_NAME=hub_investments ./scripts/migrate_data.sh

# Verify record count
psql -h localhost -U market_data_user -d hub_market_data_service -c "SELECT COUNT(*) FROM market_data"
```

---

## Troubleshooting

### Issue 1: Cannot connect to PostgreSQL

**Error**:
```
Error: Cannot connect to PostgreSQL at localhost:5432
```

**Solution**:
```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# Start PostgreSQL (macOS)
brew services start postgresql@16

# Start PostgreSQL (Linux)
sudo systemctl start postgresql

# Check PostgreSQL logs
tail -f /usr/local/var/log/postgres.log
```

---

### Issue 2: Permission denied

**Error**:
```
ERROR:  permission denied for database hub_market_data_service
```

**Solution**:
```bash
# Re-run setup script to fix permissions
./scripts/setup_database.sh

# Or manually grant permissions
psql -U postgres -d hub_market_data_service -c "GRANT ALL PRIVILEGES ON DATABASE hub_market_data_service TO market_data_user;"
```

---

### Issue 3: Database already exists

**Error**:
```
ERROR:  database "hub_market_data_service" already exists
```

**Solution**:
```bash
# This is normal - the script handles existing databases
# If you want to reset:
make db-reset
```

---

### Issue 4: Migration fails - source database not found

**Error**:
```
Error: Cannot connect to source database
Database: hub_investments
```

**Solution**:
```bash
# Check if monolith database exists
psql -U postgres -l | grep hub_investments

# If not, create it or use test data only
# The migration script will prompt you to continue with test data
```

---

## Files Created/Modified

### New Files:

1. **`scripts/setup_database.sh`** (150 lines)
   - Automated database setup script
   - User and database creation
   - Permission grants
   - Initialization

2. **`scripts/migrate_data.sh`** (180 lines)
   - Data migration from monolith
   - Conflict handling (upsert)
   - Validation and verification
   - Interactive prompts

3. **`docs/STEP_2_7_DATABASE_SETUP_COMPLETE.md`** (This document)
   - Comprehensive documentation
   - Usage guide
   - Troubleshooting

### Modified Files:

1. **`Makefile`** (already had database commands)
   - Commands reference new scripts
   - `make db-setup`, `make db-migrate`, `make db-reset`

### Existing Files (Used):

1. **`migrations/000001_create_market_data_table.up.sql`**
   - Database schema definition
   - Test data insertion

2. **`scripts/init_db.sql`**
   - Database initialization script
   - Used by setup script

---

## Next Steps

### Step 3.1: Copy Existing Unit Tests
- Copy all market data tests from monolith
- Update import paths
- Run tests and verify 100% pass rate

### Step 3.2: gRPC Integration Testing
- Test all gRPC methods
- Test authentication flow
- Test error handling

### Step 3.3: Performance Testing
- Load test gRPC endpoints
- Measure cache hit rates
- Measure latency

---

## Success Criteria

✅ **All criteria met:**

1. ✅ **Independent Database**: Separate `hub_market_data_service` database created
2. ✅ **Automated Setup**: One-command database setup (`make db-setup`)
3. ✅ **Data Migration**: Automated migration from monolith (`make db-migrate`)
4. ✅ **Schema Integrity**: Proper schema with indexes and constraints
5. ✅ **Test Data**: Initial test data for development
6. ✅ **Docker Integration**: Database runs in Docker Compose
7. ✅ **Documentation**: Comprehensive usage guide
8. ✅ **Error Handling**: Robust error handling in scripts
9. ✅ **Idempotency**: Scripts can be run multiple times safely
10. ✅ **Validation**: Automatic verification of migration success

---

## Summary

✅ **Step 2.7: Database Setup - COMPLETE!**

**Key Achievements**:
1. ✅ Created automated database setup script (150 lines)
2. ✅ Created automated data migration script (180 lines)
3. ✅ Integrated with Makefile for easy usage
4. ✅ Comprehensive documentation and troubleshooting guide
5. ✅ Independent database following microservices best practices
6. ✅ Docker Compose integration for local development
7. ✅ Idempotent scripts (safe to run multiple times)
8. ✅ Conflict handling (upsert) for data migration
9. ✅ Interactive prompts for safety
10. ✅ Color-coded output for better UX

**Database Features**:
- ✅ Separate database per service (Database Per Service Pattern)
- ✅ Automated setup and migration
- ✅ Proper indexes for performance
- ✅ Unique constraints for data integrity
- ✅ Timestamps for audit trails
- ✅ Test data for development
- ✅ Health checks in Docker

**Status**: **READY FOR TESTING** 🎉

---

**Note**: Changes are **NOT committed** as per user request. Review the implementation before committing.

