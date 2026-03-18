# --------------- alb ----------- #

resource "aws_lb" "main" {

  name = "${var.project_name}-alb"
  internal = false 
  subnets = var.public_subnet_ids
  security_groups = [var.alb_sg_id]
  load_balancer_type = "application"

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-alb" }
}

# --------------- target group ------------- #

resource "aws_alb_target_group" "main" {
  name = "${var.project_name}-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-tg" }
}

# ----------------- listener -------------- #

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }
}

