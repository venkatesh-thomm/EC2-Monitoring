#!/bin/bash
# Script to test CPU alarm by stressing the EC2 instance
# Run this on the EC2 instance to trigger CPU alarms

echo "Starting CPU stress test..."
echo "This will consume CPU resources for 5 minutes to trigger CloudWatch alarms"
echo "Press Ctrl+C to stop early"

# Check if stress is installed
if ! command -v stress &> /dev/null; then
    echo "Installing stress tool..."
    sudo apt-get update && sudo apt-get install -y stress
fi

# Get number of CPUs
NUM_CPUS=$(nproc)
echo "Detected $NUM_CPUS CPU cores"

# Stress CPU for 5 minutes
echo "Starting stress test with $NUM_CPUS workers..."
stress --cpu $NUM_CPUS --timeout 300s --verbose

echo "Stress test completed!"
echo "Check CloudWatch console for alarm status"
