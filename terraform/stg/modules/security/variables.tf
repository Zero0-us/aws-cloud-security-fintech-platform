variable "env_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_cidr_blocks" {
  description = "CIDR blocks allowed to connect from EKS/app private subnets to RDS."
  type        = list(string)
  default     = []
}
