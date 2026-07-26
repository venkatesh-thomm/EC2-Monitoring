#!/bin/bash
# Script to verify CloudWatch Agent is running and collecting metrics
# Run this on the EC2 instance to diagnose issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CloudWatch Agent Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# 1. Check if CloudWatch Agent is installed
echo -e "${YELLOW}1. Checking CloudWatch Agent installation...${NC}"
if [ -f /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
    print_status 0 "CloudWatch Agent is installed"
    AGENT_VERSION=$(/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent --version 2>&1 | head -1)
    echo "   Version: $AGENT_VERSION"
else
    print_status 1 "CloudWatch Agent is NOT installed"
    echo -e "${RED}Please install CloudWatch Agent first${NC}"
    exit 1
fi
echo ""

# 2. Check if configuration file exists
echo -e "${YELLOW}2. Checking configuration file...${NC}"
if [ -f /opt/aws/amazon-cloudwatch-agent/etc/config.json ]; then
    print_status 0 "Configuration file exists"
    CONFIG_SIZE=$(stat -f%z /opt/aws/amazon-cloudwatch-agent/etc/config.json 2>/dev/null || stat -c%s /opt/aws/amazon-cloudwatch-agent/etc/config.json)
    echo "   Size: $CONFIG_SIZE bytes"
    
    # Validate JSON
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool /opt/aws/amazon-cloudwatch-agent/etc/config.json > /dev/null 2>&1; then
            print_status 0 "Configuration JSON is valid"
        else
            print_status 1 "Configuration JSON is INVALID"
        fi
    fi
else
    print_status 1 "Configuration file NOT found"
fi
echo ""

# 3. Check agent status
echo -e "${YELLOW}3. Checking CloudWatch Agent status...${NC}"
AGENT_STATUS_JSON=$(/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a query -m ec2 -c default -s 2>/dev/null)

if [ $? -eq 0 ]; then
    AGENT_STATUS=$(echo "$AGENT_STATUS_JSON" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$AGENT_STATUS" = "running" ]; then
        print_status 0 "CloudWatch Agent is RUNNING"
        
        # Extract additional info
        START_TIME=$(echo "$AGENT_STATUS_JSON" | grep -o '"starttime":"[^"]*"' | cut -d'"' -f4)
        VERSION=$(echo "$AGENT_STATUS_JSON" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        
        echo "   Status: $AGENT_STATUS"
        echo "   Started: $START_TIME"
        echo "   Version: $VERSION"
    else
        print_status 1 "CloudWatch Agent is NOT running (Status: $AGENT_STATUS)"
        echo -e "${YELLOW}   Try starting it with:${NC}"
        echo "   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json"
    fi
else
    print_status 1 "Cannot query CloudWatch Agent status"
fi
echo ""

# 4. Check agent logs
echo -e "${YELLOW}4. Checking CloudWatch Agent logs...${NC}"
if [ -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log ]; then
    print_status 0 "Agent log file exists"
    
    LOG_SIZE=$(stat -f%z /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log 2>/dev/null || stat -c%s /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log)
    echo "   Size: $LOG_SIZE bytes"
    
    # Check for recent errors
    RECENT_ERRORS=$(tail -100 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log | grep -i error | wc -l)
    if [ $RECENT_ERRORS -gt 0 ]; then
        echo -e "   ${RED}Found $RECENT_ERRORS recent errors${NC}"
        echo "   Last 3 errors:"
        tail -100 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log | grep -i error | tail -3 | sed 's/^/   /'
    else
        print_status 0 "No recent errors in logs"
    fi
else
    print_status 1 "Agent log file NOT found"
fi
echo ""

# 5. Check system metrics availability
echo -e "${YELLOW}5. Checking system metrics availability...${NC}"

# Check memory
if command -v free &> /dev/null; then
    print_status 0 "Memory metrics available"
    MEMORY_INFO=$(free -h | grep Mem | awk '{print "Total: "$2", Used: "$3", Free: "$4}')
    echo "   $MEMORY_INFO"
else
    print_status 1 "Cannot read memory metrics"
fi

# Check disk
if command -v df &> /dev/null; then
    print_status 0 "Disk metrics available"
    DISK_INFO=$(df -h / | tail -1 | awk '{print "Total: "$2", Used: "$3" ("$5"), Free: "$4}')
    echo "   $DISK_INFO"
    
    # Show all mounted filesystems
    echo "   Mounted filesystems:"
    df -h | grep -E '^/dev/' | awk '{print "     "$1" on "$6" - "$5" used"}' | head -5
else
    print_status 1 "Cannot read disk metrics"
fi
echo ""

# 6. Check IAM role
echo -e "${YELLOW}6. Checking IAM role and permissions...${NC}"
if command -v curl &> /dev/null; then
    IAM_ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
    
    if [ -n "$IAM_ROLE" ]; then
        print_status 0 "IAM role attached: $IAM_ROLE"
        
        # Try to get credentials
        CREDS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAM_ROLE 2>/dev/null)
        if echo "$CREDS" | grep -q "AccessKeyId"; then
            print_status 0 "IAM credentials available"
        else
            print_status 1 "IAM credentials NOT available"
        fi
    else
        print_status 1 "No IAM role attached to instance"
        echo -e "${RED}   CloudWatch Agent requires an IAM role with CloudWatchAgentServerPolicy${NC}"
    fi
else
    echo "   Cannot check IAM role (curl not available)"
fi
echo ""

# 7. Check network connectivity to CloudWatch
echo -e "${YELLOW}7. Checking network connectivity to CloudWatch...${NC}"
if command -v nc &> /dev/null || command -v telnet &> /dev/null; then
    # Get region
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
    CW_ENDPOINT="monitoring.$REGION.amazonaws.com"
    
    if timeout 5 bash -c "echo > /dev/tcp/$CW_ENDPOINT/443" 2>/dev/null; then
        print_status 0 "Can reach CloudWatch endpoint: $CW_ENDPOINT"
    else
        print_status 1 "Cannot reach CloudWatch endpoint: $CW_ENDPOINT"
        echo -e "${RED}   Check security groups and network ACLs${NC}"
    fi
else
    echo "   Cannot test connectivity (nc/telnet not available)"
fi
echo ""

# 8. Check configuration details
echo -e "${YELLOW}8. Checking configuration details...${NC}"
if [ -f /opt/aws/amazon-cloudwatch-agent/etc/config.json ]; then
    # Check if memory metrics are configured
    if grep -q "mem_used_percent" /opt/aws/amazon-cloudwatch-agent/etc/config.json; then
        print_status 0 "Memory metrics configured"
    else
        print_status 1 "Memory metrics NOT configured"
    fi
    
    # Check if disk metrics are configured
    if grep -q "disk_used_percent" /opt/aws/amazon-cloudwatch-agent/etc/config.json; then
        print_status 0 "Disk metrics configured"
    else
        print_status 1 "Disk metrics NOT configured"
    fi
    
    # Check collection interval
    INTERVAL=$(grep -o '"metrics_collection_interval":[[:space:]]*[0-9]*' /opt/aws/amazon-cloudwatch-agent/etc/config.json | head -1 | grep -o '[0-9]*')
    if [ -n "$INTERVAL" ]; then
        echo "   Collection interval: ${INTERVAL}s"
    fi
    
    # Check namespace
    NAMESPACE=$(grep -o '"namespace":[[:space:]]*"[^"]*"' /opt/aws/amazon-cloudwatch-agent/etc/config.json | cut -d'"' -f4)
    if [ -n "$NAMESPACE" ]; then
        echo "   Namespace: $NAMESPACE"
    fi
fi
echo ""

# 9. Check user-data log
echo -e "${YELLOW}9. Checking user-data execution log...${NC}"
if [ -f /var/log/user-data.log ]; then
    print_status 0 "User-data log exists"
    
    if grep -q "CloudWatch Agent is running successfully" /var/log/user-data.log; then
        print_status 0 "User-data script completed successfully"
    else
        echo -e "   ${YELLOW}User-data may not have completed successfully${NC}"
    fi
    
    # Check for errors
    if grep -qi error /var/log/user-data.log; then
        echo -e "   ${YELLOW}Found errors in user-data log:${NC}"
        grep -i error /var/log/user-data.log | tail -3 | sed 's/^/   /'
    fi
elif [ -f /var/log/cloud-init-output.log ]; then
    print_status 0 "Cloud-init log exists"
    echo "   Check: /var/log/cloud-init-output.log"
else
    print_status 1 "No user-data or cloud-init logs found"
fi
echo ""

# 10. Summary and recommendations
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Summary and Recommendations${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$AGENT_STATUS" = "running" ]; then
    echo -e "${GREEN}✓ CloudWatch Agent is running properly${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Wait 5-10 minutes for metrics to appear in CloudWatch"
    echo "2. Check CloudWatch console for CWAgent namespace metrics"
    echo "3. Verify dashboard shows memory and disk data"
    echo ""
    echo "To view metrics from CLI:"
    echo "  aws cloudwatch list-metrics --namespace CWAgent"
else
    echo -e "${RED}✗ CloudWatch Agent is NOT running${NC}"
    echo ""
    echo "To fix:"
    echo "1. Start the agent:"
    echo "   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \\"
    echo "       -a fetch-config -m ec2 -s \\"
    echo "       -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json"
    echo ""
    echo "2. Check logs for errors:"
    echo "   sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
    echo ""
    echo "3. Verify IAM role has CloudWatchAgentServerPolicy"
fi

echo ""
echo "For more help, see: TROUBLESHOOTING.md"
echo ""
