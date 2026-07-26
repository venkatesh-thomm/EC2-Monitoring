#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting CloudWatch Agent Installation ==="
echo "Timestamp: $(date)"

# Update system
echo "Updating system packages..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install CloudWatch Agent
echo "Downloading CloudWatch Agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

echo "Installing CloudWatch Agent..."
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb

# Verify installation
if [ ! -f /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
    echo "ERROR: CloudWatch Agent installation failed!"
    exit 1
fi
echo "CloudWatch Agent installed successfully"

# Create CloudWatch Agent configuration
echo "Creating CloudWatch Agent configuration..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
${cloudwatch_config}
EOF

# Verify configuration file
if [ ! -f /opt/aws/amazon-cloudwatch-agent/etc/config.json ]; then
    echo "ERROR: Configuration file not created!"
    exit 1
fi
echo "Configuration file created successfully"

# Start CloudWatch Agent
echo "Starting CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Wait a few seconds for agent to start
sleep 5

# Verify agent is running
echo "Verifying CloudWatch Agent status..."
AGENT_STATUS=$(/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a status -m ec2 2>&1 || echo "status check failed")

if echo "$AGENT_STATUS" | grep -q "running"; then
    echo "✓ CloudWatch Agent is running successfully"
else
    echo "WARNING: CloudWatch Agent status check output:"
    echo "$AGENT_STATUS"
fi

# Install stress tool for testing (non-blocking)
echo "Installing stress tool..."
apt-get install -y stress || echo "Warning: stress tool installation failed, but continuing..."

# Create a simple monitoring script
cat > /usr/local/bin/system-info.sh << 'SCRIPT'
#!/bin/bash
echo "=== System Information ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h)"
echo "Disk: $(df -h /)"
echo "CPU: $(top -bn1 | grep "Cpu(s)")"
SCRIPT

chmod +x /usr/local/bin/system-info.sh

# Add cron job to log system info every 5 minutes
echo "*/5 * * * * /usr/local/bin/system-info.sh >> /var/log/system-info.log 2>&1" | crontab -

echo "CloudWatch Agent installation and configuration completed!"
