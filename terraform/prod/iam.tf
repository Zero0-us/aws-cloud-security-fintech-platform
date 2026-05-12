# ============================================================
# iam.tf — Prod 계정 비즈니스 IAM Role
# ============================================================
# Apply 순서: prod → corp (corp apply 전에 먼저 apply 필요)
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

#============================================================
# Prod-Viewer-Role
#============================================================
resource "aws_iam_role" "prod_viewer" {
  name = "Prod-Viewer-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.corp_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })

  tags = { Name = "Prod-Viewer-Role" }
}

resource "aws_iam_role_policy_attachment" "prod_viewer" {
  role       = aws_iam_role.prod_viewer.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}
