# ============================================================
# iam.tf — Dev 계정 비즈니스 IAM Role
# ============================================================

data "aws_caller_identity" "dev" {}

#============================================================
# System-Admin-Role
#============================================================
resource "aws_iam_role" "system_admin" {
  name = "System-Admin-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.dev.account_id}:root" }
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

#============================================================
# Dev-Manager-Role
#============================================================
resource "aws_iam_role" "dev_manager" {
  name = "Dev-Manager-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.dev.account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })

  tags = { Name = "Dev-Manager-Role" }
}

resource "aws_iam_role_policy_attachment" "dev_manager" {
  role       = aws_iam_role.dev_manager.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
