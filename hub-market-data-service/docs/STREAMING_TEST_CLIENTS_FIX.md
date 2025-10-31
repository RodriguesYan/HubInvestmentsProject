# 🔧 Streaming Test Clients - Package Conflict Fix

**Date**: October 30, 2025  
**Issue**: Linter errors due to conflicting `main` package declarations  
**Status**: ✅ RESOLVED

---

## 🐛 Problem

Both streaming test files were in the same directory with `package main`, causing compilation errors:

```
hub-market-data-service/scripts/
├── test_streaming_client.go  (package main)
└── test_streaming_load.go    (package main)
```

**Errors**:
- `serverAddrFlag redeclared in this block`
- `durationFlag redeclared in this block`
- `main redeclared in this block`

---

## ✅ Solution

Reorganized the test files into separate subdirectories, following Go's standard practice for multiple executables:

```
hub-market-data-service/scripts/
├── test_streaming_client/
│   └── main.go              (streaming client test)
├── test_streaming_load/
│   └── main.go              (load test)
├── run_streaming_tests.sh   (NEW: unified test runner)
└── test_streaming.sh        (existing: automated integration tests)
```

---

## 📁 New Structure

### 1. Test Streaming Client
**Location**: `scripts/test_streaming_client/main.go`

**Purpose**: Interactive streaming client for manual testing

**Usage**:
```bash
cd scripts/test_streaming_client
go run main.go --symbols AAPL,GOOGL,MSFT --duration 60s
```

**Features**:
- Subscribe to multiple symbols
- Receive real-time quotes
- Monitor heartbeats
- Graceful shutdown (Ctrl+C)
- Detailed statistics

### 2. Test Streaming Load
**Location**: `scripts/test_streaming_load/main.go`

**Purpose**: Load testing with multiple concurrent clients

**Usage**:
```bash
cd scripts/test_streaming_load
go run main.go --clients 100 --duration 30s
```

**Features**:
- Concurrent client connections
- Real-time progress updates
- Connection success/failure tracking
- Quote and heartbeat counters
- Performance metrics (quotes/second)

### 3. Unified Test Runner (NEW)
**Location**: `scripts/run_streaming_tests.sh`

**Purpose**: Easy-to-use wrapper for running streaming tests

**Usage**:
```bash
# Run single client test
./scripts/run_streaming_tests.sh client

# Run load test
./scripts/run_streaming_tests.sh load

# Run both tests
./scripts/run_streaming_tests.sh both

# With custom parameters
./scripts/run_streaming_tests.sh client --symbols AAPL,TSLA --duration 2m
./scripts/run_streaming_tests.sh load --clients 200 --duration 5m
```

**Features**:
- Service health check before running tests
- Color-coded output
- Help documentation
- Parameter forwarding

---

## 🎯 Commands Reference

### Quick Start

```bash
# Make the runner executable (one-time)
chmod +x scripts/run_streaming_tests.sh

# Run streaming client test
./scripts/run_streaming_tests.sh client

# Run load test
./scripts/run_streaming_tests.sh load
```

### Advanced Usage

```bash
# Single client with custom symbols
./scripts/run_streaming_tests.sh client \
  --symbols AAPL,GOOGL,MSFT,TSLA,NVDA \
  --duration 2m

# Load test with 500 concurrent clients
./scripts/run_streaming_tests.sh load \
  --clients 500 \
  --duration 5m \
  --symbols 10

# Run both tests with custom duration
./scripts/run_streaming_tests.sh both --duration 1m
```

### Direct Execution

```bash
# Run client test directly
cd scripts/test_streaming_client
go run main.go --server localhost:50054 --symbols AAPL,GOOGL --duration 30s

# Run load test directly
cd scripts/test_streaming_load
go run main.go --server localhost:50054 --clients 100 --duration 30s
```

---

## 📊 Test Output Examples

