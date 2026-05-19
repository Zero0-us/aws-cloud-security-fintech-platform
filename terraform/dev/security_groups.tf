resource "aws_security_group" "alb" {
  name        = "fin-dev-alb-sg"
  description = "ALB - allow HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
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
    Name = "fin-dev-alb-sg"
  }
}

resource "aws_security_group" "eks_cluster_additional" {
  name        = "fin-dev-eks-additional-sg"
  description = "Additional EKS cluster security group"
  vpc_id      = aws_vpc.dev.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-dev-eks-additional-sg"
  }
}

resource "aws_security_group_rule" "eks_nodeport_from_alb" {
  type                     = "ingress"
  description              = "Allow ALB to reach vuln-bank NodePort"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_eks_cluster.dev.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group" "rds" {
  name        = "fin-dev-rds-sg"
  description = "RDS PostgreSQL access from EKS nodes only"
  vpc_id      = aws_vpc.dev.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-dev-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_from_eks_nodes" {
  type                     = "ingress"
  description              = "PostgreSQL from EKS managed nodes"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.dev.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.rds.id
}
