#!/bin/bash
# Script to verify CloudWatch Agent from your local machine
# Uses AWS_PROFILE=personal_new

set -e

export AWS_PROFILE=personal_new

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CloudWatch Agent Verification${NC}"
echo -e "${BLUE}  Profile: $AWS_PROFILE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get instance ID
INSTANCE_ID=$(terraform output -raw instance_id)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")

echo -e "${YELLOW}Instance ID:${NC} $INSTANCE_ID"
echo -e "${YELLOW}Region:${NC} $REGION"
echo ""

# 1. Check instance state
echo -e "${BLUE}1. Checking instance state...${NC}"
INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)

LAUNCH_TIME=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].LaunchTime' \
    --output text)

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

if [ "$INSTANCE_STATE" = "running" ]; then
    echo -e "${GREEN}✓${NC} Instance is running"
    echo "  Launch time: $LAUNCH_TIME"
    echo "  Public IP: $PUBLIC_IP"
    
    # Calculate uptime
    LAUNCH_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAUNCH_TIME%+*}" "+%s" 2>/dev/null || echo "0")
    CURRENT_EPOCH=$(date +%s)
    UPTIME_SECONDS=$((CURRENT_EPOCH - LAUNCH_EPOCH))
    UPTIME_MINUTES=$((UPTIME_SECONDS / 60))
    
    echo "  Uptime: ${UPTIME_MINUTES} minutes"
    
    if [ $UPTIME_MINUTES -lt 10 ]; then
        echo -e "${YELLOW}  ⚠ Instance recently started. CloudWatch Agent may still be initializing.${NC}"
        echo -e "${YELLOW}  ⚠ Wait at least 10 minutes for metrics to appear.${NC}"
    fi
else
    echo -e "${RED}✗${NC} Instance is $INSTANCE_STATE"
    exit 1
fi
echo ""

# 2. Check IAM role
echo -e "${BLUE}2. Checking IAM role...${NC}"
IAM_ROLE=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
    --output text)

if [ -n "$IAM_ROLE" ]; then
    echo -e "${GREEN}✓${NC} IAM role attached"
    echo "  Role: $IAM_ROLE"
else
    echo -e "${RED}✗${NC} No IAM role attached"
fi
echo ""

# 3. Check for CWAgent metrics
echo -e "${BLUE}3. Checking for CloudWatch metrics...${NC}"
METRICS=$(aws cloudwatch list-metrics \
    --namespace CWAgent \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID \
    --query 'Metrics[*].MetricName' \
    --output text)

if [ -n "$METRICS" ]; then
    echo -e "${GREEN}✓${NC} CloudWatch Agent is publishing metrics!"
    echo ""
    echo "Available metrics:"
    echo "$METRICS" | tr '\t' '\n' | sort | sed 's/^/  - /'
    
    # Check for memory and disk specifically
    if echo "$METRICS" | grep -q "mem_used_percent"; then
        echo -e "${GREEN}✓${NC} Memory metrics available"
    else
        echo -e "${RED}✗${NC} Memory metrics NOT found"
    fi
    
    if echo "$METRICS" | grep -q "disk_used_percent"; then
        echo -e "${GREEN}✓${NC} Disk metrics available"
    else
        echo -e "${RED}✗${NC} Disk metrics NOT found"
    fi
else
    echo -e "${YELLOW}⚠${NC} No CWAgent metrics found yet"
    echo "  This is normal if the instance just started."
    echo "  CloudWatch Agent needs 5-10 minutes to start and publish metrics."
fi
echo ""

