.PHONY: help start stop restart logs ps build clean test-all test-gateway test-user test-monolith

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Hub Investments Platform - Docker Compose Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  1. make start          # Start all services"
	@echo "  2. make ps             # Check service status"
	@echo "  3. make test-all       # Run all tests"
	@echo "  4. make logs           # View logs"
	@echo "  5. make stop           # Stop all services"

# ============================================================================
# Service Management
# ============================================================================

start: check-env ## Start all services
	@echo "$(GREEN)Starting Hub Investments Platform...$(NC)"
	@docker compose up -d
	@echo ""
	@echo "$(GREEN)✅ Services started!$(NC)"
	@echo ""
	@make ps
	@echo ""
	@echo "$(BLUE)📡 Service Endpoints:$(NC)"
	@echo "  API Gateway:       http://localhost:8081"
	@echo "  Monolith HTTP:     http://localhost:8080"
	@echo "  Monolith gRPC:     localhost:50060"
	@echo "  User Service:      localhost:50051 (gRPC)"
	@echo "  Market Data:       localhost:50054 (gRPC)"
	@echo "  RabbitMQ UI:       http://localhost:15672 (guest/guest)"
	@echo ""
	@echo "$(BLUE)🔍 Health Checks:$(NC)"
	@echo "  Gateway:           http://localhost:8081/health"
	@echo "  Monolith:          http://localhost:8080/health"
	@echo "  User Service:      http://localhost:8082/health"
	@echo "  Market Data:       grpcurl -plaintext localhost:50054 list"
	@echo ""
	@echo "$(YELLOW)⏳ Waiting for services to be ready...$(NC)"
	@sleep 5
	@make health-check

stop: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@docker compose down
	@echo "$(GREEN)✅ Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(YELLOW)Restarting all services...$(NC)"
	@make stop
	@sleep 2
	@make start

logs: ## View logs from all services
	@docker compose logs -f

logs-gateway: ## View API Gateway logs
	@docker compose logs -f hub-api-gateway

logs-user: ## View User Service logs
	@docker compose logs -f hub-user-service

logs-monolith: ## View Monolith logs
	@docker compose logs -f hub-monolith

logs-market-data: ## View Market Data Service logs
	@docker compose logs -f hub-market-data-service

ps: ## Show service status
	@docker compose ps

# ============================================================================
# Build Commands
# ============================================================================

build: ## Build all services
	@echo "$(BLUE)Building all services...$(NC)"
	@docker compose build \
		--build-arg VERSION=$(shell git describe --tags --always 2>/dev/null || echo "dev") \
		--build-arg BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
		--build-arg GIT_COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	@echo "$(GREEN)✅ Build complete$(NC)"

build-no-cache: ## Build all services without cache
	@echo "$(BLUE)Building all services (no cache)...$(NC)"
	@docker compose build --no-cache \
		--build-arg VERSION=$(shell git describe --tags --always 2>/dev/null || echo "dev") \
		--build-arg BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
		--build-arg GIT_COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	@echo "$(GREEN)✅ Build complete$(NC)"

# ============================================================================
# Testing Commands
# ============================================================================

test-all: test-health test-gateway test-user test-monolith ## Run all tests
	@echo ""
	@echo "$(GREEN)✅ All tests completed!$(NC)"

test-health: ## Test health endpoints
	@echo "$(BLUE)Testing health endpoints...$(NC)"
	@echo -n "  Gateway:      "
	@curl -sf http://localhost:8081/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@echo -n "  Monolith:     "
	@curl -sf http://localhost:8080/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@echo -n "  User Service: "
	@curl -sf http://localhost:8082/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"

test-gateway: ## Test API Gateway
	@echo "$(BLUE)Testing API Gateway...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Testing Gateway Health$(NC)"
	@curl -s http://localhost:8081/health | jq '.' || echo "$(RED)Failed$(NC)"
	@echo ""
	@echo "$(YELLOW)2. Testing Gateway Metrics$(NC)"
	@curl -s http://localhost:8081/metrics | head -20
	@echo ""

test-user: ## Test User Service (login flow)
	@echo "$(BLUE)Testing User Service via Gateway...$(NC)"
	@echo ""
	@echo "$(YELLOW)Attempting login...$(NC)"
	@curl -X POST http://localhost:8081/api/v1/auth/login \
		-H "Content-Type: application/json" \
		-d '{"email":"test@example.com","password":"password123"}' \
		-s | jq '.' || echo "$(RED)Login failed (expected if user doesn't exist)$(NC)"
	@echo ""

