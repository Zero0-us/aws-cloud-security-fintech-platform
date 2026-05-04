# ============================================================
# [P-C2] EKS Secret 암호화용 KMS CMK + Alias
# ============================================================
# 기존 create_kms_key=true(자동생성, alias 없음)에서
# 커스텀 KMS 키 + alias/fin-eks-cmk 로 변경.

resource "aws_kms_key" "eks" {
  description             = "KMS CMK for EKS Secret encryption (fin-eks-cmk)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/fin-eks-cmk"
  target_key_id = aws_kms_key.eks.key_id
}

data "aws_caller_identity" "current" {}

# [1] EKS 클러스터 및 노드 그룹 설정 블록
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # [P-C2] 커스텀 KMS CMK로 Secret 암호화 (alias/fin-eks-cmk)
  create_kms_key            = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # [P-C3] EKS Control Plane 로깅 전체 활성화
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  enable_cluster_creator_admin_permissions = true

  # 노드 그룹 설정 — JOA 서비스 Pod 8개 대응 (t3.medium × 2)
  eks_managed_node_groups = {
    fin-prod-nodegroup = {
      ami_type       = "AL2_x86_64"
      name           = "fin-prod-nodegroup"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = var.node_disk_size
            volume_type = "gp3"
          }
        }
      }
    }
  }
}

# [2] Kubeconfig 자동 업데이트
resource "null_resource" "update_kubeconfig" {
  # 클러스터 생성이 완전히 끝난 후 실행되도록 보장
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig \
        --name ${module.eks.cluster_name} \
        --region ${var.region} \
        --profile Lee-role
    EOT
  }
}