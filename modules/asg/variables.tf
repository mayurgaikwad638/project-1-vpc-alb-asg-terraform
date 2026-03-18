variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2023)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ASG"
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of ALB target group to register instances into"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name where app files are stored"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 4
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "bastion_subnet_id" {
  description = "Public subnet ID for the bastion host"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the bastion host"
  type        = string
}
