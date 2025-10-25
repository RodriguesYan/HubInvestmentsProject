# Service Management Guide

## Quick Commands

### Start Services

```bash
# Terminal 1 - User Service
cd hub-user-service
make run

# Terminal 2 - API Gateway
cd hub-api-gateway
make run

# Terminal 3 - Monolith (optional)
cd HubInvestmentsServer
make run
```

### Stop All Services

```bash
./stop-all-services.sh
```

### Check What's Running

```bash
# Check port 8080 (HTTP)
lsof -ti:8080

# Check port 50051 (gRPC - user service)
lsof -ti:50051

# Check port 50060 (gRPC - monolith)
lsof -ti:50060
```

## Common Issues

### Issue: "bind: address already in use"

**Error:**
```
❌ Server failed: listen tcp :8080: bind: address already in use
```

**Solution:**
```bash
# Option 1: Use the stop script
./stop-all-services.sh

# Option 2: Kill specific port
lsof -ti:8080 | xargs kill -9

# Option 3: Find and kill manually
lsof -ti:8080  # Get PID
kill -9 <PID>  # Kill the process
```

### Issue: Background process won't die

**Solution:**
```bash
# Find all Go processes
ps aux | grep "go run"

# Kill all Go server processes
pkill -9 -f "go run cmd/server/main.go"

# Nuclear option - kill all Go processes
pkill -9 go
```

### Issue: Orphaned Go build processes

Sometimes Go leaves behind compiled binaries in the cache that keep running.

**Solution:**
```bash
# Find them
ps aux | grep "go-build.*main"

# Kill them
ps aux | grep "go-build.*main" | grep -v grep | awk '{print $2}' | xargs kill -9

# Or use the stop script
./stop-all-services.sh
```

## Port Allocation

| Service | HTTP Port | gRPC Port | Notes |
|---------|-----------|-----------|-------|
| hub-user-service | 8080 | 50051 | Authentication service |
| hub-api-gateway | 8080 | - | API Gateway (conflicts with user service!) |
| HubInvestmentsServer | 8080 | 50060 | Monolith (conflicts with others!) |

⚠️ **Warning:** All services use port 8080 by default! You can only run ONE at a time, or you need to change ports.

## Running Multiple Services

### Option 1: Change Ports (Recommended)

**hub-api-gateway** - Change to port 8081:

```bash
# Edit hub-api-gateway/.env
HTTP_PORT=8081

# Or export before running
HTTP_PORT=8081 make run
```

**hub-user-service** - Keep on port 8080:
```bash
# Already configured in config.env
HTTP_PORT=localhost:8080
```

**HubInvestmentsServer** - Change to port 8082:
```bash
# Edit HubInvestmentsServer/config.env
HTTP_PORT=localhost:8082
```

### Option 2: Run One at a Time

Only run the service you're currently working on:

```bash
# Working on user service
cd hub-user-service
make run

# When done, stop it
./stop-all-services.sh

# Now work on gateway
cd hub-api-gateway
make run
```

## Service Dependencies

```
┌─────────────────┐
│  hub-api-gateway│  (Port 8080/8081)
└────────┬────────┘
         │
         ├──────────> hub-user-service (Port 8080, gRPC 50051)
         │
         └──────────> HubInvestmentsServer (Port 8080/8082, gRPC 50060)
```

**Startup Order:**
1. Start **hub-user-service** first (gateway needs it)
2. Start **HubInvestmentsServer** (if needed)
3. Start **hub-api-gateway** last

## Recommended Port Configuration

To avoid conflicts, use these ports:

| Service | HTTP Port | gRPC Port | Command |
|---------|-----------|-----------|---------|
| hub-user-service | 8080 | 50051 | `make run` |
| hub-api-gateway | 8081 | - | `HTTP_PORT=8081 make run` |
| HubInvestmentsServer | 8082 | 50060 | `HTTP_PORT=localhost:8082 make run` |

### Update Configurations

**hub-api-gateway/.env:**
```bash
JWT_SECRET=HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^
HTTP_PORT=8081  # Changed from 8080
CONFIG_PATH=config/config.yaml
```

**hub-user-service/config.env:**
```bash
HTTP_PORT=localhost:8080  # Keep as is
GRPC_PORT=localhost:50051
```

