# Setup Guide for Hub Services

This guide will help you fix the configuration issues for both `hub-api-gateway` and `hub-user-service`.

## Issues Identified

1. **hub-api-gateway**: Missing `JWT_SECRET` environment variable
2. **hub-user-service**: PostgreSQL role "postgres" does not exist

## Solutions

### 1. Fix hub-api-gateway

The API Gateway needs the `JWT_SECRET` environment variable to be set. You have two options:

#### Option A: Export environment variable (Quick Fix)

```bash
# In your terminal, before running the gateway:
export JWT_SECRET="HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^"
```

#### Option B: Create .env file (Recommended)

Create a `.env` file in the `hub-api-gateway` directory:

```bash
cd hub-api-gateway
cat > .env << 'EOF'
# Hub API Gateway Environment Variables
JWT_SECRET=HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^
CONFIG_PATH=config/config.yaml
EOF
```

Then update your run command to load the .env file:

```bash
# If using make:
make run

# Or manually:
source .env && go run cmd/server/main.go
```

### 2. Fix hub-user-service Database Connection

The PostgreSQL role "postgres" doesn't exist in your database. You have two options:

#### Option A: Create the postgres role

```bash
# Connect to PostgreSQL as your current user
psql postgres

# Then in the PostgreSQL prompt:
CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
\q
```

#### Option B: Update config.env to use your existing database user

Find out your current PostgreSQL user:

```bash
whoami
```

Then update `hub-user-service/config.env`:

```bash
# Replace 'postgres' with your actual username
DB_USER=your_actual_username
DB_PASSWORD=  # Leave empty if no password, or set your password
```

For example, if your username is `yanrodrigues`:

```bash
DB_USER=yanrodrigues
DB_PASSWORD=
```

### 3. Verify Database Exists

Make sure the `hub_investments` database exists:

```bash
# List databases
psql -l

# If hub_investments doesn't exist, create it:
createdb hub_investments

# Or using psql:
psql postgres -c "CREATE DATABASE hub_investments;"
```

### 4. Run Database Migrations (if needed)

For hub-user-service:

```bash
cd hub-user-service
make migrate-up
```

## Quick Start Commands

### Start hub-user-service:

```bash
cd hub-user-service

# Make sure config.env has correct database credentials
# Then run:
make run
```

### Start hub-api-gateway:

```bash
cd hub-api-gateway

# Set JWT_SECRET environment variable
export JWT_SECRET="HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^"

# Run the gateway
make run
```

## Verification

### Test hub-user-service:

```bash
# Check health endpoint
curl http://localhost:8080/health

# Test login (if you have a user in the database)
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### Test hub-api-gateway:

```bash
# Check health endpoint
curl http://localhost:8080/health

# Check metrics
curl http://localhost:8080/metrics
```

## Common Issues

### Issue: "JWT_SECRET environment variable is required"
**Solution**: Export the JWT_SECRET before running the gateway (see Option A above)

### Issue: "role 'postgres' does not exist"
**Solution**: Either create the postgres role or update DB_USER in config.env (see Option B above)

### Issue: "database 'hub_investments' does not exist"
**Solution**: Create the database using `createdb hub_investments`

### Issue: Services can't connect to each other
**Solution**: Make sure both services are running and check the port configurations:
- hub-user-service gRPC: localhost:50051
- hub-api-gateway HTTP: localhost:8080

## Environment Variables Summary

### hub-api-gateway requires:
- `JWT_SECRET`: Must match the value in hub-user-service

### hub-user-service requires (in config.env):
- `MY_JWT_SECRET`: Must match JWT_SECRET in hub-api-gateway
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`: PostgreSQL connection details
- `HTTP_PORT`, `GRPC_PORT`: Server ports

## Next Steps

1. Fix the configuration issues above
2. Start hub-user-service first
3. Then start hub-api-gateway
4. Verify both services are running with health checks
5. Test the login flow through the gateway

