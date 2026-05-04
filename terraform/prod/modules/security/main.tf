# 1. ALB 보안 그룹 (외부 사용자로부터 80/443 허용)
resource "aws_security_group" "alb_sg" {
  name        = "fin-${var.env_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실제 운영 시에는 443만 열거나 WAF 적용 권장
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "fin-${var.env_name}-alb-sg" }
}

# 2. App(EKS) 보안 그룹 (ALB로부터의 트래픽만 허용)
#    JOA 서비스: Spring Boot(:8080) + Next.js(:3000)
resource "aws_security_group" "app_sg" {
  name        = "fin-${var.env_name}-app-sg"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Spring Boot backends (bank/openapi/admin)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Next.js frontends (admin/docs/bank-web)"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "fin-${var.env_name}-app-sg" }
}

# 3. DB(RDS) 보안 그룹 (App SG로부터의 3306 트래픽만 허용)
resource "aws_security_group" "db_sg" {
  name        = "fin-${var.env_name}-db-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # App SG만 허용 (보안 핵심)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "fin-${var.env_name}-db-sg" }
}