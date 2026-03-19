# Highly Available AWS Infrastructure — Terraform + GitHub Actions CI/CD

![Terraform](https://img.shields.io/badge/Terraform-1.6.0-7B42BC?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-us--east--1-FF9900?logo=amazonaws)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=githubactions)

A production-style, highly available AWS infrastructure provisioned entirely with **Terraform** and deployed automatically via **GitHub Actions CI/CD**. Demonstrates real-world DevOps practices including Infrastructure as Code, multi-AZ architecture, auto scaling, and zero-downtime deployments.

---

## Architecture

```
Internet
    |
    v
Application Load Balancer (Public Subnets — AZ-1a & AZ-1b)
    |
    v
Auto Scaling Group (Private Subnets — AZ-1a & AZ-1b)
    |              |
    v              v
EC2 (AZ-a)     EC2 (AZ-b)
Nginx           Nginx
    <- pulls app from S3 on boot ->

Bastion Host (Public Subnet) <- SSH access for debugging
```

### Key Design Decisions

| Decision | Reason |
|---|---|
| EC2 in private subnets | Never directly exposed to internet |
| ALB in public subnets | Single entry point for all traffic |
| Multi-AZ deployment | High availability — survives AZ failure |
| NAT Gateway | Private EC2s can reach internet for packages |
| Bastion host | Secure SSH access without opening EC2 to internet |
| S3 for app files | Decouple app from infra — update without rebuilding |
| IAM role on EC2 | Secure S3 access — no hardcoded credentials |
| ASG instance refresh | Zero-downtime deployments on launch template update |
| Remote state (S3) | Shared state for team and CI/CD |
| DynamoDB state lock | Prevents concurrent Terraform runs |

---

## Project Structure

```
project-1-vpc-alb-asg-terraform/
|
+-- app/
|   +-- index.html                  # Web app served by Nginx
|
+-- modules/
|   +-- vpc/                        # VPC, subnets, IGW, NAT, route tables
|   +-- sg/                         # Security groups — ALB, EC2, Bastion
|   +-- alb/                        # Application Load Balancer + Target Group
|   +-- asg/                        # Launch Template, ASG, IAM Role, Bastion
|
+-- .github/
|   +-- workflows/
|       +-- deploy.yml              # GitHub Actions CI/CD pipeline
|
+-- main.tf                         # Root — wires all modules together
+-- variables.tf                    # Input variable definitions
+-- outputs.tf                      # Output values (ALB DNS, Bastion IP)
+-- terraform.tfvars                # Variable values (gitignored)
+-- .gitignore
```

---

## Infrastructure Components

### VPC
- CIDR: `10.0.0.0/16`
- 2 Public Subnets (`10.0.1.0/24`, `10.0.2.0/24`) — us-east-1a, us-east-1b
- 2 Private Subnets (`10.0.3.0/24`, `10.0.4.0/24`) — us-east-1a, us-east-1b
- Internet Gateway, NAT Gateway, separate route tables

### Security Groups

| SG | Inbound | Outbound |
|---|---|---|
| ALB SG | Port 80 from `0.0.0.0/0` | All traffic |
| EC2 SG | Port 80 from ALB SG only | All traffic |
| Bastion SG | Port 22 from your IP only | All traffic |

### Auto Scaling Group
- Desired: 2 | Min: 1 | Max: 4
- Multi-AZ across both private subnets
- Rolling instance refresh — zero downtime deployments
- Health check type: ELB

### EC2 User Data (on each boot)
1. Install Nginx and AWS CLI
2. Pull `index.html` from S3 via IAM role
3. Inject Instance ID and AZ into the page
4. Start Nginx

### IAM Role (EC2)
- `AmazonS3ReadOnlyAccess` — pull app files from S3
- `AmazonSSMManagedInstanceCore` — SSM Session Manager (no SSH needed)

---

## CI/CD Pipeline

```
Push to main
      |
      v
Job 1 — Upload App to S3
  +-- Checkout code
  +-- Configure AWS credentials
  +-- Upload index.html to S3
      |
      v  (needs: deploy-app)
Job 2 — Terraform Plan and Apply
  +-- terraform init
  +-- terraform fmt -check
  +-- terraform validate
  +-- terraform plan
  +-- terraform apply (push to main only)
      |
      v
ALB DNS printed in logs
```

On Pull Request — only `plan` runs. No changes until merged to main.

---

## Prerequisites

### Tools
- Terraform >= 1.6.0
- AWS CLI configured
- Git

### AWS Pre-flight Setup (one time)

```bash
# 1. EC2 Key Pair
aws ec2 create-key-pair \
  --key-name mayur-key --region us-east-1 \
  --query 'KeyMaterial' --output text > ~/.ssh/mayur-key.pem
chmod 400 ~/.ssh/mayur-key.pem

# 2. S3 State Bucket
aws s3api create-bucket --bucket mayur-ha-infra-tfstate --region us-east-1
aws s3api put-bucket-versioning \
  --bucket mayur-ha-infra-tfstate \
  --versioning-configuration Status=Enabled

# 3. DynamoDB Lock Table
aws dynamodb create-table \
  --table-name mayur-ha-infra-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

# 4. S3 App Bucket
aws s3api create-bucket --bucket mayur-ha-infra-app-files --region us-east-1
```

### GitHub Secrets Required

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | `us-east-1` |
| `MY_IP` | Your public IP (`curl ifconfig.me`) |

---

## Local Deployment

```bash
# Clone
git clone https://github.com/mayurgaikwad638/project-1-vpc-alb-asg-terraform.git
cd project-1-vpc-alb-asg-terraform

# Create terraform.tfvars (never commit this)
project_name     = "mayur-ha-infra"
aws_region       = "us-east-1"
ami_id           = "ami-0c02fb55956c7d316"
instance_type    = "t2.micro"
key_name         = "mayur-key"
my_ip            = "YOUR_PUBLIC_IP"
desired_capacity = 2
min_size         = 1
max_size         = 4

# Upload app first
aws s3 cp app/index.html s3://mayur-ha-infra-app-files/index.html

# Deploy
terraform init
terraform plan
terraform apply
```

---

## Verify Deployment

```bash
terraform output alb_dns_name
```

Open the URL in browser. Refresh a few times — watch **Instance ID** and **Availability Zone** change. This proves multi-AZ load balancing is working.

---

## SSH via Bastion

```bash
# Get IPs
terraform output bastion_public_ip

# SSH to bastion
ssh -i ~/.ssh/mayur-key.pem ec2-user@<BASTION_IP>

# From bastion to private EC2
ssh -i ~/.ssh/mayur-key.pem ec2-user@<PRIVATE_EC2_IP>

# Debug Nginx
sudo systemctl status nginx
sudo cat /var/log/cloud-init-output.log
```

---

## Update the App

```bash
# Edit app/index.html then push
git add app/index.html
git commit -m "update app"
git push
# GitHub Actions handles the rest automatically
```

---

## Destroy

```bash
terraform destroy
```

---

## What I Learned

- Designing multi-AZ highly available AWS architectures
- Writing modular Terraform with proper dependency chaining
- Securing infrastructure with layered security groups
- IAM roles and instance profiles for credential-free EC2-to-S3 access
- Zero-downtime deployments using ASG instance refresh
- Remote state management with S3 and DynamoDB locking
- GitHub Actions CI/CD — automating deployments on git push
- Bastion host pattern for secure SSH to private instances

---

## Tech Stack

`Terraform` `AWS VPC` `ALB` `Auto Scaling Group` `EC2` `S3` `IAM` `GitHub Actions` `Nginx` `Amazon Linux 2023`

---

## Author

**Mayur Gaikwad**
- GitHub: [@mayurgaikwad638](https://github.com/mayurgaikwad638)
- LinkedIn: [linkedin.com/in/GaikwadMayur](https://linkedin.com/in/GaikwadMayur)
