#!/bin/bash
set -e

echo "Building Lambda deployment package for x86_64 architecture..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Detected macOS - Building for x86_64 target architecture${NC}"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Copy Lambda function
cp lambda/lambda_function.py "$TEMP_DIR/"

# Check if requirements.txt exists and has content
if [ -f lambda/requirements.txt ] && [ -s lambda/requirements.txt ]; then
    echo "Installing Python dependencies..."
    
    # Install dependencies using pip with platform-specific flags for x86_64
    pip3 install \
        --platform manylinux2014_x86_64 \
        --target "$TEMP_DIR" \
        --implementation cp \
        --python-version 3.11 \
        --only-binary=:all: \
        --upgrade \
        -r lambda/requirements.txt
    
    echo -e "${GREEN}Dependencies installed successfully${NC}"
else
    echo "No dependencies to install"
fi

# Create zip file
cd "$TEMP_DIR"
echo "Creating deployment package..."
zip -r lambda_function.zip . -x "*.pyc" -x "*__pycache__*" -x "*.dist-info/*"

# Move zip to project root
mv lambda_function.zip "$OLDPWD/"
cd "$OLDPWD"

# Cleanup
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Lambda deployment package created: lambda_function.zip${NC}"
echo "Package size: $(du -h lambda_function.zip | cut -f1)"
echo ""
echo "The package is ready for deployment with Terraform"
