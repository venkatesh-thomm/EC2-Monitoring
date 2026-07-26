.PHONY: help init build plan deploy destroy clean test

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform init

build: ## Build Lambda deployment package
	chmod +x scripts/build_lambda.sh
	./scripts/build_lambda.sh

plan: build ## Create Terraform plan
	terraform plan

deploy: ## Deploy infrastructure
	chmod +x scripts/deploy.sh
	./scripts/deploy.sh

destroy: ## Destroy all infrastructure
	chmod +x scripts/destroy.sh
	./scripts/destroy.sh

clean: ## Clean up local files
	rm -f lambda_function.zip
	rm -f tfplan
	rm -rf .terraform/
	rm -f .terraform.lock.hcl

test: ## Show test commands
	@echo "To test the monitoring setup:"
	@echo ""
	@echo "1. SSH to the EC2 instance:"
	@echo "   aws ssm start-session --target <instance-id>"
	@echo ""
	@echo "2. Test CPU alarm:"
	@echo "   sudo stress --cpu \$$(nproc) --timeout 300s"
	@echo ""
	@echo "3. Test memory alarm:"
	@echo "   sudo stress --vm 1 --vm-bytes 512M --timeout 300s"
	@echo ""
	@echo "4. Check CloudWatch console for alarms and dashboard"

validate: ## Validate Terraform configuration
	terraform validate

fmt: ## Format Terraform files
	terraform fmt -recursive

outputs: ## Show Terraform outputs
	terraform output
