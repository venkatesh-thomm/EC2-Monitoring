#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "==========================================="
echo "Starting CloudWatch Agent Installation"
echo "Timestamp: $(date)"
echo "==========================================="

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y wget unzip stress

# Install CloudWatch Agent
echo "Installing Amazon CloudWatch Agent..."

if ! rpm -q amazon-cloudwatch-agent >/dev/null 2>&1; then
    dnf install -y \
    https://s3.amazonaws.com/amazoncloudwatch-agent/redhat/amd64/latest/amazon-cloudwatch-agent.rpm
fi

# Verify installation
if [ ! -f /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
    echo "ERROR: CloudWatch Agent installation failed!"
    exit 1
fi

echo "CloudWatch Agent installed successfully."

# Create configuration
echo "Creating CloudWatch Agent configuration..."

mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

cat >/opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
${cloudwatch_config}
EOF

# Start CloudWatch Agent
echo "Starting CloudWatch Agent..."

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
    -s

sleep 10

echo "Checking CloudWatch Agent status..."

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -m ec2 \
    -a status

# Enable service
systemctl enable amazon-cloudwatch-agent

# Install stress tool
echo "Verifying stress utility..."

stress --version || echo "Stress utility installed."

# Create system information script
cat >/usr/local/bin/system-info.sh <<'SCRIPT'
#!/bin/bash

echo "========== $(date) =========="
echo
echo "Hostname:"
hostname

echo
echo "Uptime:"
uptime

echo
echo "Memory:"
free -h

echo
echo "Disk:"
df -h

echo
echo "CPU:"
top -bn1 | grep "Cpu(s)"
SCRIPT

chmod +x /usr/local/bin/system-info.sh

# Configure cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/system-info.sh >> /var/log/system-info.log 2>&1") | crontab -

echo "==========================================="
echo "CloudWatch Agent installation completed"
echo "==========================================="

systemctl status amazon-cloudwatch-agent --no-pager

echo "User data execution finished."