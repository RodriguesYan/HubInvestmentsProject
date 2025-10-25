# Database Alignment Fix

## Problem Summary

You reported two issues:
1. **Authentication not working**: Endpoints were returning data with invalid tokens instead of `401 Unauthorized`
2. **Foreign key constraint violation**: Orders were failing with error: `"pq: insert or update on table "orders" violates foreign key constraint "orders_user_id_fkey"`

## Root Cause

The services were using **different databases**:

| Service | Database | User ID |
|---------|----------|---------|
| **User Service** | `hubinvestments` | ID 3 (test@test.com) |
| **Monolith** | `yanrodrigues` | ID 999 (test@test.com) |
| **API Gateway** | N/A (validates via gRPC) | - |

### The Problem Flow

1. User logs in via User Service → Gets JWT token with `userId: "3"` (from `hubinvestments` database)
2. User submits order via API Gateway → Token validated successfully (user 3 exists in `hubinvestments`)
3. Monolith tries to save order → Tries to insert `user_id=3` into `yanrodrigues` database
4. **FAILURE**: User ID 3 doesn't exist in `yanrodrigues` database → Foreign key constraint violation

## Solution

Aligned all services to use the **same database**: `yanrodrigues`

### Changes Made

#### 1. Updated User Service Configuration

**File**: `hub-user-service/config.env`

```diff
- DB_NAME=hubinvestments
+ DB_NAME=yanrodrigues
```

This ensures the User Service validates tokens and manages users in the same database where orders are stored.

#### 2. Restarted All Services

Stopped all running services and restarted them with the correct configuration:

```bash
# Stop all services
kill -9 <all_pids>

# Start User Service (port 50051)
cd hub-user-service && ./bin/user-service > /tmp/user-service.log 2>&1 &

# Start Monolith (ports 8080, 50060)
cd HubInvestmentsServer && ./bin/server > /tmp/server.log 2>&1 &

# Start API Gateway (port 3000)
cd hub-api-gateway && HTTP_PORT=3000 ./bin/gateway > /tmp/gateway.log 2>&1 &
```

## Verification

### ✅ Issue 1: Authentication Now Works Correctly

**Test 1: No Token**
```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"symbol": "VOO", "order_type": "MARKET", "order_side": "BUY", "quantity": 5}'

# Response: {"code":"AUTH_TOKEN_MISSING","error":"Authorization token is required"}
# Status: 401 Unauthorized ✅
```

**Test 2: Invalid Token**
```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid_token_here" \
  -d '{"symbol": "VOO", "order_type": "MARKET", "order_side": "BUY", "quantity": 5}'

# Response: {"code":"AUTH_TOKEN_INVALID","error":"Token expired or invalid"}
# Status: 401 Unauthorized ✅
```

**Test 3: Valid Token**
```bash
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <valid_token>" \
  -d '{"symbol": "VOO", "order_type": "MARKET", "order_side": "BUY", "quantity": 10}'

# Response: {"order_id":"9c84fb47-30a8-45b6-b7c2-0b17bbc06faa","status":"PENDING",...}
# Status: 200 OK ✅
```

### ✅ Issue 2: Foreign Key Constraint Fixed

**Database Verification:**
```sql
SELECT id, user_id, symbol, order_type, order_side, quantity, status 
FROM orders 
WHERE id='9c84fb47-30a8-45b6-b7c2-0b17bbc06faa';

-- Result:
--   id                  | user_id | symbol | order_type | order_side | quantity | status
-- ----------------------+---------+--------+------------+------------+----------+----------
--  9c84fb47-...         |     999 | VOO    | MARKET     | BUY        | 10.0     | EXECUTED
```

✅ Order saved successfully with `user_id=999`  
✅ Foreign key constraint satisfied  
✅ Order automatically executed by worker

## Current Database State

### `yanrodrigues` Database (ACTIVE)

**Users Table:**
```sql
SELECT id, email, name FROM users;

-- Result:
--  id  |     email     |   name    
-- -----+---------------+-----------
--  999 | test@test.com | Test User
```

