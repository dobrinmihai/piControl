# PiControl Helper Makefile
# Builds binaries for Linux ARM and AMD64 architectures

# Application name and version
APP_NAME := picontrol-helper
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S_UTC')
COMMIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Go parameters
GOCMD := go
GOBUILD := $(GOCMD) build
GOCLEAN := $(GOCMD) clean
GOTEST := $(GOCMD) test
GOGET := $(GOCMD) get
GOMOD := $(GOCMD) mod

# Build flags
LDFLAGS := -ldflags="-w -s -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.CommitHash=$(COMMIT_HASH)"
CGO_ENABLED := 0

# Binary names
BINARY_LINUX_AMD64 := $(APP_NAME)-linux-amd64
BINARY_LINUX_ARM := $(APP_NAME)-linux-arm
BINARY_LINUX_ARM64 := $(APP_NAME)-linux-arm64

# Build directory
BUILD_DIR := build
DIST_DIR := dist

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: all clean build linux-amd64 linux-arm linux-arm64 test deps tidy help install-deps dev-deps release

# Default target
all: clean deps build

# Help target
help: ## Show this help message
	@echo "PiControl Helper Build System"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Clean build artifacts
clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	$(GOCLEAN)
	rm -rf $(BUILD_DIR)
	rm -rf $(DIST_DIR)
	rm -f $(BINARY_LINUX_AMD64)
	rm -f $(BINARY_LINUX_ARM)
	rm -f $(BINARY_LINUX_ARM64)
	rm -f picontrol-linux
	rm -f picontrol-linux-arm
	@echo "$(GREEN)Clean completed$(NC)"

# Download dependencies
deps: ## Download dependencies
	@echo "$(YELLOW)Downloading dependencies...$(NC)"
	$(GOMOD) download
	$(GOMOD) verify
	@echo "$(GREEN)Dependencies downloaded$(NC)"

# Tidy go modules
tidy: ## Tidy go modules
	@echo "$(YELLOW)Tidying go modules...$(NC)"
	$(GOMOD) tidy
	@echo "$(GREEN)Go modules tidied$(NC)"

# Install development dependencies
dev-deps: ## Install development dependencies
	@echo "$(YELLOW)Installing development dependencies...$(NC)"
	$(GOGET) -u golang.org/x/tools/cmd/goimports
	$(GOGET) -u github.com/golangci/golangci-lint/cmd/golangci-lint
	@echo "$(GREEN)Development dependencies installed$(NC)"

# Run tests
test: ## Run tests
	@echo "$(YELLOW)Running tests...$(NC)"
	$(GOTEST) -v ./...
	@echo "$(GREEN)Tests completed$(NC)"

# Build for Linux AMD64
linux-amd64: ## Build for Linux AMD64
	@echo "$(YELLOW)Building for Linux AMD64...$(NC)"
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_LINUX_AMD64) .
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(BINARY_LINUX_AMD64)$(NC)"

# Build for Linux ARM (32-bit)
linux-arm: ## Build for Linux ARM (32-bit)
	@echo "$(YELLOW)Building for Linux ARM (32-bit)...$(NC)"
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=arm GOARM=6 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_LINUX_ARM) .
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(BINARY_LINUX_ARM)$(NC)"

# Build for Linux ARM64
linux-arm64: ## Build for Linux ARM64
	@echo "$(YELLOW)Building for Linux ARM64...$(NC)"
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_LINUX_ARM64) .
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(BINARY_LINUX_ARM64)$(NC)"

# Build all architectures
build: linux-amd64 linux-arm linux-arm64 ## Build for all supported architectures
	@echo "$(GREEN)All binaries built successfully!$(NC)"
	@echo "$(YELLOW)Built binaries:$(NC)"
	@ls -la $(BUILD_DIR)/

# Create legacy named binaries (for backward compatibility with setup script)
legacy: build ## Create legacy named binaries
	@echo "$(YELLOW)Creating legacy named binaries...$(NC)"
	cp $(BUILD_DIR)/$(BINARY_LINUX_AMD64) picontrol-linux
	cp $(BUILD_DIR)/$(BINARY_LINUX_ARM) picontrol-linux-arm
	@echo "$(GREEN)Legacy binaries created:$(NC)"
	@echo "  picontrol-linux (AMD64)"
	@echo "  picontrol-linux-arm (ARM 32-bit)"

# Install binary to system (requires sudo)
install: linux-amd64 ## Install binary to /usr/local/bin (requires sudo)
	@echo "$(YELLOW)Installing to /usr/local/bin...$(NC)"
	sudo cp $(BUILD_DIR)/$(BINARY_LINUX_AMD64) /usr/local/bin/$(APP_NAME)
	sudo chmod +x /usr/local/bin/$(APP_NAME)
	@echo "$(GREEN)Installed: /usr/local/bin/$(APP_NAME)$(NC)"

# Build for current architecture only
local: ## Build for current architecture
	@echo "$(YELLOW)Building for current architecture...$(NC)"
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=$(CGO_ENABLED) $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(APP_NAME) .
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(APP_NAME)$(NC)"

