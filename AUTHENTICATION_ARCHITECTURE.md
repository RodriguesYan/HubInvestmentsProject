# Authentication Architecture

## Overview

The Hub Investments platform uses a **Gateway-Based Authentication** pattern where the API Gateway is the single point of authentication for all external requests. This approach eliminates redundant authentication checks in downstream services and improves performance.

## Architecture Diagram

```
┌─────────────┐
│   Client    │
│  (Browser/  │
│   Mobile)   │
└──────┬──────┘
       │ HTTP + JWT Token
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│                    API Gateway                          │
│                   (Port 8081)                           │
│                                                         │
│  1. Validates JWT Token (via User Service)             │
│  2. Extracts User Context (userId, email)              │
│  3. Forwards Context in gRPC Metadata                  │
│     - x-user-id: "2"                                   │
│     - x-user-email: "user@example.com"                 │
│                                                         │
└───────┬──────────────────────────────┬─────────────────┘
        │                              │
        │ gRPC + Metadata              │ gRPC + Metadata
        │                              │
        ▼                              ▼
┌──────────────────┐          ┌──────────────────┐
│  User Service    │          │    Monolith      │
│  (Port 50051)    │          │  (Port 50060)    │
│                  │          │                  │
│  ✅ Validates JWT │          │  ✅ Trusts Gateway│
│  ✅ Returns User  │          │  ✅ Extracts User │
│     Context      │          │     from Metadata│
│                  │          │  ❌ No JWT Check  │
└──────────────────┘          └──────────────────┘
```

## Authentication Flow

### 1. **Login Flow**

```
Client → API Gateway → User Service
  POST /api/v1/auth/login
  {
    "email": "user@example.com",
    "password": "password123"
  }

User Service:
  ✅ Validates credentials
  ✅ Generates JWT token
  ✅ Returns token to client

Response:
  {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "userId": "2",
      "email": "user@example.com"
    }
  }
```

### 2. **Authenticated Request Flow**

```
Client → API Gateway → Monolith/Services
  POST /api/v1/orders
  Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
  {
    "symbol": "AAPL",
    "quantity": 10
  }

API Gateway:
  ✅ Extracts JWT from Authorization header
  ✅ Validates token with User Service (cached)
  ✅ Extracts userId and email from token
  ✅ Forwards to monolith with metadata:
     - authorization: Bearer eyJhbGciOiJIUzI1NiIs... (optional, for audit/logging)
     - x-user-id: "2" (CRITICAL - used by monolith)
     - x-user-email: "user@example.com" (CRITICAL - used by monolith)

Monolith:
  ✅ Extracts x-user-id from metadata (CRITICAL)
  ✅ Extracts x-user-email from metadata (optional)
  ✅ Adds userId to context
  ✅ Processes business logic
  ❌ No JWT validation (trusts gateway)
  ⚠️  SECURITY: Monolith MUST NOT be publicly accessible (see Step 4.10 in TODO.md)

Response:
  {
    "orderId": "order-123",
    "status": "submitted"
  }
```

## Components

### 1. API Gateway (hub-api-gateway)

**Responsibilities:**
- ✅ Validate all incoming JWT tokens
- ✅ Cache token validation results (5 minutes TTL)
- ✅ Extract user context from validated tokens
- ✅ Forward user context to downstream services via gRPC metadata
- ✅ Handle authentication errors (401 Unauthorized)

**Configuration:**
```yaml
# hub-api-gateway/internal/config/config.go
auth:
  jwt_secret: ${JWT_SECRET}
  cache_enabled: true
  cache_ttl: 300  # 5 minutes
```

**Key Files:**
- `internal/middleware/auth_middleware.go` - JWT validation middleware
- `internal/proxy/proxy_handler.go` - Forwards user context to services
- `internal/auth/user_client.go` - Communicates with User Service

### 2. User Service (hub-user-service)

**Responsibilities:**
- ✅ Authenticate users (login)
- ✅ Generate JWT tokens
- ✅ Validate JWT tokens (for gateway)
- ✅ Manage user data

**gRPC Methods:**
```protobuf
service AuthService {
  rpc Login(LoginRequest) returns (LoginResponse);
  rpc ValidateToken(ValidateTokenRequest) returns (ValidateTokenResponse);
}
```

**Key Files:**
- `internal/grpc/auth_server.go` - gRPC authentication service
- `internal/auth/auth_service.go` - Authentication business logic
- `internal/auth/token/token_service.go` - JWT generation/validation

### 3. Monolith (HubInvestmentsServer)

**Responsibilities:**
- ✅ Extract user context from gateway metadata
- ✅ Process business logic with authenticated user context
- ❌ **No JWT validation** (trusts gateway)