**Orders Table:**
```sql
SELECT id, user_id, symbol, status 
FROM orders 
WHERE user_id=999 
ORDER BY created_at DESC 
LIMIT 3;

-- Result: Multiple successful orders ✅
```

### `hubinvestments` Database (INACTIVE)

This database is no longer used by any service. It contains:
- User ID 2 (bla@bla.com)
- User ID 3 (test@test.com)

**Note**: This database can be kept for backup purposes or deleted if not needed.

## Services Status

| Service | Port | Status | Database |
|---------|------|--------|----------|
| **User Service** | 50051 (gRPC) | ✅ Running | `yanrodrigues` |
| **Monolith HTTP** | 8080 | ✅ Running | `yanrodrigues` |
| **Monolith gRPC** | 50060 | ✅ Running | `yanrodrigues` |
| **API Gateway** | 3000 | ✅ Running | N/A (validates via gRPC) |
| **RabbitMQ** | 5672, 15672 | ✅ Running | N/A |
| **Redis** | 6379 | ✅ Running | N/A |
| **PostgreSQL** | 5432 | ✅ Running | N/A |

## How to Generate a Valid Token

```bash
# Create token generator
cat > /tmp/gen_token.go << 'EOF'
package main

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt"
)

func main() {
	secret := "HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^"
	userID := "999"
	username := "test@test.com"

	token := jwt.NewWithClaims(jwt.SigningMethodHS256,
		jwt.MapClaims{
			"username": username,
			"userId":   userID,
			"exp":      time.Now().Add(time.Hour * 24).Unix(),
		})

	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		panic(err)
	}

	fmt.Println(tokenString)
}
EOF

# Generate token
cd /tmp && go run gen_token.go

# Use the generated token in your requests
TOKEN=$(cd /tmp && go run gen_token.go)
curl -X POST http://localhost:3000/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"symbol": "VOO", "order_type": "MARKET", "order_side": "BUY", "quantity": 5}'
```

## Key Learnings

1. **Database Consistency**: All microservices that share data must use the same database
2. **User ID Mapping**: JWT tokens contain user IDs from the authentication database - these must match the database where business logic is executed
3. **Foreign Key Constraints**: These are enforced at the database level and will fail if referential integrity is violated
4. **Service Restart**: After configuration changes, all affected services must be restarted

## Troubleshooting

### If you see "foreign key constraint" error again:

1. **Check which database each service is using:**
   ```bash
   # User Service
   grep DB_NAME hub-user-service/config.env
   
   # Monolith (check code)
   grep -A5 "DefaultConfig" HubInvestmentsServer/shared/infra/database/connection_factory.go
   ```

2. **Verify user exists in the correct database:**
   ```bash
   psql -d yanrodrigues -c "SELECT id, email FROM users WHERE id=999;"
   ```

3. **Restart all services:**
   ```bash
   # Stop all
   lsof -i :3000 -i :8080 -i :50051 -i :50060 | grep LISTEN | awk '{print $2}' | xargs kill -9
   
   # Start all (see "Restarted All Services" section above)
   ```

### If authentication is not working:

1. **Check if User Service is running:**
   ```bash
   lsof -i :50051 | grep LISTEN
   ```

2. **Check User Service logs:**
   ```bash
   tail -50 /tmp/user-service.log
   ```

3. **Verify JWT secret matches across services:**
   ```bash
   grep JWT_SECRET hub-user-service/config.env
   grep JWT_SECRET HubInvestmentsServer/config.env
   grep JWT_SECRET hub-api-gateway/.env
   ```

## Files Modified

1. **hub-user-service/config.env** - Changed `DB_NAME` from `hubinvestments` to `yanrodrigues`

## Next Steps

1. ✅ **All issues resolved** - System is working correctly
2. **Optional**: Consider migrating users from `hubinvestments` to `yanrodrigues` if needed
3. **Optional**: Update documentation to reflect the single database architecture
4. **Recommended**: Add integration tests to verify database consistency across services

---

**Date**: October 23, 2025  
**Status**: ✅ All Issues Resolved  
**Database**: `yanrodrigues` (unified across all services)

