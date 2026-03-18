# ── IAM ROLE FOR EC2 ─────────────────────────────────
# Allows EC2 to pull files from S3 and use SSM Session Manager
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-ec2-role" }
}

# Attach S3 read policy — EC2 can pull app files from S3
resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Attach SSM policy — allows Session Manager (no SSH needed)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — wraps the IAM role so EC2 can use it
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ── LAUNCH TEMPLATE ──────────────────────────────────
# Blueprint for every EC2 instance the ASG creates
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false  # Private subnet — no public IP
    security_groups             = [var.ec2_sg_id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # User data — runs on every EC2 at boot
  # Installs Nginx, pulls index.html from S3, serves it
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Update packages
    yum update -y

    # Install Nginx and AWS CLI
    yum install -y nginx aws-cli

    # Pull app files from S3
    aws s3 cp s3://${var.s3_bucket_name}/index.html /usr/share/nginx/html/index.html

    # Get instance metadata for display
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

    # Inject instance info into the page
    sed -i "s/INSTANCE_ID/$INSTANCE_ID/g" /usr/share/nginx/html/index.html
    sed -i "s/AVAILABILITY_ZONE/$AZ/g" /usr/share/nginx/html/index.html

    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
  EOF
  )

  # When launch template is updated, create new version
  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-lt" }
}

# ── AUTO SCALING GROUP ───────────────────────────────
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.private_subnet_ids

  # Register instances with ALB target group
  target_group_arns = [var.target_group_arn]

  # Wait for health check before marking instance healthy
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  # Instance refresh — zero downtime deployments
  # When launch template changes, replaces instances gradually
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ec2"
    propagate_at_launch = true
  }
}

# ── BASTION HOST ─────────────────────────────────────
# Small EC2 in public subnet for SSH debugging access
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = var.bastion_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = { Name = "${var.project_name}-bastion" }
}