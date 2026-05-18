# ============================================================
# iam.tf — Stg 계정 비즈니스 IAM Role
# ============================================================

#============================================================
# System-Admin-Role
#============================================================
resource "aws_iam_role" "system_admin" {
  name = "System-Admin-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
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
