variable "env_name" {
  description = "환경 이름 (prod, stg, dev 등)"
  type        = string
}

variable "base_domain" {
  description = "서비스의 기본 도메인 이름"
  type        = string
  default     = "fin-api.com"
}

variable "alb_dns_name" {
  description = "연결할 ALB의 DNS 주소"
  type        = string
}

variable "alb_zone_id" {
  description = "연결할 ALB의 Hosted Zone ID"
  type        = string
}