**Interceptor:**
```go
// shared/grpc/server.go
type gatewayContextInterceptor struct{}

func (i *gatewayContextInterceptor) unaryInterceptor(
    ctx context.Context,
    req interface{},
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (interface{}, error) {
    // Extract user ID from gateway metadata
    md, ok := metadata.FromIncomingContext(ctx)
    if ok {
        if userIDs := md.Get("x-user-id"); len(userIDs) > 0 {
            ctx = context.WithValue(ctx, "userId", userIDs[0])
        }
        if emails := md.Get("x-user-email"); len(emails) > 0 {
            ctx = context.WithValue(ctx, "userEmail", emails[0])
        }
    }
    
    return handler(ctx, req)
}
```

**Key Files:**
- `shared/grpc/server.go` - gRPC server with context interceptor
- All handlers extract userId from context: `ctx.Value("userId").(string)`

## Security Considerations

### ✅ **Advantages**

1. **Single Point of Authentication**
   - All authentication logic is centralized in the gateway
   - Easier to audit and maintain
   - Consistent security policies across all services

2. **Performance**
   - No redundant JWT validation in downstream services
   - Token validation is cached (5-minute TTL)
   - Reduced latency for authenticated requests

3. **Flexibility**
   - Easy to change authentication strategy (OAuth, SAML, etc.)
   - Only need to update the gateway
   - Services remain decoupled from auth implementation

4. **Simplified Services**
   - Downstream services don't need JWT libraries
   - No need to manage JWT secrets in multiple services
   - Services focus on business logic

### ⚠️ **Security Requirements**

1. **Network Isolation** ⚠️ **CRITICAL**
   - ✅ Monolith and User Service are **NOT** publicly accessible
   - ✅ Only the API Gateway is exposed to the internet
   - ✅ Services communicate via Docker's internal network (`hub-network`)
   - ⚠️  **ACTION REQUIRED**: Implement Step 4.10 in TODO.md before production
   - ⚠️  **RISK**: Without network isolation, attackers can bypass authentication

2. **Trust Boundary**
   - The API Gateway is the **security boundary**
   - All requests **MUST** go through the gateway
   - Direct access to services bypasses authentication
   - Backend services trust the gateway's `x-user-id` metadata

3. **Metadata Validation**
   - Services should validate that `x-user-id` is present
   - Consider adding request signing for extra security (mTLS, API keys)
   - Monitor for suspicious metadata patterns
   - **Note**: `authorization` header is forwarded for audit/logging but NOT validated by backend services

### 🔒 **Network Security**

```yaml
# docker-compose.yml
networks:
  hub-network:
    driver: bridge
    internal: false  # Gateway needs external access
    
services:
  hub-api-gateway:
    ports:
      - "8081:8080"  # ✅ Publicly accessible
    networks:
      - hub-network
      
  hub-user-service:
    # ❌ No public ports exposed
    expose:
      - "50051"
    networks:
      - hub-network
      
  hub-monolith:
    # ❌ No public ports exposed
    expose:
      - "50060"
    networks:
      - hub-network
```

## Token Caching

The API Gateway caches token validation results to improve performance:

```go
// Cache key: token hash
// Cache value: user context (userId, email)
// TTL: 5 minutes

if cachedContext, exists := cache.Get(tokenHash); exists {
    // Use cached result (no call to User Service)
    return cachedContext
}

// Cache miss - validate with User Service
context, err := userService.ValidateToken(token)
cache.Set(tokenHash, context, 5*time.Minute)
```

**Benefits:**
- Reduces load on User Service
- Improves response time (no network call)
- Token validation happens once per 5 minutes

**Trade-offs:**
- Revoked tokens remain valid for up to 5 minutes
- Consider shorter TTL for high-security applications

## Error Handling

### Authentication Errors (401 Unauthorized)

```json
{
  "code": "UNAUTHENTICATED",
  "error": "missing authorization header"
}

{
  "code": "UNAUTHENTICATED",
  "error": "invalid or expired token"
}

{
  "code": "UNAUTHENTICATED",
  "error": "user not found or database error"
}
```

### Authorization Errors (403 Forbidden)

```json
{
  "code": "PERMISSION_DENIED",
  "error": "insufficient permissions"
}
```

## Testing

### 1. Login Test

```bash
curl -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

Expected Response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "userId": "2",
    "email": "user@example.com"
  }
}
```

### 2. Authenticated Request Test

```bash
TOKEN="eyJhbGciOiJIUzI1NiIs..."

curl -X POST http://localhost:8081/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "symbol": "AAPL",
    "order_type": "MARKET",
    "order_side": "BUY",
    "quantity": 10
  }'
```

### 3. Verify User Context Forwarding

