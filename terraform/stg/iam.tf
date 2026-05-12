# ============================================================
# iam.tf — Stg 계정 비즈니스 IAM Role
# ============================================================

variable "corp_account_id" {
  description = "Corp AWS 계정 ID (IAM Role 신뢰 주체)"
  type        = string
  default     = ""
}

#============================================================
# System-Admin-Role
#============================================================
resource "aws_iam_role" "system_admin" {
  name = "System-Admin-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.corp_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })

  tags = { Name = "System-Admin-Role" }
}

resource "aws_iam_role_policy_attachment" "system_admin" {
  role       = aws_iam_role.system_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
