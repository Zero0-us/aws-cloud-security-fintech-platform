# modules/alb/variables.tf

variable "env_name" {
  description = "배포 환경 구분 (stg, dev 등)"
  type        = string
}

variable "vpc_id" {
  description = "ALB와 Target Group이 속할 VPC ID"
  type        = string
}

variable "alb_sg_id" {
  description = "ALB에 적용할 보안 그룹 ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALB가 위치할 Public 서브넷 ID 리스트 (최소 2개 이상)"
  type        = list(string)
}