**HubInvestmentsServer/config.env:**
```bash
HTTP_PORT=localhost:8082  # Changed from 8080
GRPC_PORT=localhost:50060
```

## Testing Services

### hub-user-service (Port 8080)

```bash
# Health check
curl http://localhost:8080/health

# Login (if you have a user)
curl -X POST http://localhost:8080/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### hub-api-gateway (Port 8081)

```bash
# Health check
curl http://localhost:8081/health

# Metrics
curl http://localhost:8081/metrics

# Login through gateway
curl -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### HubInvestmentsServer (Port 8082)

```bash
# Health check (if implemented)
curl http://localhost:8082/health

# Login
curl -X POST http://localhost:8082/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

## Monitoring

### Check Service Status

```bash
# Check all ports
for port in 8080 8081 8082 50051 50060; do
    echo -n "Port $port: "
    lsof -ti:$port > /dev/null 2>&1 && echo "IN USE" || echo "FREE"
done
```

### View Service Logs

```bash
# Run with output to file
cd hub-user-service
make run 2>&1 | tee service.log

# In another terminal, tail the log
tail -f service.log
```

## Development Workflow

### Typical Development Session

```bash
# 1. Stop any running services
./stop-all-services.sh

# 2. Start the service you're working on
cd hub-user-service
make run

# 3. In another terminal, test it
curl http://localhost:8080/health

# 4. When done, stop it
./stop-all-services.sh
```

### Running All Services Together

```bash
# Terminal 1
cd hub-user-service
make run

# Terminal 2
cd hub-api-gateway
HTTP_PORT=8081 make run

# Terminal 3
cd HubInvestmentsServer
HTTP_PORT=localhost:8082 make run

# Terminal 4 - Testing
curl http://localhost:8080/health  # user service
curl http://localhost:8081/health  # gateway
curl http://localhost:8082/health  # monolith
```

## Scripts Reference

### stop-all-services.sh

Stops all Hub services by:
1. Killing Go server processes
2. Freeing ports 8080, 50051, 50060
3. Cleaning up orphaned processes

**Usage:**
```bash
./stop-all-services.sh
```

### start-user-service.sh

Starts hub-user-service with config.env loaded.

**Usage:**
```bash
./start-user-service.sh
```

### start-api-gateway.sh

Starts hub-api-gateway with .env loaded.

**Usage:**
```bash
./start-api-gateway.sh
```

## Troubleshooting

### Services won't stop

```bash
# Nuclear option - kill all Go processes
pkill -9 go

# Then verify
lsof -ti:8080
lsof -ti:50051
```

### Port still in use after killing

```bash
# Wait a few seconds
sleep 5

# Check again
lsof -ti:8080

# Force kill with sudo (last resort)
sudo lsof -ti:8080 | xargs sudo kill -9
```

### Can't find which service is running

```bash
# List all processes on port 8080
lsof -i:8080

# Get full command
ps aux | grep $(lsof -ti:8080)
```

## Best Practices

1. **Always stop services before starting new ones**
   ```bash
   ./stop-all-services.sh
   ```

2. **Use different ports for each service**
   - Avoids conflicts
   - Can run all services simultaneously
   - Easier debugging

3. **Check ports before starting**
   ```bash
   lsof -ti:8080 || echo "Port is free"
   ```

4. **Use the provided scripts**
   - `./stop-all-services.sh` - Clean shutdown
   - `./start-user-service.sh` - Start with config
   - `./start-api-gateway.sh` - Start with config

5. **Monitor logs**
   ```bash
   make run 2>&1 | tee service.log
   ```

## Summary

✅ **Start:** Use `make run` in service directory  
✅ **Stop:** Use `./stop-all-services.sh`  
✅ **Check:** Use `lsof -ti:PORT`  
✅ **Test:** Use `curl http://localhost:PORT/health`  
✅ **Avoid conflicts:** Use different ports for each service  

---

**Quick Reference Card:**

```bash
# Stop everything
./stop-all-services.sh

# Start user service (port 8080)
cd hub-user-service && make run

# Start gateway (port 8081)
cd hub-api-gateway && HTTP_PORT=8081 make run

# Check what's running
lsof -ti:8080 && echo "8080 in use" || echo "8080 free"
```