Check monolith logs to verify user context is being extracted:

```bash
docker logs hub-monolith --tail 50 | grep userId
```

Expected: You should see userId being used in business logic

## Migration from Old Architecture

### Before (Redundant Auth)

```
Client → Gateway (validates JWT) → Monolith (validates JWT again) ❌
         ✅ Auth                     ✅ Auth (redundant!)
```

**Issues:**
- Duplicate JWT validation (performance overhead)
- JWT secret needed in multiple services
- Harder to change auth strategy
- More code to maintain

### After (Gateway-Only Auth)

```
Client → Gateway (validates JWT) → Monolith (trusts gateway) ✅
         ✅ Auth                     ✅ Extracts user context
```

**Benefits:**
- Single authentication point
- Better performance (no duplicate validation)
- Simpler service code
- Easier to maintain and update

### Changes Made

1. **Removed** `AuthInterceptor` from monolith (`HubInvestmentsServer/internal/market_data/presentation/grpc/interceptors/auth_interceptor.go`)
2. **Added** `gatewayContextInterceptor` in `HubInvestmentsServer/shared/grpc/server.go`
3. **Updated** API Gateway to forward `x-user-id` and `x-user-email` metadata
4. **Removed** JWT validation logic from monolith services

## Best Practices

### ✅ **DO**

1. **Always use the API Gateway** for external requests
2. **Validate user context** in business logic (check if userId exists)
3. **Monitor authentication metrics** (failed logins, token validation errors)
4. **Use HTTPS** in production to protect tokens in transit
5. **Rotate JWT secrets** regularly
6. **Set appropriate token expiration** (10 minutes recommended)

### ❌ **DON'T**

1. **Don't expose services directly** to the internet
2. **Don't bypass the gateway** for authenticated requests
3. **Don't store JWT secrets** in code or version control
4. **Don't use long-lived tokens** (increases security risk)
5. **Don't trust client-provided user IDs** (always use gateway metadata)

## Monitoring and Observability

### Key Metrics to Track

1. **Authentication Success Rate**
   - Track successful vs failed login attempts
   - Alert on unusual patterns (brute force attacks)

2. **Token Validation Cache Hit Rate**
   - Monitor cache effectiveness
   - Optimize TTL based on hit rate

3. **Gateway → Service Latency**
   - Measure end-to-end request time
   - Identify performance bottlenecks

4. **Authentication Errors**
   - Track 401 errors by endpoint
   - Identify problematic clients

### Logging

**API Gateway:**
```
2025/10/25 20:09:02 ✅ Token validated for user: user@example.com (2)
2025/10/25 20:09:02 📨 Proxying request: POST /api/v1/orders -> OrderService.SubmitOrder
```

**Monolith:**
```
Processing order for userId: 2
```

## Troubleshooting

### Issue: "missing authorization header"

**Cause:** Client didn't send Authorization header

**Solution:**
```bash
# Ensure Authorization header is present
curl -H "Authorization: Bearer <token>" ...
```

### Issue: "invalid or expired token"

**Cause:** Token is expired or malformed

**Solution:**
1. Login again to get a fresh token
2. Check token expiration time (default: 10 minutes)

### Issue: "user not found"

**Cause:** User doesn't exist in database

**Solution:**
1. Create the user in the User Service database
2. Verify user credentials

### Issue: Services can't communicate

**Cause:** Docker network misconfiguration

**Solution:**
```bash
# Verify all services are on the same network
docker network inspect hub-network

# Ensure services can reach each other
docker exec hub-api-gateway ping hub-monolith
docker exec hub-api-gateway ping hub-user-service
```

## Future Enhancements

### 1. **OAuth 2.0 / OpenID Connect**
- Support for third-party authentication (Google, GitHub)
- Only requires changes to API Gateway

### 2. **API Keys for Service-to-Service**
- Add API key authentication for internal services
- Separate from user authentication

### 3. **Rate Limiting per User**
- Track requests by userId
- Implement per-user rate limits

### 4. **Audit Logging**
- Log all authenticated requests
- Track user actions for compliance

### 5. **Token Refresh**
- Implement refresh tokens for longer sessions
- Reduce need for frequent re-authentication

## Conclusion

The Gateway-Based Authentication architecture provides a secure, performant, and maintainable approach to authentication in a microservices environment. By centralizing authentication in the API Gateway and using trusted metadata for downstream services, we achieve:

- ✅ **Better Performance** - No redundant JWT validation
- ✅ **Simpler Services** - Services focus on business logic
- ✅ **Easier Maintenance** - Single point of authentication
- ✅ **Improved Security** - Consistent security policies

This architecture follows industry best practices used by companies like Netflix, Uber, and Amazon in their microservices platforms.
