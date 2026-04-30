# ============================================================
# provider.tf — Terraform 설정 + AWS 프로바이더
# ============================================================
# 이 파일은 "Terraform아, AWS를 사용할 거야. 서울 리전이야" 를 선언하는 파일.
# 모든 Terraform 프로젝트의 시작점.

terraform {
  # Terraform 최소 버전 요구
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"   # AWS 프로바이더 (HashiCorp 공식)
      version = "~> 5.0"          # 5.x 버전 사용 (최신 안정판)
    }
  }
}

# AWS 프로바이더 설정
provider "aws" {
  region  = "ap-northeast-2"   # 서울 리전
  profile = "dev"              # aws configure --profile dev 로 설정한 자격증명 사용
  # Access Key / Secret Key를 여기에 직접 쓰면 절대 안 됨!

  default_tags {
    tags = {
      Project     = "fintech-security"
      Environment = "dev"
      Team        = "Zero-Us"
      ManagedBy   = "Terraform"
    }
  }
}
