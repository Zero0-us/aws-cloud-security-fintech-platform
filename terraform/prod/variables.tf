variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
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
