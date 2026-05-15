resource "aws_security_group" "alb_sg" {
  name        = "fin-${var.env_name}-alb-sg"
  description = "Security group for public Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Public HTTP for vulnerable web testing"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-${var.env_name}-alb-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "fin-${var.env_name}-app-sg"
  description = "Security group for vuln-bank application traffic"
  vpc_id      = var.vpc_id

  ingress {
    description     = "vuln-bank Flask web/API"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-${var.env_name}-app-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "fin-${var.env_name}-db-sg"
  description = "Security group for private PostgreSQL RDS"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from EKS private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.app_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-${var.env_name}-db-sg"
  }
}
