# Security Considerations - Gateway-Based Authentication

## 🔐 Overview

After removing authentication from the monolith and implementing Gateway-Based Authentication, we have a **critical security requirement** that must be addressed before production deployment.

## ⚠️ The Problem

**Backend services (User Service, Monolith) no longer validate JWT tokens.**

They trust the `x-user-id` metadata from the API Gateway:

```go
// Monolith now trusts this metadata without validation
md, ok := metadata.FromIncomingContext(ctx)
if ok {
    if userIDs := md.Get("x-user-id"); len(userIDs) > 0 {
        ctx = context.WithValue(ctx, "userId", userIDs[0])
    }
}
```

**Risk**: If backend services are exposed to the internet, an attacker can:
1. Bypass the API Gateway
2. Call backend services directly
3. Set any `x-user-id` they want
4. Impersonate any user

## ✅ The Solution: Multi-Layer Defense

See **Step 4.10** in `TODO.md` for detailed implementation strategies.

### Recommended Approach (Development → Production)

#### 1. **Development: Network Isolation (Docker)**
```yaml
# docker-compose.yml
services:
  hub-api-gateway:
    networks:
      - public
      - private
    ports:
      - "8081:8080"  # ✅ Exposed to internet
  
  hub-user-service:
    networks:
      - private  # ✅ NOT exposed to internet
    # NO ports mapping to host
  
  hub-monolith:
    networks:
      - private  # ✅ NOT exposed to internet
    # NO ports mapping to host

networks:
  public:
    driver: bridge
  private:
    driver: bridge
    internal: true  # ⚠️ CRITICAL: No external access
```

**Test**:
```bash
# Should fail (connection refused)
curl http://localhost:50051  # User Service
curl http://localhost:50060  # Monolith

# Should succeed (via gateway)
curl http://localhost:8081/api/v1/orders
```

#### 2. **Production: Mutual TLS (mTLS)**
- API Gateway presents client certificate when calling backend services
- Backend services validate client certificate (only accept gateway's cert)
- See `TODO.md` Step 4.10 for full implementation

#### 3. **Backup: API Keys / Shared Secrets**
- Gateway includes secret in gRPC metadata (`x-internal-api-key`)
- Backend services validate the secret in interceptor
- Simple but less secure than mTLS

#### 4. **Infrastructure: Firewall Rules**
- Configure firewall to only allow Gateway IP to access backend services
- AWS Security Groups, iptables, or cloud provider firewall

## 📝 About the Authorization Header

### Question: Should we keep forwarding the `Authorization` header?

**Answer: Yes, but it's optional now.**

In `proxy_handler.go` line 100:
```go
// Forward Authorization header to gRPC metadata
if authHeader := r.Header.Get("Authorization"); authHeader != "" {
    md.Set("authorization", authHeader)
}
```

**Why keep it?**
- ✅ **Audit trails**: Having the original token in logs is useful
- ✅ **Future-proofing**: If we add other services that need the token
- ✅ **Debugging**: Can trace requests with the original token
- ✅ **Minimal overhead**: It's just metadata, no performance impact

**Critical metadata** (actually used by backend services):
```go
md.Set("x-user-id", userContext.UserID)      // ⚠️ CRITICAL
md.Set("x-user-email", userContext.Email)    // ⚠️ CRITICAL
```

## 🚨 Current Status

### ✅ What's Working
- API Gateway validates JWT tokens
- API Gateway extracts user context
- API Gateway forwards `x-user-id` and `x-user-email` to backend services
- Backend services extract user context from metadata
- Authentication is centralized and simplified

### ⚠️ What's Missing (CRITICAL for Production)
- **Network isolation** to prevent direct access to backend services
- **mTLS** or **API keys** for service-to-service authentication
- **Monitoring** for unauthorized access attempts
- **Firewall rules** to restrict access

## 📋 Action Items

### Before Production Deployment
- [ ] Implement Step 4.10 from TODO.md (Service-to-Service Security)
- [ ] Choose security strategy (Network Isolation + mTLS recommended)
- [ ] Test that backend services are NOT accessible directly
- [ ] Set up monitoring and alerting for unauthorized access
- [ ] Document incident response procedures

### Testing Checklist
```bash
# 1. Test direct access to User Service (should fail)
grpcurl -plaintext localhost:50051 hub_investments.AuthService/ValidateToken

# 2. Test direct access to Monolith (should fail)
grpcurl -plaintext localhost:50060 hub_investments.OrderService/SubmitOrder

# 3. Test access via API Gateway (should succeed)
curl -H "Authorization: Bearer <token>" http://localhost:8081/api/v1/orders

# 4. Monitor logs for unauthorized access attempts
docker logs hub-monolith | grep "Unauthenticated"
docker logs hub-user-service | grep "Unauthenticated"
```

## 📚 Related Documentation

- **AUTHENTICATION_ARCHITECTURE.md** - Complete authentication flow and architecture
- **TODO.md Step 4.10** - Detailed implementation strategies for service-to-service security
- **AUTHENTICATION_CHANGES_SUMMARY.md** - Summary of authentication simplification changes

## 🎯 Summary

**The authentication simplification is complete and working**, but we have a **critical security gap** that must be addressed:

1. ✅ **Authentication works** - Gateway validates tokens, backend services trust gateway
2. ⚠️  **Security gap** - Backend services are vulnerable if exposed to internet
3. 🔒 **Solution** - Implement network isolation + mTLS (Step 4.10 in TODO.md)
4. ⏰ **Timeline** - Must be completed before production deployment (1-2 weeks)

**Priority: CRITICAL** - This is not optional for production.
