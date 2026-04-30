# ============================================================
# alb.tf — Application Load Balancer
# ============================================================
# ALB = 인터넷에서 들어오는 HTTP/HTTPS 트래픽을 EKS 노드에 분배.
# 아키텍처에서 pub-sub-2a, pub-sub-2c에 있는 ALB 아이콘에 해당.
#
# 트래픽 흐름:
#   사용자 → Internet Gateway → ALB (pub 서브넷) → EKS 노드 (pri 서브넷)
#
# ALB는 2개 AZ에 걸쳐 배치 → 한쪽 AZ 장애 시 다른 쪽에서 서비스.
# ⚠️ ALB는 만들어놓기만 해도 ~$16/월 과금!

# ────────────────────────────────────────────
# 1. ALB 생성
# ────────────────────────────────────────────
# internet-facing = 인터넷에서 접근 가능 (외부 사용자용)
# internal = VPC 내부 전용 (마이크로서비스 간 통신용)

resource "aws_lb" "dev" {
  name               = "fin-dev-alb"
  internal           = false                    # internet-facing (외부 접근)
  load_balancer_type = "application"            # ALB (L7, HTTP/HTTPS)
  security_groups    = [aws_security_group.alb.id]

  # 2개 AZ의 Public 서브넷에 배치 (고가용성)
  subnets = [
    aws_subnet.dev_pub_2a.id,    # ap-northeast-2a
    aws_subnet.dev_pub_2c.id,    # ap-northeast-2c
  ]

  # 삭제 보호 (실습이라 끔)
  enable_deletion_protection = false

  tags = {
    Name = "fin-dev-alb"
  }
}

# ────────────────────────────────────────────
# 2. 대상 그룹 (Target Group)
# ────────────────────────────────────────────
# ALB가 트래픽을 보낼 대상을 정의.
# EKS에서는 보통 AWS Load Balancer Controller가 자동 관리하지만,
# 기본 대상 그룹을 미리 만들어둠.

resource "aws_lb_target_group" "dev" {
  name        = "fin-dev-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.dev.id
  target_type = "ip"          # EKS Pod IP로 직접 라우팅 (ip 모드)

  # 헬스 체크: ALB가 대상이 살아있는지 확인
  health_check {
    enabled             = true
    healthy_threshold   = 2       # 연속 2번 성공하면 healthy
    unhealthy_threshold = 3       # 연속 3번 실패하면 unhealthy
    interval            = 30      # 30초마다 체크
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }

  tags = {
    Name = "fin-dev-tg"
  }
}

# ────────────────────────────────────────────
# 3. 리스너 (Listener)
# ────────────────────────────────────────────
# ALB의 "귀". 어떤 포트/프로토콜을 듣고, 어디로 보낼지 정함.
# HTTP:80 → 대상 그룹으로 전달

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dev.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev.arn
  }
}
