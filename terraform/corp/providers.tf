terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # 백엔드 설정 (옵션)
  # backend "s3" {
  #   bucket = "fin-corp-terraform-state"
  #   key    = "corp/terraform.tfstate"
  #   region = "ap-northeast-2"
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "aws-cloud-security-fintech-platform"
      ManagedBy = "Terraform"
      Account   = "Corp"
    }
  }
}