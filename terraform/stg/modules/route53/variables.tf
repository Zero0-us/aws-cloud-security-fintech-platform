variable "env_name" {
  type = string
}

variable "base_domain" {
  type    = string
  default = "fin-api.com"
}

variable "alb_dns_name" {
  description = "Target ALB DNS name. Empty keeps the hosted zone but skips the alias record."
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Target ALB hosted zone ID. Empty keeps the hosted zone but skips the alias record."
  type        = string
  default     = ""
}
