# HubInvestments Project
## API Gateway + Microservices Architecture

---

## 🚀 Quick Start

### Start All Services
```bash
./start_all_services.sh
```

### Stop All Services
```bash
./stop_all_services.sh
```

### Run Tests
```bash
cd HubInvestmentsServer
./test_step_4_6_6_complete.sh
```

---

## 📦 Services

| Service | Port | Protocol | Status |
|---------|------|----------|--------|
| **API Gateway** | 8080 | HTTP | ✅ Required |
| **Monolith** | 50060 | gRPC | ✅ Required |
| **User Service** | 50051 | gRPC | ⚠️ Optional |

---

## 🧪 Quick Tests

```bash
# Health check
curl http://localhost:8080/health

# Market data
curl http://localhost:8080/api/v1/market-data/AAPL

# Full test suite
cd HubInvestmentsServer && ./test_step_4_6_6_complete.sh
```

---

## 📚 Documentation

- **[Service Startup Guide](HubInvestmentsServer/docs/SERVICE_STARTUP_GUIDE.md)** - Detailed startup instructions
- **[Step 4.6.6 Complete Summary](HubInvestmentsServer/docs/STEP_4_6_6_COMPLETE_SUMMARY.md)** - Integration testing results
- **[Step 4.6.6 Final Report](HubInvestmentsServer/docs/STEP_4_6_6_FINAL_REPORT.md)** - Comprehensive report
- **[TODO](HubInvestmentsServer/TODO.md)** - Project roadmap

---

## 🔧 Configuration

### JWT Secret (Must Match Across All Services)
```
HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^
```

### Service Addresses
- Monolith gRPC: `localhost:50060`
- User Service gRPC: `localhost:50051`
- Gateway HTTP: `localhost:8080`

---

## 📊 Current Status

**Step 4.6.6**: ✅ **100% COMPLETE**
- ✅ All scenarios tested (4/4)
- ✅ Configuration complete (3/3)
- ✅ Implementation tasks done (7/7)
- ✅ Testing verified (13/13)
- ✅ Deliverables created (6/6)

---

## 🐛 Troubleshooting

### Gateway Won't Start
```bash
# Check JWT_SECRET
export JWT_SECRET='HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$%^'

# Or use startup script
./start_all_services.sh
```

### User Service Database Error
This is **OK** - user service is optional for Step 4.6.6 testing.

### View Logs
```bash
tail -f /tmp/monolith.log
tail -f /tmp/gateway.log
tail -f /tmp/user-service.log
```

---

## 🎯 Next Steps

**Step 4.7**: API Gateway - Security Features
- Rate limiting
- Request size limits
- CORS policy
- IP whitelisting

---

**Last Updated**: October 20, 2025

