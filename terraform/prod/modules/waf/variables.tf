variable "env_name" {
  description = "Environment name."
  type        = string
}

variable "alb_arn" {
  description = "Optional ALB ARN for direct Terraform-managed WAF association. Leave null when WAF is attached by Kubernetes Ingress annotation."
  type        = string
  default     = null
}
