variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for IAM resources"
  type        = string
}

variable "iam_users" {
  description = "IAM users to provision and their group memberships. Group keys: admin, deployer, auditor, security_ops, readonly."
  type = map(object({
    groups = list(string)
    tags   = optional(map(string), {})
  }))
  default = {}
}
