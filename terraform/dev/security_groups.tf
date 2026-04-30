# ============================================================
# security_groups.tf — 보안 그룹 (인스턴스 레벨 방화벽)
# ============================================================
# 보안 그룹 = "누가 어떤 포트로 접근할 수 있는가?"를 정하는 규칙.
# AWS에서 트래픽을 제어하는 2가지:
#   1. NACL (서브넷 레벨, 상태 비저장) — 여기선 기본값 사용
#   2. 보안 그룹 (인스턴스 레벨, 상태 저장) — 여기서 설정
#
# 3계층 보안 원칙:
#   인터넷 → ALB-SG (80/443만) → EKS-SG (ALB에서만) → RDS-SG (EKS에서만)
#   DB에 인터넷이 직접 접근하는 것은 불가능!

# ────────────────────────────────────────────
# 1. ALB 보안 그룹
# ────────────────────────────────────────────
# ALB는 인터넷에서 들어오는 트래픽의 첫 번째 관문.
# HTTP(80)와 HTTPS(443)만 허용.

resource "aws_security_group" "alb" {
  name        = "fin-dev-alb-sg"
  description = "ALB - Allow HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.dev.id

  # 인바운드: 인터넷에서 HTTP 허용
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # 전 세계 어디서든
  }

  # 인바운드: 인터넷에서 HTTPS 허용
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드: 어디든 나갈 수 있음 (EKS 노드로 트래픽 전달)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"            # "-1" = 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-dev-alb-sg"
  }
}

# ────────────────────────────────────────────
# 2. EKS 노드 보안 그룹
# ────────────────────────────────────────────
# EKS 워커 노드(EC2 스팟 인스턴스)에 적용.
# ALB에서 오는 트래픽 + 노드 간 통신만 허용.
# 인터넷에서 직접 접근 불가!

resource "aws_security_group" "eks_node" {
  name        = "fin-dev-eks-node-sg"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.dev.id

  # 인바운드: ALB에서 오는 트래픽 (서비스 포트)
  ingress {
    description     = "Traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # ALB-SG에서만!
  }

  # 인바운드: 노드 간 통신 (쿠버네티스 Pod 간 통신에 필수)
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true   # 같은 보안 그룹의 다른 인스턴스끼리
  }

  # 인바운드: EKS 컨트롤 플레인 → 노드 통신
  # (kubelet API, 로그 수집 등 — EKS가 노드를 관리하려면 필수)
  ingress {
    description = "EKS control plane to nodes"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.30.0.0/16"]   # VPC 내부 전체
  }

  # 아웃바운드: 어디든 (NAT Gateway 경유로 인터넷 접근)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-dev-eks-node-sg"
  }
}

# ────────────────────────────────────────────
# 3. RDS 보안 그룹
# ────────────────────────────────────────────
# 가장 안쪽 계층. MySQL 포트(3306)만,
# EKS 노드에서만 접근 가능.
# 인터넷, ALB, 심지어 Public 서브넷에서도 직접 접근 불가!

resource "aws_security_group" "rds" {
  name        = "fin-dev-rds-sg"
  description = "RDS - MySQL access from EKS nodes only"
  vpc_id      = aws_vpc.dev.id

  # 인바운드: EKS 노드에서 MySQL 접근
  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node.id]   # EKS-SG에서만!
  }

  # 아웃바운드
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
