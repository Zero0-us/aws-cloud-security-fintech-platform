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

  # KMS 보안 설정
  create_kms_key = var.enable_kms_encryption
  cluster_encryption_config = var.enable_kms_encryption ? {
    resources = ["secrets"]
  } : {}

  enable_cluster_creator_admin_permissions = true

  # 노드 그룹 설정 (Step-1 비용 최적화)
  eks_managed_node_groups = {
    fin-prod-nodegroup = {
      ami_type       = "AL2_x86_64"
      name = "fin-prod-nodegroup"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      
      min_size     = 1
      max_size     = 4
      desired_size = 1
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