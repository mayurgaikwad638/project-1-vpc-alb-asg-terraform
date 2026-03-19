# ------------- sg for alb ---------------- #

resource "aws_security_group" "alb-sg" {

  name = "${var.project_name}-alb-sg"
  vpc_id = var.vpc_id
  tags = { Name = "${var.project_name}-alb-sg" }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

# ── BASTION SECURITY GROUP ───────────────────────────
# SSH allowed ONLY from your IP — never open to internet
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH only from my IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-bastion-sg" }
}


# ---------------- sg for ec2 -------------- #
resource "aws_security_group" "ec2" {
  
  name = "${var.project_name}-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [ aws_security_group.alb-sg.id ]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp" 
    security_groups = [ aws_security_group.bastion.id ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }
}

