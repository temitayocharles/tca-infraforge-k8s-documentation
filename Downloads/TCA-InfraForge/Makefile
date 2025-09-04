.PHONY: help build deploy test clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build Docker images
	docker build -f Dockerfile.api -t tca-infraforge/api .
	docker build -f Dockerfile.backend -t tca-infraforge/backend .

deploy-sandbox: ## Deploy to sandbox environment
	kubectl apply -k manifests/overlays/sandbox/

deploy-stage: ## Deploy to stage environment
	kubectl apply -k manifests/overlays/stage/

deploy-prod: ## Deploy to prod environment
	kubectl apply -k manifests/overlays/prod/

test: ## Run tests
	@echo "Running tests..."

clean: ## Clean up resources
	kubectl delete -k manifests/overlays/sandbox/ || true
	kubectl delete -k manifests/overlays/stage/ || true
	kubectl delete -k manifests/overlays/prod/ || true