test-monolith: ## Test Monolith endpoints
	@echo "$(BLUE)Testing Monolith...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Testing Monolith Health$(NC)"
	@curl -s http://localhost:8080/health | jq '.' || echo "$(RED)Failed$(NC)"
	@echo ""
	@echo "$(YELLOW)2. Testing Swagger Documentation$(NC)"
	@curl -sf http://localhost:8080/swagger/ > /dev/null && echo "$(GREEN)✓ Swagger available$(NC)" || echo "$(RED)✗ Swagger unavailable$(NC)"
	@echo ""

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@echo ""
	@echo "$(YELLOW)Test 1: Gateway → User Service (Login)$(NC)"
	@curl -X POST http://localhost:8081/api/v1/auth/login \
		-H "Content-Type: application/json" \
		-d '{"email":"test@test.com","password":"test123"}' \
		-w "\nHTTP Status: %{http_code}\n" \
		-s | head -10
	@echo ""
	@echo "$(YELLOW)Test 2: Gateway → Monolith (Market Data)$(NC)"
	@curl -s http://localhost:8081/api/v1/market-data/AAPL \
		-w "\nHTTP Status: %{http_code}\n" | head -10
	@echo ""

# ============================================================================
# Utility Commands
# ============================================================================

clean: ## Stop services and remove volumes
	@echo "$(RED)⚠️  This will remove all data!$(NC)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "$(GREEN)✅ Cleaned$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

shell-gateway: ## Open shell in gateway container
	@docker exec -it hub-api-gateway /bin/sh

shell-user: ## Open shell in user service container
	@docker exec -it hub-user-service /bin/sh

shell-monolith: ## Open shell in monolith container
	@docker exec -it hub-monolith /bin/sh

shell-market-data: ## Open shell in market data service container
	@docker exec -it hub-market-data-service /bin/sh

shell-db-monolith: ## Open PostgreSQL shell for monolith
	@docker exec -it hub-monolith-db psql -U yanrodrigues

shell-db-user: ## Open PostgreSQL shell for user service
	@docker exec -it hub-user-db psql -U hubuser -d hub_user_service

shell-db-market-data: ## Open PostgreSQL shell for market data service
	@docker exec -it hub-market-data-db psql -U market_data_user -d hub_market_data

check-env: ## Check if .env file exists
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found!$(NC)"; \
		echo "$(YELLOW)Creating .env from template...$(NC)"; \
		echo "JWT_SECRET=HubInv3stm3nts_S3cur3_JWT_K3y_2024_!@#$$%^" > .env; \
		echo "MONOLITH_DB_USER=yanrodrigues" >> .env; \
		echo "MONOLITH_DB_PASSWORD=" >> .env; \
		echo "MONOLITH_DB_NAME=yanrodrigues" >> .env; \
		echo "USER_DB_USER=hubuser" >> .env; \
		echo "USER_DB_PASSWORD=hubpassword" >> .env; \
		echo "USER_DB_NAME=hub_user_service" >> .env; \
		echo "RABBITMQ_USER=guest" >> .env; \
		echo "RABBITMQ_PASS=guest" >> .env; \
		echo "$(GREEN)✅ .env file created$(NC)"; \
	fi

health-check: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@for i in 1 2 3 4 5; do \
		echo -n "  Attempt $$i/5: "; \
		if curl -sf http://localhost:8081/health > /dev/null && \
		   curl -sf http://localhost:8080/health > /dev/null && \
		   curl -sf http://localhost:8082/health > /dev/null; then \
			echo "$(GREEN)✓ All services healthy$(NC)"; \
			exit 0; \
		else \
			echo "$(YELLOW)⏳ Waiting...$(NC)"; \
			sleep 3; \
		fi; \
	done; \
	echo "$(RED)✗ Some services are not healthy yet$(NC)"; \
	echo "$(YELLOW)Run 'make ps' to check status$(NC)"

stats: ## Show resource usage
	@docker stats --no-stream hub-api-gateway hub-user-service hub-monolith hub-market-data-service

network-inspect: ## Inspect hub-network
	@docker network inspect hub-network | jq '.[0].Containers'

.DEFAULT_GOAL := help