# Run the application locally
run: local ## Build and run the application locally
	@echo "$(YELLOW)Running $(APP_NAME)...$(NC)"
	./$(BUILD_DIR)/$(APP_NAME)

# Development mode with hot reload (requires air)
dev: ## Run in development mode with hot reload
	@if command -v air >/dev/null 2>&1; then \
		echo "$(YELLOW)Starting development server with hot reload...$(NC)"; \
		air; \
	else \
		echo "$(RED)Air not found. Install with: go install github.com/cosmtrek/air@latest$(NC)"; \
		echo "$(YELLOW)Running without hot reload...$(NC)"; \
		$(MAKE) run; \
	fi

# Lint code
lint: ## Run linter
	@if command -v golangci-lint >/dev/null 2>&1; then \
		echo "$(YELLOW)Running linter...$(NC)"; \
		golangci-lint run; \
		echo "$(GREEN)Linting completed$(NC)"; \
	else \
		echo "$(RED)golangci-lint not found. Install with: make dev-deps$(NC)"; \
	fi

# Format code
fmt: ## Format code
	@echo "$(YELLOW)Formatting code...$(NC)"
	$(GOCMD) fmt ./...
	@if command -v goimports >/dev/null 2>&1; then \
		goimports -w .; \
	fi
	@echo "$(GREEN)Code formatted$(NC)"

# Check for security vulnerabilities
security: ## Check for security vulnerabilities
	@if command -v govulncheck >/dev/null 2>&1; then \
		echo "$(YELLOW)Checking for security vulnerabilities...$(NC)"; \
		govulncheck ./...; \
		echo "$(GREEN)Security check completed$(NC)"; \
	else \
		echo "$(YELLOW)Installing govulncheck...$(NC)"; \
		$(GOGET) golang.org/x/vuln/cmd/govulncheck; \
		govulncheck ./...; \
	fi

# Create distribution packages
release: clean build ## Create release packages
	@echo "$(YELLOW)Creating release packages...$(NC)"
	@mkdir -p $(DIST_DIR)

	# Create tar.gz for each architecture
	@cd $(BUILD_DIR) && tar -czf ../$(DIST_DIR)/$(APP_NAME)-$(VERSION)-linux-amd64.tar.gz $(BINARY_LINUX_AMD64)
	@cd $(BUILD_DIR) && tar -czf ../$(DIST_DIR)/$(APP_NAME)-$(VERSION)-linux-arm.tar.gz $(BINARY_LINUX_ARM)
	@cd $(BUILD_DIR) && tar -czf ../$(DIST_DIR)/$(APP_NAME)-$(VERSION)-linux-arm64.tar.gz $(BINARY_LINUX_ARM64)

	# Create checksums
	@cd $(DIST_DIR) && sha256sum *.tar.gz > checksums.txt

	@echo "$(GREEN)Release packages created in $(DIST_DIR)/:$(NC)"
	@ls -la $(DIST_DIR)/

# Show build information
info: ## Show build information
	@echo "$(YELLOW)Build Information:$(NC)"
	@echo "  App Name:     $(APP_NAME)"
	@echo "  Version:      $(VERSION)"
	@echo "  Build Time:   $(BUILD_TIME)"
	@echo "  Commit Hash:  $(COMMIT_HASH)"
	@echo "  Go Version:   $(shell $(GOCMD) version)"
	@echo "  Build Dir:    $(BUILD_DIR)"
	@echo "  Dist Dir:     $(DIST_DIR)"

# Docker build (if Dockerfile exists)
docker: ## Build Docker image
	@if [ -f Dockerfile ]; then \
		echo "$(YELLOW)Building Docker image...$(NC)"; \
		docker build -t $(APP_NAME):$(VERSION) .; \
		docker build -t $(APP_NAME):latest .; \
		echo "$(GREEN)Docker image built: $(APP_NAME):$(VERSION)$(NC)"; \
	else \
		echo "$(RED)Dockerfile not found$(NC)"; \
	fi

# Quick build and test cycle
quick: fmt lint test local ## Quick development cycle: format, lint, test, build

# CI/CD pipeline simulation
ci: clean deps fmt lint test security build ## Run CI/CD pipeline locally

# Size analysis
size: build ## Analyze binary sizes
	@echo "$(YELLOW)Binary size analysis:$(NC)"
	@ls -lh $(BUILD_DIR)/ | grep $(APP_NAME) || true
	@echo ""
	@echo "$(YELLOW)Detailed size breakdown:$(NC)"
	@for binary in $(BUILD_DIR)/$(APP_NAME)*; do \
		if [ -f "$$binary" ]; then \
			echo "$$binary:"; \
			size "$$binary" 2>/dev/null || echo "  Size command not available"; \
		fi \
	done

# Benchmark tests
bench: ## Run benchmark tests
	@echo "$(YELLOW)Running benchmark tests...$(NC)"
	$(GOTEST) -bench=. -benchmem ./...
	@echo "$(GREEN)Benchmark tests completed$(NC)"
