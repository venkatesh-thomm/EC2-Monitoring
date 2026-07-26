#!/bin/bash
# Script to fix CloudWatch Agent by recreating the instance
# This ensures the updated user_data script runs

set -e

export AWS_PROFILE=personal_new

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Fix CloudWatch Agent${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Problem:${NC} The instance was updated but not recreated,"
echo "so the new user_data script with CloudWatch Agent didn't run."
echo ""
echo -e "${YELLOW}Solution:${NC} Force Terraform to recreate the instance."
echo ""
echo "This will:"
echo "  1. Terminate the current instance"
echo "  2. Create a new instance with the updated user_data"
echo "  3. CloudWatch Agent will install and start automatically"
echo "  4. Metrics will appear within 10 minutes"
echo ""

read -p "Do you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Tainting the EC2 instance to force recreation...${NC}"
terraform taint aws_instance.monitored

echo ""
echo -e "${YELLOW}Applying changes...${NC}"
terraform apply -auto-approve

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Instance Recreated!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get new instance ID
NEW_INSTANCE_ID=$(terraform output -raw instance_id)
echo "New instance ID: $NEW_INSTANCE_ID"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Wait 10 minutes for CloudWatch Agent to install and start"
echo "2. Run verification script:"
echo "   ./verify_agent_from_local.sh"
echo ""
echo "3. Check dashboard:"
echo "   $(terraform output -raw dashboard_url)"
echo ""
