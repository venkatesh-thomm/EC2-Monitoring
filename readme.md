# EC2 Monitoring & Auto Remediation using AWS


It's a comprehensive AWS monitoring solution that demonstrates CloudWatch metrics, logs, dashboards, alarms, and automated remediation using Lambda functions.

This project uses Terraform as an Infra as Code tool to create the entire infrastructure in a few minutes!

---

# Architecture
```
┌─────────────┐
│   EC2       │
│  Instance   │──────┐
│ (CW Agent)  │      │
└─────────────┘      │
                     │ Metrics & Logs
                     ▼
              ┌──────────────┐
              │  CloudWatch  │
              │   Metrics    │
              └──────┬───────┘
                     │
                     │ Threshold Exceeded
                     ▼
              ┌──────────────┐
              │  CloudWatch  │
              │    Alarms    │
              └──────┬───────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
    ┌─────────┐           ┌──────────┐
    │   SNS   │           │  Lambda  │
    │  Topic  │           │ Function │
    └────┬────┘           └────┬─────┘
         │                     │
         │ Email               │ Auto-Remediation
         ▼                     ▼
    ┌─────────┐           ┌──────────┐
    │  User   │           │   EC2    │
    │  Email  │           │  Reboot  │
    └─────────┘           └──────────┘
```    
---

# Project Structure

```
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars.example     # Example configuration
├── deploy.sh                    # Automated deployment script
├── destroy.sh                   # Cleanup script
├── Makefile                     # Make targets for common tasks
├── .gitignore                   # Git ignore rules
│
├── lambda/
│   ├── lambda_function.py       # Auto-remediation Lambda (Python 3.11)
│   └── requirements.txt         # Python dependencies
│
├── scripts/
│   ├── build_lambda.sh          # Build Lambda package for x86_64
│   ├── user_data.sh             # EC2 initialization script
│   ├── test_cpu_stress.sh       # CPU stress test script
│   └── test_memory_stress.sh    # Memory stress test script
│
└── configs/
    ├── cloudwatch-config.json   # CloudWatch Agent configuration
    └── dashboard.json           # Dashboard template
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

* Step 1

Clone repository

```
git clone https://github.com/<username>/EC2-Monitoring.git

cd EC2-Monitoring
```

---

* Step 2 

```
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

* Step  3

Confirm SNS Subscription

Open your email.

Click

```
Confirm Subscription
```

---

* Step 4

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

Open -AWS Console

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

CloudWatch Agent not installed

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

Memory Alarm shows Insufficient Data

Verify

```
aws cloudwatch list-metrics --namespace CWAgent
```

If no metrics exist

CloudWatch Agent is not running.

---

SNS Email not received

- Confirm subscription
- Verify SNS topic
- Check CloudWatch Alarm Actions

---

Lambda not executing

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

Terraform Profile Error

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
./scripts/destroy.sh

terraform destroy
```
