# Quick Fix Guide

## ✅ FIXED: No More Manual Exports!

The hub-api-gateway now automatically loads configuration from `.env` file, just like the other services!

## TL;DR - Fast Solution

Run this automated setup script:

```bash
cd /Users/yanrodrigues/Documents/HubInvestmentsProject
./setup-services.sh
```

Then start the services in separate terminals:

```bash
# Terminal 1
./start-user-service.sh

# Terminal 2
./start-api-gateway.sh
```

**Or manually:**

```bash
# Terminal 1 - hub-user-service
cd hub-user-service
make run

# Terminal 2 - hub-api-gateway
cd hub-api-gateway
./create-env.sh  # One-time setup
make run
```

---

## Manual Fix (if you prefer)

### Fix 1: hub-api-gateway - Create .env file (one-time)

**Create the .env file once:**

```bash
cd hub-api-gateway
./create-env.sh
make run
```

**That's it!** The gateway now automatically loads JWT_SECRET from `.env` (no more manual exports needed!)

### Fix 2: hub-user-service - Database setup

**Automated Fix (Recommended):**

```bash
cd hub-user-service
./verify-config.sh
```

This script will automatically:
- ✅ Check your PostgreSQL setup
- ✅ Verify database exists
- ✅ Check user credentials
- ✅ Offer to fix issues automatically

**Manual Fix:**

**Option A: Create postgres role**

```bash
psql postgres -c "CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;"
```

**Option B: Use your current user**

Edit `hub-user-service/config.env` and change:

```bash
DB_USER=yanrodrigues  # or whatever `whoami` returns
DB_PASSWORD=          # leave empty
```

### Fix 3: Ensure database exists

```bash
createdb hub_investments
```

---

## Verification

After starting both services, test them:

```bash
# Test user service
curl http://localhost:8080/health

# Test API gateway (different port if configured)
curl http://localhost:8080/health
```

## Stopping Services

If you need to stop all running services:

```bash
./stop-all-services.sh
```

This will:
- ✅ Kill all Go server processes
- ✅ Free up ports 8080 and 50051
- ✅ Clean up orphaned processes

---

## What the scripts do:

1. **setup-services.sh**: 
   - Checks PostgreSQL setup
   - Creates/verifies database
   - Updates configuration files
   - Runs migrations

2. **start-user-service.sh**: 
   - Loads config.env
   - Starts hub-user-service

3. **start-api-gateway.sh**: 
   - Sets JWT_SECRET
   - Starts hub-api-gateway

---

## Troubleshooting

### "command not found: psql"
Install PostgreSQL first:
```bash
brew install postgresql@14
```

### "database does not exist"
```bash
createdb hub_investments
```

### "connection refused"
Make sure PostgreSQL is running:
```bash
brew services start postgresql@14
```

### Services still failing?
Check the detailed guide: `SETUP_SERVICES.md`

