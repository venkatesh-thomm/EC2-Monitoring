#!/bin/bash
set -e

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Change to the project root directory (parent of scripts)
cd "$SCRIPT_DIR/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}  Destroy EC2 Monitoring Infrastructure${NC}"
echo -e "${RED}========================================${NC}"
echo ""

echo -e "${YELLOW}WARNING: This will destroy all resources created by this project!${NC}"
echo ""
echo "Resources to be destroyed:"
echo "  - EC2 instance"
echo "  - VPC and networking"
echo "  - CloudWatch alarms and dashboard"
echo "  - SNS topic"
echo "  - Lambda function"
echo "  - IAM roles and policies"
echo "  - CloudWatch log groups"
echo ""

read -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Destruction cancelled${NC}"
    exit 0
fi

echo ""
read -p "Type 'destroy' to confirm: " confirm2

if [ "$confirm2" != "destroy" ]; then
    echo -e "${GREEN}Destruction cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Destroying infrastructure...${NC}"
terraform destroy -auto-approve

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All resources destroyed${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Clean up local files
echo -e "${YELLOW}Cleaning up local files...${NC}"
rm -f terraform.tfstate*
rm -f tfplan
rm -f lambda_function.zip

echo -e "${GREEN}Cleanup complete!${NC}"
