# ============================================================
# iam.tf — SOC 계정 IAM Groups, Policies, MFA 강제
# ============================================================

locals {
  soc_groups = {
    admin            = "fin-soc-admin"
    security_ops     = "fin-soc-security-ops"
    security_auditor = "fin-soc-security-auditor"
  }
}

# ============================================================
# IAM Groups
# ============================================================

resource "aws_iam_group" "this" {
  for_each = local.soc_groups

  name = each.value
  path = "/fintech/soc/"
}

# ============================================================
# MFA 강제 정책 (전체 그룹 공통 적용)
# ============================================================

data "aws_iam_policy_document" "mfa_required" {
  statement {
    sid    = "DenyMostActionsWithoutMFA"
    effect = "Deny"

    not_actions = [
      "iam:ChangePassword",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetAccountPasswordPolicy",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ListUsers",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "sts:GetCallerIdentity",
      "sts:GetSessionToken"
    ]

    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "mfa_required" {
  name        = "fin-soc-deny-without-mfa"
  description = "MFA 없이는 대부분 AWS API 차단."
  policy      = data.aws_iam_policy_document.mfa_required.json
}

resource "aws_iam_group_policy_attachment" "mfa_required" {
  for_each = aws_iam_group.this

  group      = each.value.name
  policy_arn = aws_iam_policy.mfa_required.arn
}

# ============================================================
# admin — AdministratorAccess
# ============================================================

resource "aws_iam_group_policy_attachment" "admin" {
  group      = aws_iam_group.this["admin"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================
# security_ops — Athena + Lambda + S3 로그 조회 + CloudWatch
# ============================================================

data "aws_iam_policy_document" "security_ops" {
  statement {
    sid    = "AllowAthenaQuery"
    effect = "Allow"
    actions = [
      "athena:BatchGetQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetWorkGroup",
      "athena:ListQueryExecutions",
      "athena:StartQueryExecution",
      "athena:StopQueryExecution"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowGlueCatalogRead"
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowLambdaInvoke"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunction",
      "lambda:ListFunctions"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3LogRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:PutObject"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchFullRead"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:List*",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "security_ops" {
  name        = "fin-soc-security-ops-policy"
  description = "SOC 분석가용 — Athena 쿼리, Lambda 실행, S3 로그 조회, CloudWatch 모니터링."
  policy      = data.aws_iam_policy_document.security_ops.json
}

resource "aws_iam_group_policy_attachment" "security_ops" {
  group      = aws_iam_group.this["security_ops"].name
  policy_arn = aws_iam_policy.security_ops.arn
}

# ============================================================
# security_auditor — SecurityAudit + ReadOnlyAccess
# ============================================================

resource "aws_iam_group_policy_attachment" "security_auditor_securityaudit" {
  group      = aws_iam_group.this["security_auditor"].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_group_policy_attachment" "security_auditor_readonly" {
  group      = aws_iam_group.this["security_auditor"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ============================================================
# IAM Users
# ============================================================

resource "aws_iam_user" "this" {
  for_each = var.iam_users

  name          = each.key
  path          = "/fintech/soc/"
  force_destroy = true
  tags          = each.value.tags
}

resource "aws_iam_user_group_membership" "this" {
  for_each = var.iam_users

  user   = aws_iam_user.this[each.key].name
  groups = [for g in each.value.groups : aws_iam_group.this[g].name]
}

# ============================================================
# 패스워드 정책
# ============================================================

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 12
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  require_uppercase_characters   = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
}
