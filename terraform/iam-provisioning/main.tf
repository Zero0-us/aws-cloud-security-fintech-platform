# ============================================================
# IAM Provisioning Automation - Main Configuration
# 경로: terraform/iamprovisioning/main.tf
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # 백엔드 설정 (로컬로 변경 - S3 버킷 없어도 동작)
  # 프로덕션 배포 시 S3 백엔드로 변경하세요
  # backend "s3" {
  #   bucket       = "fin-terraform-state-s3"
  #   key          = "iam-provisioning/terraform.tfstate"
  #   region       = "ap-northeast-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "IAM-Provisioning-Automation"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Security-Team"
    }
  }
}

# 현재 계정 정보
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}