### Streaming Client Test
```
🚀 Starting streaming client test
   Server: localhost:50054
   Symbols: AAPL,GOOGL,MSFT
   Duration: 30s

📡 Subscribing to 3 symbols...
✅ Subscription sent

📊 Receiving quotes...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 [AAPL] Apple Inc.: $175.23 (1.25%) | Vol: 1234567 | Cap: $2.75T
📈 [GOOGL] Alphabet Inc.: $142.89 (-0.45%) | Vol: 987654 | Cap: $1.85T
💓 Heartbeat #1
📈 [MSFT] Microsoft Corporation: $378.45 (0.87%) | Vol: 654321 | Cap: $2.81T
...

⏰ Test duration completed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Duration: 30.123s
Heartbeats: 1
Total Quotes: 24

Quotes by Symbol:
  AAPL: 8 quotes (0.27 quotes/sec)
  GOOGL: 8 quotes (0.27 quotes/sec)
  MSFT: 8 quotes (0.27 quotes/sec)

✅ Test completed successfully!
```

### Load Test
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         Market Data Service - Load Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Server:           localhost:50054
Concurrent Clients: 100
Duration:         30s
Symbols/Client:   5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 Starting 100 concurrent clients...
   Started 10/100 clients
   Started 20/100 clients
   ...
   Started 100/100 clients
✅ All clients started

📊 [5s] Conns: 100✓ 0✗ | Quotes: 125 (25.0/s) | Heartbeats: 0
📊 [10s] Conns: 100✓ 0✗ | Quotes: 250 (25.0/s) | Heartbeats: 0
...

⏰ Test duration completed, waiting for clients to finish...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    Final Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Duration:        30.456s
Target Clients:       100
Successful Conns:     100 (100.0%)
Failed Conns:         0 (0.0%)

Total Quotes:         750
Total Heartbeats:     100
Total Errors:         0

Quotes/Second:        24.63
Quotes/Client:        7.50
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Load test completed successfully!
```

---

## 🔍 Verification

### Check No Linter Errors
```bash
cd hub-market-data-service
go vet ./scripts/...
# Output: (no errors)
```

### Verify Structure
```bash
tree scripts/
# Output:
# scripts/
# ├── test_streaming_client/
# │   └── main.go
# ├── test_streaming_load/
# │   └── main.go
# ├── run_streaming_tests.sh
# └── test_streaming.sh
```

### Test Compilation
```bash
# Client test
cd scripts/test_streaming_client && go build -o /dev/null main.go
# Success!

# Load test
cd scripts/test_streaming_load && go build -o /dev/null main.go
# Success!
```

---

## 📝 Files Modified

### Created
1. ✅ `scripts/test_streaming_client/` (directory)
2. ✅ `scripts/test_streaming_load/` (directory)
3. ✅ `scripts/run_streaming_tests.sh` (unified test runner)
4. ✅ `docs/STREAMING_TEST_CLIENTS_FIX.md` (this document)

### Moved
1. ✅ `scripts/test_streaming_client.go` → `scripts/test_streaming_client/main.go`
2. ✅ `scripts/test_streaming_load.go` → `scripts/test_streaming_load/main.go`

### Updated
1. ✅ `README.md` - Updated streaming test documentation

---

## 🎓 Why This Structure?

### Go Best Practices
1. **One `package main` per directory**: Prevents symbol conflicts
2. **`main.go` naming**: Standard convention for executable packages
3. **Separate directories for executables**: Clear organization

### Benefits
1. ✅ No compilation errors
2. ✅ Clear separation of concerns
3. ✅ Easy to build/run independently
4. ✅ Can be built as standalone binaries
5. ✅ Better IDE support

### Example: Building Standalone Binaries
```bash
# Build client test binary
go build -o bin/streaming-client scripts/test_streaming_client/main.go

# Build load test binary
go build -o bin/streaming-load scripts/test_streaming_load/main.go

# Run binaries
./bin/streaming-client --symbols AAPL,GOOGL --duration 1m
./bin/streaming-load --clients 200 --duration 2m
```

---

## ✅ Summary

**Problem**: Package conflicts in streaming test files  
**Solution**: Reorganized into separate subdirectories  
**Result**: Clean compilation, better organization, easier usage

**New Features**:
- ✅ Unified test runner script (`run_streaming_tests.sh`)
- ✅ No linter errors
- ✅ Better documentation
- ✅ Easier to use and maintain

---

**Status**: ✅ COMPLETE - All linter errors resolved!


