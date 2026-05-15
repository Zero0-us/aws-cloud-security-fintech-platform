
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "default"

  default_tags {
    tags = {
      Project   = "aws-cloud-security-fintech-platform"
      ManagedBy = "Terraform"
    }
  }
}

## Phase 1: EKS가 생성된 후 아래 주석을 해제하세요
# data "aws_eks_cluster_auth" "this" {
#   name = module.prod_eks.cluster_name
# }

provider "kubernetes" {
  host = "https://localhost"
}

provider "helm" {
  kubernetes {
    host = "https://localhost"
  }
}

# 배포 전 테라폼이 실제로 인지하고 있는 AWS 계정 정보를 강제로 출력함.
# 계정 꼬임 현상으로 인한 오배포 및 비용 발생을 물리적으로 방지하기 위함임.

data "aws_caller_identity" "current" {}

output "deploy_account_id" {
  description = "현재 테라폼이 배포를 시도하려는 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}


