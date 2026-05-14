## 1. 네트워크 및 환경 식별
variable "env_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
# variable "my_role_arn" { type = string }

variable "cluster_name" {
  type    = string
  default = "fin-stg-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.micro"]
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "node_desired_size" { default = 2 }
variable "node_min_size" { default = 2 }
variable "node_max_size" { default = 3 }
variable "node_disk_size" { default = 20 }

variable "ebs_csi_addon_version" {
  description = "EBS CSI 드라이버 애드온 버전"
  type        = string
  default     = null
}

# KMS 시크릿 암호화 기능 활성화 변수 추가

variable "enable_kms_encryption" {
  description = "EKS Secret 암호화를 위한 KMS CMK 활성화 여부"
  type        = bool
  default     = true # 기본적으로 활성화 (핀테크 보안 규정)
}

variable "region" {
  description = "AWS 리전 정보"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로필명. 비어 있으면 기본 자격증명을 사용."
  type        = string
  default     = ""
}

variable "node_group_name" {
  description = "EKS 노드 그룹의 이름"
  type        = string
}
variable "access_entries" {
  description = "EKS Access Entries 명단"
  type        = any
  default     = {}
}
