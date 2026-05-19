variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "fintech-prod"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "env_name" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "is_prod_deployment" {
  description = "Enable RDS Multi-AZ for prod"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnets" {
  description = "Public subnet CIDRs for ALB/NAT"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs for EKS nodes/apps"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "db_subnets" {
  description = "Private DB subnet CIDRs for RDS"
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "node_group_name" {
  description = "EKS node group name"
  type        = string
  default     = "fin-prod-nodegroup"
}

variable "eks_access_entries" {
  description = "EKS access entries"
  type        = any
  default     = {}
}

variable "active_ingress_alb_name" {
  description = "Physical ALB name created by Kubernetes Ingress. Leave empty before the Ingress exists."
  type        = string
  default     = "k8s-default-fintechi-961c886429"
}

variable "audit_log_retention_days" {
  description = "Retention days for CloudTrail CloudWatch/S3 audit logs"
  type        = number
  default     = 90
}

variable "iam_users" {
  description = "IAM users and role groups to provision for the fintech platform. Group keys: admin, deployer, auditor, security_ops, readonly."
  type = map(object({
    groups = list(string)
    tags   = optional(map(string), {})
  }))

  default = {
    fin-prod-admin = {
      groups = ["admin"]
      tags = {
        Role = "admin"
      }
    }
    fin-prod-deployer = {
      groups = ["deployer"]
      tags = {
        Role = "deployer"
      }
    }
    fin-prod-auditor = {
      groups = ["auditor"]
      tags = {
        Role = "auditor"
      }
    }
    fin-prod-security = {
      groups = ["security_ops"]
      tags = {
        Role = "security-ops"
      }
    }
  }
}

# ============================================================
# SOC (Audit Account) 로그 전송 관련 변수
# ============================================================
# stg monitoring.tf 패턴을 prod에도 동일하게 적용하기 위한 변수들.
# VPC Flow Logs, AWS Config 리소스가 SOC S3 버킷으로 로그 전송 시 사용.
# ============================================================

variable "soc_log_bucket_name" {
  description = "Audit Account (SOC)에 있는 PROD 로그 수집 S3 버킷명. 비어 있으면 fin-<env_name>-log-s3를 사용."
  type        = string
  default     = ""
}

variable "soc_log_bucket_prefix" {
  description = "SOC 로그 버킷 안에서 이 환경 로그를 저장할 prefix. 비어 있으면 env_name을 사용."
  type        = string
  default     = ""
}

variable "enable_soc_monitoring" {
  description = "VPC Flow Logs, AWS Config를 SOC 로그 버킷으로 전송하는 리소스를 생성할지 여부."
  type        = bool
  default     = true
}

variable "soc_monitoring_retention_days" {
  description = "PROD 계정 CloudWatch Logs 보관 기간 (일)"
  type        = number
  default     = 90
}

variable "soc_account_id" {
  description = "SOC AWS 계정 ID"
  type        = string
  default     = "549027855245"
}
variable "soc_lambda_role_name" {
  description = "SOC 계정의 Lambda 실행 Role 이름. 비어있으면 SOC 계정 root 허용 (덜 안전)."
  type        = string
  default     = ""
}