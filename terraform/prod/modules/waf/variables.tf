variable "env_name" {
  description = "환경 이름"
  type        = string
}

variable "alb_arn" {
  description = "WAF를 연결할 ALB의 ARN 주소"
  type        = string
}