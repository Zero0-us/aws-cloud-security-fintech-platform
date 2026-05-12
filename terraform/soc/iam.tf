# ============================================================
# iam.tf — SOC 계정 비즈니스 IAM Role
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
# Security-Audit-Role
#============================================================
resource "aws_iam_role" "security_audit" {
  name = "Security-Audit-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.corp_account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })

  tags = { Name = "Security-Audit-Role" }
}

resource "aws_iam_role_policy_attachment" "security_audit_securityaudit" {
  role       = aws_iam_role.security_audit.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "security_audit_readonly" {
  role       = aws_iam_role.security_audit.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
