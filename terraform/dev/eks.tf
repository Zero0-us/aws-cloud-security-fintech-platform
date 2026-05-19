# ============================================================
# eks.tf — EKS 클러스터 + 스팟 노드그룹
# ============================================================
# EKS = Elastic Kubernetes Service
# AWS가 쿠버네티스 컨트롤 플레인(마스터)을 관리해주고,
# 너는 워커 노드(EC2)만 관리하면 됨.
#
# 구조:
#   EKS 컨트롤 플레인 (AWS 관리, $73/월)
#     └── 노드그룹 (EC2 스팟 인스턴스, 네가 관리)
#           ├── 노드 1 (pri-sub-2a)
#           └── 노드 2 (pri-sub-2c)

# ────────────────────────────────────────────
# 1. EKS 클러스터 IAM 역할
# ────────────────────────────────────────────
# EKS 컨트롤 플레인이 AWS API를 호출하려면 IAM 역할이 필요.
# "EKS 서비스가 이 역할을 맡을(Assume) 수 있다"고 신뢰 정책에 명시.

resource "aws_iam_role" "eks_cluster" {
  name = "fin-dev-eks-cluster-role"

  # 신뢰 정책: "eks.amazonaws.com 서비스가 이 역할을 사용할 수 있다"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "fin-dev-eks-cluster-role"
  }
}

# EKS 클러스터 정책 연결
# 이 정책이 있어야 EKS가 ENI 생성, 보안그룹 관리 등을 할 수 있음
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ────────────────────────────────────────────
# 2. EKS 클러스터 생성
# ────────────────────────────────────────────
# 컨트롤 플레인 = 쿠버네티스 API 서버, etcd, 스케줄러 등.
# AWS가 완전 관리 (패치, 업그레이드, 고가용성 자동).
# ⚠️ 클러스터 생성에 10~15분 소요!
# ⚠️ $0.10/hr = $73/월 과금 시작!

resource "aws_eks_cluster" "dev" {
  name     = "fin-dev-eks"
  version  = "1.29"                              # 쿠버네티스 버전 (엑셀 기준)
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    # 컨트롤 플레인이 사용할 서브넷
    # Private 서브넷에 ENI를 생성하여 노드와 통신
    subnet_ids = [
      aws_subnet.dev_pri_2a.id,
      aws_subnet.dev_pri_2c.id,
      aws_subnet.dev_pub_2a.id,
      aws_subnet.dev_pub_2c.id,
    ]

    security_group_ids = [aws_security_group.eks_node.id]

    # 엔드포인트 액세스 설정
    endpoint_public_access  = true    # kubectl을 인터넷에서 사용 가능
    endpoint_private_access = true    # VPC 내부에서도 API 접근 가능
  }

  # 클러스터 역할 정책이 먼저 연결되어야 함
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "fin-dev-eks"
  }
}

# ────────────────────────────────────────────
# 3. EKS 노드그룹 IAM 역할
# ────────────────────────────────────────────
# 워커 노드(EC2)가 사용할 역할.
# 클러스터 역할과 다른 권한이 필요:
#   - EKSWorkerNodePolicy: 노드 등록/관리
#   - EKS_CNI_Policy: Pod 네트워킹 (VPC CNI)
#   - EC2ContainerRegistryReadOnly: ECR에서 Docker 이미지 pull

resource "aws_iam_role" "eks_node" {
  name = "fin-dev-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"    # EC2가 이 역할을 사용
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "fin-dev-eks-node-role"
  }
}

# 3개 정책 연결 (각각의 역할):

# 노드를 EKS 클러스터에 등록하고 관리하는 권한
resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

# VPC CNI 플러그인용 — Pod마다 VPC IP를 할당하는 권한
resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

# ECR에서 Docker 이미지를 pull하는 권한 (읽기 전용)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

# ────────────────────────────────────────────
# 4. EKS 스팟 노드그룹
# ────────────────────────────────────────────
# 스팟 인스턴스 = AWS 여유 용량을 최대 90% 할인에 사용.
# 단점: AWS가 용량 필요하면 2분 전 경고 후 회수 가능.
# Dev 환경이라 회수되어도 큰 문제 없음 → 비용 절감!
#
# t3.medium (2 vCPU, 4GB) + t3a.medium 혼합:
#   - EKS 시스템 Pod(kubelet, kube-proxy, coredns)에 ~1GB 필요
#   - t3.micro(1GB)는 부족 → t3.medium(4GB) 사용
#   - t3a는 AMD CPU로 t3보다 ~10% 저렴
#   - 여러 타입 지정 → 스팟 확보 확률 UP

resource "aws_eks_node_group" "dev_spot" {
  cluster_name    = aws_eks_cluster.dev.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_node.arn

  # Private 서브넷에 배치 (외부 직접 접근 차단)
  subnet_ids = [
    aws_subnet.dev_pri_2a.id,
    aws_subnet.dev_pri_2c.id,
  ]

  # ⭐ 스팟 인스턴스 설정 (비용 절감)
  capacity_type = "SPOT"

  instance_types = [
    "t3.small",      # Intel, 2 vCPU, 2GB — 프리티어 범위에서 최소 사양
  ]

  ami_type  = "AL2_x86_64"   # Amazon Linux 2 (엑셀 기준)
  disk_size = 20              # 노드당 EBS 20GB

  scaling_config {
    desired_size = 1   # 현재 노드 수 (Dev이므로 1대)
    min_size     = 1   # 최소
    max_size     = 2   # 최대 (엑셀 기준)
  }

  # 노드 업데이트 시 한 번에 1개씩 (서비스 중단 최소화)
  update_config {
    max_unavailable = 1
  }

  # IAM 정책이 먼저 연결되어야 함
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_readonly,
  ]

  tags = {
    Name = "fin-dev-nodegroup"
  }
}
