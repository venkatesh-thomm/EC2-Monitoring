#!/bin/bash
# Script to test memory alarm by stressing the EC2 instance
# Run this on the EC2 instance to trigger memory alarms

echo "Starting memory stress test..."
echo "This will consume memory resources for 5 minutes to trigger CloudWatch alarms"
echo "Press Ctrl+C to stop early"

# Check if stress is installed
if ! command -v stress &> /dev/null; then
    echo "Installing stress tool..."
    sudo apt-get update && sudo apt-get install -y stress
fi

# Get available memory in MB
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
# Use 80% of available memory
STRESS_MEM=$((TOTAL_MEM * 80 / 100))

echo "Total memory: ${TOTAL_MEM}MB"
echo "Will allocate: ${STRESS_MEM}MB"

# Stress memory for 5 minutes
echo "Starting memory stress test..."
stress --vm 1 --vm-bytes ${STRESS_MEM}M --timeout 300s --verbose

echo "Stress test completed!"
echo "Check CloudWatch console for alarm status"
