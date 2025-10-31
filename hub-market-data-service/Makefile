# Makefile for Hub Market Data Service

# Variables
APP_NAME=market-data-service
DOCKER_IMAGE=hub-market-data-service
VERSION?=latest
GO_VERSION=1.22
POSTGRES_VERSION=16
REDIS_VERSION=7

# Build variables
BUILD_DIR=bin
CMD_DIR=cmd/server
MAIN_FILE=$(CMD_DIR)/main.go

# Docker Compose
COMPOSE_FILE=deployments/docker-compose.yml

# Colors for output
COLOR_RESET=\033[0m
COLOR_BOLD=\033[1m
COLOR_GREEN=\033[32m
COLOR_YELLOW=\033[33m
COLOR_BLUE=\033[34m

.PHONY: help
help: ## Show this help message
	@echo "$(COLOR_BOLD)Hub Market Data Service - Makefile Commands$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(COLOR_GREEN)%-20s$(COLOR_RESET) %s\n", $$1, $$2}'

# ==============================================================================
# Development
# ==============================================================================

.PHONY: run
run: ## Run the service locally
	@echo "$(COLOR_BLUE)Running service locally...$(COLOR_RESET)"
	go run $(MAIN_FILE)

.PHONY: build
build: ## Build the service binary
	@echo "$(COLOR_BLUE)Building service binary...$(COLOR_RESET)"
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(APP_NAME) $(MAIN_FILE)
	@echo "$(COLOR_GREEN)✓ Binary built: $(BUILD_DIR)/$(APP_NAME)$(COLOR_RESET)"

.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(COLOR_BLUE)Cleaning build artifacts...$(COLOR_RESET)"
	rm -rf $(BUILD_DIR)
	rm -f coverage.out
	@echo "$(COLOR_GREEN)✓ Clean complete$(COLOR_RESET)"

# ==============================================================================
# Testing
# ==============================================================================

.PHONY: test
test: ## Run all tests
	@echo "$(COLOR_BLUE)Running tests...$(COLOR_RESET)"
	go test -v ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage
	@echo "$(COLOR_BLUE)Running tests with coverage...$(COLOR_RESET)"
	go test -cover -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(COLOR_GREEN)✓ Coverage report: coverage.html$(COLOR_RESET)"

.PHONY: test-integration
test-integration: ## Run integration tests (requires Docker)
	@echo "$(COLOR_BLUE)Running integration tests...$(COLOR_RESET)"
	go test -tags=integration -v ./...

.PHONY: test-unit
test-unit: ## Run unit tests only
	@echo "$(COLOR_BLUE)Running unit tests...$(COLOR_RESET)"
	go test -short -v ./...

.PHONY: test-streaming
test-streaming: ## Run streaming integration tests
	@echo "$(COLOR_BLUE)Running streaming integration tests...$(COLOR_RESET)"
	@./scripts/test_streaming.sh

.PHONY: test-streaming-client
test-streaming-client: ## Run interactive streaming client
	@echo "$(COLOR_BLUE)Starting streaming client...$(COLOR_RESET)"
	@go run scripts/test_streaming_client.go

.PHONY: test-streaming-load
test-streaming-load: ## Run streaming load test (100 clients)
	@echo "$(COLOR_BLUE)Running streaming load test...$(COLOR_RESET)"
	@go run scripts/test_streaming_load.go

.PHONY: test-streaming-stress
test-streaming-stress: ## Run streaming stress test (1000 clients)
	@echo "$(COLOR_BLUE)Running streaming stress test...$(COLOR_RESET)"
	@go run scripts/test_streaming_load.go -clients 1000 -duration 2m

# ==============================================================================
# Code Quality
# ==============================================================================

.PHONY: fmt
fmt: ## Format code
	@echo "$(COLOR_BLUE)Formatting code...$(COLOR_RESET)"
	go fmt ./...
	@echo "$(COLOR_GREEN)✓ Code formatted$(COLOR_RESET)"

.PHONY: lint
lint: ## Run linter
	@echo "$(COLOR_BLUE)Running linter...$(COLOR_RESET)"
	golangci-lint run ./...

.PHONY: vet
vet: ## Run go vet
	@echo "$(COLOR_BLUE)Running go vet...$(COLOR_RESET)"
	go vet ./...

.PHONY: check
check: fmt vet lint ## Run all code quality checks

# ==============================================================================
# Dependencies
# ==============================================================================

.PHONY: deps
deps: ## Download dependencies
	@echo "$(COLOR_BLUE)Downloading dependencies...$(COLOR_RESET)"
	go mod download
	@echo "$(COLOR_GREEN)✓ Dependencies downloaded$(COLOR_RESET)"

.PHONY: deps-tidy
deps-tidy: ## Tidy dependencies
	@echo "$(COLOR_BLUE)Tidying dependencies...$(COLOR_RESET)"
	go mod tidy
	@echo "$(COLOR_GREEN)✓ Dependencies tidied$(COLOR_RESET)"

.PHONY: deps-verify
deps-verify: ## Verify dependencies
	@echo "$(COLOR_BLUE)Verifying dependencies...$(COLOR_RESET)"
	go mod verify
	@echo "$(COLOR_GREEN)✓ Dependencies verified$(COLOR_RESET)"

# ==============================================================================
# Docker
# ==============================================================================

.PHONY: docker-build
docker-build: ## Build Docker image
	@echo "$(COLOR_BLUE)Building Docker image...$(COLOR_RESET)"
	docker build -t $(DOCKER_IMAGE):$(VERSION) --build-arg VERSION=$(VERSION) .
	@echo "$(COLOR_GREEN)✓ Docker image built: $(DOCKER_IMAGE):$(VERSION)$(COLOR_RESET)"

.PHONY: docker-run
docker-run: ## Run Docker container
	@echo "$(COLOR_BLUE)Running Docker container...$(COLOR_RESET)"
	docker run -d \
		--name $(APP_NAME) \
		-p 8080:8080 \
		-p 50051:50051 \
		-p 8082:8082 \
		--env-file .env \
		$(DOCKER_IMAGE):$(VERSION)
	@echo "$(COLOR_GREEN)✓ Container started: $(APP_NAME)$(COLOR_RESET)"

.PHONY: docker-stop
docker-stop: ## Stop Docker container
	@echo "$(COLOR_BLUE)Stopping Docker container...$(COLOR_RESET)"
	docker stop $(APP_NAME) || true
	docker rm $(APP_NAME) || true
	@echo "$(COLOR_GREEN)✓ Container stopped$(COLOR_RESET)"

.PHONY: docker-logs
docker-logs: ## View Docker container logs
	docker logs -f $(APP_NAME)

# ==============================================================================
# Docker Compose
# ==============================================================================

.PHONY: docker-compose-up
docker-compose-up: ## Start all services with Docker Compose
	@echo "$(COLOR_BLUE)Starting services with Docker Compose...$(COLOR_RESET)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(COLOR_GREEN)✓ Services started$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Run 'make docker-compose-logs' to view logs$(COLOR_RESET)"

.PHONY: docker-compose-down
docker-compose-down: ## Stop all services with Docker Compose
	@echo "$(COLOR_BLUE)Stopping services with Docker Compose...$(COLOR_RESET)"
	docker-compose -f $(COMPOSE_FILE) down
	@echo "$(COLOR_GREEN)✓ Services stopped$(COLOR_RESET)"

.PHONY: docker-compose-logs
docker-compose-logs: ## View Docker Compose logs
	docker-compose -f $(COMPOSE_FILE) logs -f

.PHONY: docker-compose-ps
docker-compose-ps: ## Show Docker Compose services status
	docker-compose -f $(COMPOSE_FILE) ps

.PHONY: docker-compose-restart
docker-compose-restart: ## Restart all services with Docker Compose
	@echo "$(COLOR_BLUE)Restarting services with Docker Compose...$(COLOR_RESET)"
	docker-compose -f $(COMPOSE_FILE) restart
	@echo "$(COLOR_GREEN)✓ Services restarted$(COLOR_RESET)"

# ==============================================================================
# Database
# ==============================================================================

.PHONY: db-setup
db-setup: ## Set up database (create database and user)
	@echo "$(COLOR_BLUE)Setting up database...$(COLOR_RESET)"
	./scripts/setup_database.sh
	@echo "$(COLOR_GREEN)✓ Database setup complete$(COLOR_RESET)"

.PHONY: db-migrate
db-migrate: ## Run database migrations
	@echo "$(COLOR_BLUE)Running database migrations...$(COLOR_RESET)"
	./scripts/migrate_data.sh
	@echo "$(COLOR_GREEN)✓ Database migrations complete$(COLOR_RESET)"

.PHONY: db-seed
db-seed: ## Seed database with initial data
	@echo "$(COLOR_BLUE)Seeding database...$(COLOR_RESET)"
	psql $(DATABASE_URL) -f scripts/seed_data.sql
	@echo "$(COLOR_GREEN)✓ Database seeded$(COLOR_RESET)"

.PHONY: db-reset
db-reset: ## Reset database (drop and recreate)
	@echo "$(COLOR_YELLOW)⚠️  This will delete all data!$(COLOR_RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(COLOR_BLUE)Resetting database...$(COLOR_RESET)"; \
		./scripts/reset_database.sh; \
		echo "$(COLOR_GREEN)✓ Database reset complete$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_YELLOW)Cancelled$(COLOR_RESET)"; \
	fi

# ==============================================================================
# Proto/gRPC
# ==============================================================================

.PHONY: proto-gen
proto-gen: ## Generate gRPC code from proto files
	@echo "$(COLOR_BLUE)Generating gRPC code...$(COLOR_RESET)"
	protoc --go_out=. --go_opt=paths=source_relative \
		--go-grpc_out=. --go-grpc_opt=paths=source_relative \
		internal/infrastructure/grpc/proto/*.proto
	@echo "$(COLOR_GREEN)✓ gRPC code generated$(COLOR_RESET)"

# ==============================================================================
# Utilities
# ==============================================================================

.PHONY: install-tools
install-tools: ## Install development tools
	@echo "$(COLOR_BLUE)Installing development tools...$(COLOR_RESET)"
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "$(COLOR_GREEN)✓ Tools installed$(COLOR_RESET)"

.PHONY: version
version: ## Show version information
	@echo "$(COLOR_BOLD)Version Information$(COLOR_RESET)"
	@echo "App Version:    $(VERSION)"
	@echo "Go Version:     $(shell go version)"
	@echo "Docker Version: $(shell docker --version)"

.PHONY: env-example
env-example: ## Create .env.example file
	@echo "$(COLOR_BLUE)Creating .env.example...$(COLOR_RESET)"
	@cat > .env.example <<EOF
# Server Configuration
HTTP_PORT=8080
GRPC_PORT=50051
WEBSOCKET_PORT=8082

# Database Configuration
DATABASE_URL=postgres://market_data_user:password@localhost:5432/hub_market_data_service?sslmode=disable

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Cache Configuration
CACHE_TTL=5m
CACHE_ENABLED=true

# WebSocket Configuration
WS_MAX_CONNECTIONS=10000
WS_IDLE_TIMEOUT=30m

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Metrics
METRICS_ENABLED=true
METRICS_PORT=9090
EOF
	@echo "$(COLOR_GREEN)✓ .env.example created$(COLOR_RESET)"

# ==============================================================================
# CI/CD
# ==============================================================================

.PHONY: ci
ci: deps-verify check test ## Run CI pipeline (verify, check, test)
	@echo "$(COLOR_GREEN)✓ CI pipeline complete$(COLOR_RESET)"

.PHONY: ci-full
ci-full: deps-verify check test test-integration docker-build ## Run full CI pipeline
	@echo "$(COLOR_GREEN)✓ Full CI pipeline complete$(COLOR_RESET)"

# ==============================================================================
# Default Target
# ==============================================================================

.DEFAULT_GOAL := help

