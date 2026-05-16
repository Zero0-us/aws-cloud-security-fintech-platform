# ============================================================
# Variables
# 경로: terraform/iamprovisioning/variables.tf
# ============================================================

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "fin-iam-provisioning"
}

# Discord 설정
variable "discord_webhook_url" {
  description = "Discord Webhook URL for notifications"
  type        = string
  sensitive   = true
  default     = ""  # terraform.tfvars에서 설정
}

# 대상 계정 ID 목록
variable "target_account_ids" {
  description = "Map of account names to account IDs"
  type        = map(string)
  default = {
    dev  = "111111111111"
    stg  = "222222222222"
    prod = "333333333333"
    soc  = "444444444444"
    corp = "555555555555"
  }
}

# IAM Role 매핑
variable "allowed_roles" {
  description = "List of allowed IAM roles for provisioning"
  type        = list(string)
  default = [
    "System-Admin",
    "Security-Audit",
    "Prod-Viewer",
    "Dev-Manager",
    "CICD-Deploy",
    "Stg-Manager",
    "SOC-Analyst",
    "ReadOnly"
  ]
}

# Lambda 설정
variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = map(number)
  default = {
    request_parser   = 30
    iam_executor     = 120
    discord_notifier = 10
  }
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = map(number)
  default = {
    request_parser   = 256
    iam_executor     = 512
    discord_notifier = 128
  }
}

# S3 설정
variable "s3_lifecycle_expiration_days" {
  description = "S3 object expiration days"
  type        = number
  default     = 90
}

# DynamoDB 설정
variable "dynamodb_ttl_days" {
  description = "DynamoDB TTL in days"
  type        = number
  default     = 365
}

# Cross-Account Role 설정 (대상 계정 배포용)
variable "soc_account_id" {
  description = "SOC Account ID for cross-account role trust"
  type        = string
  default     = ""  # 대상 계정 배포 시에만 사용
}

variable "deploy_cross_account_role" {
  description = "Whether to deploy cross-account role (for target accounts only)"
  type        = bool
  default     = false
}