# 4. Check for recent metric data
if [ -n "$METRICS" ]; then
    echo -e "${BLUE}4. Checking recent memory data...${NC}"
    
    MEMORY_DATA=$(aws cloudwatch get-metric-statistics \
        --namespace CWAgent \
        --metric-name mem_used_percent \
        --dimensions Name=InstanceId,Value=$INSTANCE_ID \
        --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-30M +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 300 \
        --statistics Average \
        --query 'Datapoints[*].[Timestamp,Average]' \
        --output text 2>/dev/null)
    
    if [ -n "$MEMORY_DATA" ]; then
        echo -e "${GREEN}✓${NC} Memory data available"
        echo "Recent memory usage:"
        echo "$MEMORY_DATA" | tail -5 | awk '{print "  " $1 " - " $2 "%"}'
    else
        echo -e "${YELLOW}⚠${NC} No memory data points yet"
    fi
    echo ""
    
    echo -e "${BLUE}5. Checking recent disk data...${NC}"
    
    DISK_DATA=$(aws cloudwatch get-metric-statistics \
        --namespace CWAgent \
        --metric-name disk_used_percent \
        --dimensions Name=InstanceId,Value=$INSTANCE_ID Name=path,Value=/ \
        --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-30M +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 300 \
        --statistics Average \
        --query 'Datapoints[*].[Timestamp,Average]' \
        --output text 2>/dev/null)
    
    if [ -n "$DISK_DATA" ]; then
        echo -e "${GREEN}✓${NC} Disk data available"
        echo "Recent disk usage:"
        echo "$DISK_DATA" | tail -5 | awk '{print "  " $1 " - " $2 "%"}'
    else
        echo -e "${YELLOW}⚠${NC} No disk data points yet"
    fi
    echo ""
fi

# 6. Check alarm states
echo -e "${BLUE}6. Checking CloudWatch alarms...${NC}"
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix ec2-monitoring \
    --query 'MetricAlarms[*].[AlarmName,StateValue]' \
    --output text)

if [ -n "$ALARMS" ]; then
    echo "$ALARMS" | while read -r alarm_name state; do
        if [ "$state" = "OK" ]; then
            echo -e "  ${GREEN}✓${NC} $alarm_name: $state"
        elif [ "$state" = "INSUFFICIENT_DATA" ]; then
            echo -e "  ${YELLOW}⚠${NC} $alarm_name: $state (waiting for data)"
        else
            echo -e "  ${RED}✗${NC} $alarm_name: $state"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} No alarms found"
fi
echo ""

# 7. SSH command to check agent directly
echo -e "${BLUE}7. To check agent status directly on instance:${NC}"
echo ""
echo "SSH to instance:"
echo -e "${YELLOW}ssh -i <your-key.pem> ec2-user@$PUBLIC_IP${NC}"
echo ""
echo "Then run:"
echo "  sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a query -m ec2 -c default -s"
echo "  sudo cat /var/log/user-data.log"
echo "  sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -n "$METRICS" ] && [ -n "$MEMORY_DATA" ] && [ -n "$DISK_DATA" ]; then
    echo -e "${GREEN}✓ CloudWatch Agent is working correctly!${NC}"
    echo ""
    echo "Dashboard URL:"
    echo "$(terraform output -raw dashboard_url)"
else
    echo -e "${YELLOW}⚠ CloudWatch Agent is still initializing${NC}"
    echo ""
    echo "Expected timeline:"
    echo "  - T+0: Instance starts"
    echo "  - T+2-3 min: CloudWatch Agent installs"
    echo "  - T+5 min: First metrics appear"
    echo "  - T+10 min: Dashboard shows data reliably"
    echo ""
    echo "Current uptime: ${UPTIME_MINUTES} minutes"
    echo ""
    if [ $UPTIME_MINUTES -lt 10 ]; then
        echo -e "${YELLOW}Recommendation: Wait $(( 10 - UPTIME_MINUTES )) more minutes and run this script again.${NC}"
    else
        echo -e "${RED}Issue: Agent should be running by now.${NC}"
        echo "Check logs on the instance:"
        echo "  ssh ec2-user@$PUBLIC_IP"
        echo "  sudo cat /var/log/user-data.log"
    fi
fi

echo ""
