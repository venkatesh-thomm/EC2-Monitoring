# EC2 Monitoring & Auto Remediation using AWS

## Overview

This project provisions an AWS EC2 instance using Terraform and configures monitoring using:

- Amazon CloudWatch
- CloudWatch Agent
- CloudWatch Alarms
- Amazon SNS
- AWS Lambda
- IAM Roles
- AWS Systems Manager (SSM)

The solution monitors:

- CPU Utilization
- Memory Utilization
- Disk Utilization
- EC2 Status Checks

If CPU usage exceeds the configured threshold:

1. CloudWatch Alarm changes to **ALARM**
2. SNS sends an email notification
3. Lambda function automatically reboots the EC2 instance
4. SNS sends a remediation notification

---

# Architecture

```
                    +-------------------+
                    |      EC2          |
                    | CloudWatch Agent  |
                    +---------+---------+
                              |
                              |
                    CloudWatch Metrics
                              |
                              |
                    CloudWatch Alarms
                              |
               +--------------+-------------+
               |                            |
            SNS Topic                  Lambda
               |                            |
               |                            |
         Email Notification         Reboot EC2
```

---

# Project Structure

```
EC2-Monitoring/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
├── locals.tf
├── terraform.tfvars
│
├── scripts/
│   ├── user_data.sh
│   ├── test_cpu_stress.sh
│   ├── test_memory_stress.sh
│
├── lambda/
│   ├── lambda_function.py
│   └── build_lambda.sh
│
├── fix_cloudwatch_agent.sh
│
└── README.md
```

---

# Prerequisites

Install the following:

- AWS CLI
- Terraform
- Git
- ZIP utility

Configure AWS CLI

```
aws configure
```

Verify credentials

```
aws sts get-caller-identity
```

---

# Execution Order

## Step 1

Clone repository

```
git clone https://github.com/<username>/EC2-Monitoring.git

cd EC2-Monitoring
```

---

## Step 2

Initialize Terraform

```
terraform init
```

---

## Step 3

Validate configuration

```
terraform validate
```

---

## Step 4

Review infrastructure

```
terraform plan
```

---

## Step 5

Deploy Infrastructure

```
terraform apply
```

Type

```
yes
```

---

## Step 6

Confirm SNS Subscription

Open your email.

Click

```
Confirm Subscription
```

---

## Step 7

Verify Resources

Terraform creates

- EC2
- IAM Role
- IAM Instance Profile
- CloudWatch Agent Configuration
- CloudWatch Alarms
- SNS Topic
- Lambda Function

---

# Verify CloudWatch Agent

Connect to EC2

```
sudo systemctl status amazon-cloudwatch-agent
```

Expected

```
Active: active (running)
```

---

# Verify Metrics

Open

AWS Console

CloudWatch

Metrics

CWAgent

You should see

- mem_used_percent
- disk_used_percent

---

# Test CPU Alarm

SSH into EC2

Run

```
./scripts/test_cpu_stress.sh
```

Expected

- CPU reaches threshold
- Alarm changes to ALARM
- Email notification received
- Lambda invoked
- EC2 rebooted

---

# Test Memory Alarm

```
./scripts/test_memory_stress.sh
```

Expected

Memory alarm becomes ALARM.

---

# Verify Lambda

CloudWatch

Logs

```
/aws/lambda/<function-name>
```

You should see reboot logs.

---

# Verify SNS

You should receive

- CPU Alert Email
- Auto Remediation Email

---

# Useful Terraform Commands

Initialize

```
terraform init
```

Validate

```
terraform validate
```

Plan

```
terraform plan
```

Deploy

```
terraform apply
```

Destroy

```
terraform destroy
```

View Outputs

```
terraform output
```

Refresh State

```
terraform refresh
```

---

# Recreate EC2

If user_data.sh changes

```
terraform apply -replace=aws_instance.monitored
```

or

```
terraform taint aws_instance.monitored

terraform apply
```

---

# Troubleshooting

## CloudWatch Agent not installed

```
sudo systemctl status amazon-cloudwatch-agent
```

If

```
Unit not found
```

Check

```
sudo cat /var/log/cloud-init-output.log
```

---

## Memory Alarm shows Insufficient Data

Verify

```
aws cloudwatch list-metrics --namespace CWAgent
```

If no metrics exist

CloudWatch Agent is not running.

---

## SNS Email not received

- Confirm subscription
- Verify SNS topic
- Check CloudWatch Alarm Actions

---

## Lambda not executing

Check

CloudWatch Logs

```
/aws/lambda/<function-name>
```

Verify IAM permissions

```
ec2:RebootInstances
```

---

## Terraform Profile Error

If

```
failed to get shared config profile
```

Run

```
aws configure list-profiles
```

Use existing profile

or remove

```
AWS_PROFILE
```

---

# Cleanup

Destroy all resources

```
terraform destroy
```

---

# Technologies Used

- Terraform
- AWS EC2
- CloudWatch
- CloudWatch Agent
- AWS Lambda
- Amazon SNS
- IAM
- Systems Manager (SSM)
- Amazon Linux / RHEL

---

# Learning Outcomes

This project demonstrates:

- Infrastructure as Code using Terraform
- CloudWatch Monitoring
- CloudWatch Agent Installation
- SNS Notifications
- Lambda Auto Remediation
- IAM Best Practices
- EC2 Monitoring
- AWS Troubleshooting
- Production Deployment