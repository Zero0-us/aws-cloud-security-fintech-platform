resource "aws_lb" "dev" {
  name               = "fin-dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.dev_pub_2a.id,
    aws_subnet.dev_pub_2c.id,
  ]

  enable_deletion_protection = false

  access_logs {
    bucket  = var.soc_log_bucket_name
    prefix  = var.alb_access_logs_prefix
    enabled = true
  }

  tags = {
    Name = "fin-dev-alb"
  }
}

resource "aws_lb_target_group" "dev" {
  name        = "fin-dev-tg"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.dev.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }

  tags = {
    Name = "fin-dev-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dev.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev.arn
  }
}

resource "aws_autoscaling_attachment" "dev_nodegroup_alb" {
  autoscaling_group_name = aws_eks_node_group.dev_spot.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.dev.arn
}
