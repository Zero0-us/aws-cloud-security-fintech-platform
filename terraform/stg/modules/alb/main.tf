# 1. ALB 본체 생성
resource "aws_lb" "this" {
  name               = "fin-${var.env_name}-alb"
  internal           = false # 외부 노출형
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids # 2a, 2c Public 서브넷

  # [보안] 핀테크 Prod 환경 권장: 실수로 인한 삭제 방지
  # 잦은 생성/삭제가 필요한 개발 단계라 테스트 환경에서는 false로 설정
  # enable_deletion_protection = var.env_name == "prod" ? true : false

  tags = { Name = "fin-${var.env_name}-alb" }
}

# 2. Target Group (트래픽이 전달될 목적지)
#    JOA Spring Boot 백엔드 기본 포트: 8080
resource "aws_lb_target_group" "this" {
  name        = "fin-${var.env_name}-tg"
  port        = 8080 # Spring Boot 기본 포트
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # EKS Pod로 직접 통신하기 위해 필수

  health_check {
    path                = "/actuator/health" # Spring Boot Actuator 헬스체크
    protocol            = "HTTP"
    port                = "8080"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 3. Listener 설정 (80 포트)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  # Stg 환경이라면 나중에 HTTPS로 리다이렉트하거나 443 리스너 추가
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
