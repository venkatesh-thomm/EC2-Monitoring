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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  EC2 CloudWatch Monitoring Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

# Check if pip3 is installed
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}Error: pip3 is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials are not configured${NC}"
    echo "Please configure AWS credentials using 'aws configure'"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars with your configuration before continuing${NC}"
    echo "Required: Set your email address for alarm notifications"
    exit 1
fi

# Build Lambda package
echo -e "${YELLOW}Building Lambda deployment package...${NC}"
chmod +x scripts/build_lambda.sh
./scripts/build_lambda.sh

if [ ! -f "lambda_function.zip" ]; then
    echo -e "${RED}Error: Lambda package was not created${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Lambda package built successfully${NC}"
echo ""

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

echo -e "${GREEN}✓ Configuration is valid${NC}"
echo ""

# Plan deployment
echo -e "${YELLOW}Creating deployment plan...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Ready to deploy!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will create the following resources:"
echo "  - VPC and networking components"
echo "  - EC2 instance with CloudWatch Agent"
echo "  - CloudWatch alarms and dashboard"
echo "  - SNS topic for notifications"
echo "  - Lambda function for auto-remediation"
echo ""
read -p "Do you want to proceed with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Apply Terraform
echo ""
echo -e "${YELLOW}Deploying infrastructure...${NC}"
terraform apply tfplan

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Display outputs
echo -e "${BLUE}Important Information:${NC}"
terraform output

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Check your email and confirm the SNS subscription"
echo "2. Wait 5-10 minutes for CloudWatch Agent to start reporting metrics"
echo "3. Access the CloudWatch Dashboard using the URL above"
echo "4. Test alarms by running stress tests on the EC2 instance:"
echo "   - SSH to the instance"
echo "   - Run: sudo stress --cpu \$(nproc) --timeout 300s"
echo ""
echo -e "${GREEN}Monitoring is now active!${NC}"
