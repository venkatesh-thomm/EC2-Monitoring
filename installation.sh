# Update the system
sudo yum update -y

# Install required package
sudo yum install -y yum-utils

# Install  zip and unzip
sudo yum install -y zip unzip

# Add the HashiCorp repository
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Install Terraform
sudo yum install -y terraform

# Verify the installation
terraform version