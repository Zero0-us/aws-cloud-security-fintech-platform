variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for audit resources"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch and S3 retention days for audit logs"
  type        = number
  default     = 90
}
