terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "aws_profile" {
  description = "AWS CLI profile to use for the dev environment"
  type        = string
  default     = "default"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "fintech-security"
      Environment = "dev"
      Team        = "Zero-Us"
      ManagedBy   = "Terraform"
    }
  }
}
