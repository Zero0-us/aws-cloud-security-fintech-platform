# ============================================================
# iam.tf — Dev 계정 IAM Groups, Policies, MFA 강제
# ============================================================

locals {
  dev_groups = {
    admin     = "fin-dev-admin"
    developer = "fin-dev-developer"
    auditor   = "fin-dev-auditor"
    readonly  = "fin-dev-readonly"
  }
}

# ============================================================
# IAM Groups
# ============================================================

resource "aws_iam_group" "this" {
  for_each = local.dev_groups

  name = each.value
  path = "/fintech/dev/"
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
  name        = "fin-dev-deny-without-mfa"
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
# developer — ECR + EKS + CloudWatch
# ============================================================

data "aws_iam_policy_document" "developer" {
  statement {
    sid       = "AllowEcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEcrAccess"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEksAccess"
    effect = "Allow"
    actions = [
      "eks:AccessKubernetesApi",
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchRead"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:List*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "developer" {
  name        = "fin-dev-developer-policy"
  description = "개발 환경 ECR, EKS, CloudWatch 접근."
  policy      = data.aws_iam_policy_document.developer.json
}

resource "aws_iam_group_policy_attachment" "developer" {
  group      = aws_iam_group.this["developer"].name
  policy_arn = aws_iam_policy.developer.arn
}

# ============================================================
# auditor — 읽기 전용 감사
# ============================================================

data "aws_iam_policy_document" "auditor" {
  statement {
    sid    = "AllowAuditReadOnly"
    effect = "Allow"
    actions = [
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "ec2:Describe*",
      "ecr:Describe*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "rds:Describe*",
      "s3:GetBucketLocation",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:ListAllMyBuckets",
      "s3:ListBucket"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "auditor" {
  name        = "fin-dev-auditor-policy"
  description = "개발 환경 읽기 전용 감사 접근."
  policy      = data.aws_iam_policy_document.auditor.json
}

resource "aws_iam_group_policy_attachment" "auditor" {
  group      = aws_iam_group.this["auditor"].name
  policy_arn = aws_iam_policy.auditor.arn
}

# ============================================================
# readonly — AWS 관리형 ReadOnlyAccess
# ============================================================

resource "aws_iam_group_policy_attachment" "readonly" {
  group      = aws_iam_group.this["readonly"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ============================================================
# IAM Users
# ============================================================

resource "aws_iam_user" "this" {
  for_each = var.iam_users

  name          = each.key
  path          = "/fintech/dev/"
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
