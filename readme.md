# EC2 Monitoring & Auto Remediation using AWS

A comprehensive AWS monitoring solution that demonstrates CloudWatch metrics, logs, dashboards, alarms, and automated remediation using AWS Lambda.

The entire infrastructure is provisioned using **Terraform (Infrastructure as Code)**, allowing you to deploy the complete monitoring solution in just a few minutes.

---

# Architecture

```text
┌─────────────┐
│     EC2     │
│  Instance   │──────┐
│ (CW Agent)  │      │
└─────────────┘      │
                     │ Metrics & Logs
                     ▼
              ┌──────────────┐
              │ CloudWatch   │
              │   Metrics    │
              └──────┬───────┘
                     │
                     │ Threshold Exceeded
                     ▼
              ┌──────────────┐
              │ CloudWatch   │
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
         │ Email               │ Auto Remediation
         ▼                     ▼
    ┌─────────┐           ┌──────────┐
    │  User   │           │   EC2    │
    │  Email  │           │  Reboot  │
    └─────────┘           └──────────┘
```

---

# Project Structure

```text
EC2-Monitoring/
│
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── provider.tf                  # AWS provider configuration
├── locals.tf                    # Local values
├── terraform.tfvars.example     # Example variable file
├── .gitignore
├── README.md
│
├── scripts/
│   ├── deploy.sh                # Deploy infrastructure
│   ├── destroy.sh               # Destroy infrastructure
│   ├── build_lambda.sh          # Build Lambda package
│   ├── user_data.sh             # EC2 bootstrap script
│   ├── test_cpu_stress.sh       # CPU stress test
│   └── test_memory_stress.sh    # Memory stress test
│
├── lambda/
│   ├── lambda_function.py       # Auto-remediation Lambda
│   └── requirements.txt         # Python dependencies
│
└── configs/
    ├── cloudwatch-config.json   # CloudWatch Agent configuration
    └── dashboard.json           # CloudWatch Dashboard
```

---

# Prerequisites

Install the following software:

- AWS CLI
- Terraform
- Git
- Zip

Configure AWS credentials:

```bash
aws configure
```

Verify your credentials:

```bash
aws sts get-caller-identity
```

---

# Deployment Steps

## Step 1 - Clone the Repository

```bash
git clone https://github.com/<username>/EC2-Monitoring.git

cd EC2-Monitoring
```

---

## Step 2 - Build the Lambda Package

Make the script executable:

```bash
chmod +x scripts/build_lambda.sh
```

Build the Lambda deployment package:

```bash
./scripts/build_lambda.sh
```

---

## Step 3 - Deploy the Infrastructure

Make the deployment script executable:

```bash
chmod +x scripts/deploy.sh
```

Deploy all AWS resources:

```bash
./scripts/deploy.sh
```

or manually:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

---

## Step 4 - Confirm SNS Subscription

After deployment:

1. Check your email.
2. Open the SNS confirmation email.
3. Click **Confirm Subscription**.

---

## Step 5 - Verify Resources

Terraform creates the following AWS resources:

- EC2 Instance
- IAM Role
- IAM Instance Profile
- CloudWatch Agent
- CloudWatch Dashboard
- CloudWatch Alarms
- SNS Topic
- Lambda Function

---

# Verify CloudWatch Agent

Connect to the EC2 instance and run:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

Expected output:

```text
Active: active (running)
```

---

# Verify CloudWatch Metrics

Open the AWS Console:

```
CloudWatch
    └── Metrics
            └── CWAgent
```

You should see metrics such as:

- mem_used_percent
- disk_used_percent
- cpu_usage_idle
- cpu_usage_user

---

# Test CPU Alarm

SSH into the EC2 instance:

```bash
./scripts/test_cpu_stress.sh
```

Expected behaviour:

- CPU utilisation increases
- CloudWatch Alarm changes to **ALARM**
- SNS email notification is sent
- Lambda function is invoked
- EC2 instance reboots automatically

---

# Test Memory Alarm

Run:

```bash
./scripts/test_memory_stress.sh
```

Expected behaviour:

- Memory utilisation exceeds the threshold
- Memory Alarm changes to **ALARM**

---

# Verify Lambda Execution

Open:

```
CloudWatch
    └── Log Groups
            └── /aws/lambda/<function-name>
```

Verify that Lambda execution logs are present.

---

# Verify SNS Notifications

You should receive:

- High CPU Alert
- Auto Remediation Notification

---

# Updating User Data

If you modify `scripts/user_data.sh`, recreate the EC2 instance:

```bash
terraform apply -replace=aws_instance.monitored
```

or

```bash
terraform taint aws_instance.monitored
terraform apply
```

---




# Troubleshooting

## CloudWatch Agent Not Installed

Check the service:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

If you see:

```text
Unit amazon-cloudwatch-agent.service could not be found.
```

Check cloud-init logs:

```bash
sudo cat /var/log/cloud-init-output.log
```

---

## Memory or Disk Alarm Shows "Insufficient Data"

Verify that CloudWatch Agent is publishing metrics:

```bash
aws cloudwatch list-metrics --namespace CWAgent
```

If no metrics are returned, verify that the CloudWatch Agent is running correctly.

---

## SNS Email Not Received

Verify:

- SNS subscription is confirmed.
- Alarm actions reference the correct SNS topic.
- Email address is correct.

---

## Lambda Not Executing

Check Lambda logs:

```text
/aws/lambda/<function-name>
```

Verify that the Lambda execution role has:

```text
ec2:RebootInstances
```

permission.

---

## Terraform Profile Error

If you receive:

```text
failed to get shared config profile
```

Check available profiles:

```bash
aws configure list-profiles
```

Use an existing profile or remove the `AWS_PROFILE` environment variable.

---

# Cleanup

Destroy all AWS resources:

```bash
chmod +x scripts/destroy.sh

./scripts/destroy.sh
```

or

```bash
terraform destroy
```

## To Copy files 
```
scp test_cpu_stress.sh test_memory_stress.sh ec2-user@100.60.66.40:~
```
## To test the stress run scripts at a time
```
./test_cpu_stress.sh & ./test_memory_stress.sh &
```

