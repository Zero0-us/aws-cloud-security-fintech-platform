data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  groups = {
    admin        = "${var.name_prefix}-admin"
    deployer     = "${var.name_prefix}-deployer"
    auditor      = "${var.name_prefix}-auditor"
    security_ops = "${var.name_prefix}-security-ops"
    readonly     = "${var.name_prefix}-readonly"
  }

  common_tags = {
    Environment = var.env_name
    Component   = "iam"
  }

  vuln_bank_ecr_repository_arn = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/vuln-bank"
  prod_eks_cluster_arn         = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/fin-${var.env_name}-eks"
}

resource "aws_iam_group" "this" {
  for_each = local.groups

  name = each.value
  path = "/fintech/${var.env_name}/"
}

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
  name        = "${var.name_prefix}-deny-without-mfa"
  description = "Deny AWS API actions unless the IAM principal uses MFA."
  policy      = data.aws_iam_policy_document.mfa_required.json
  tags        = local.common_tags
}

data "aws_iam_policy_document" "admin" {
  statement {
    sid    = "AllowFintechPlatformAdministration"
    effect = "Allow"

    actions = [
      "application-autoscaling:*",
      "autoscaling:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "ec2:*",
      "ecr:*",
      "eks:*",
      "elasticloadbalancing:*",
      "iam:CreateServiceLinkedRole",
      "iam:Get*",
      "iam:List*",
      "iam:PassRole",
      "kms:*",
      "logs:*",
      "rds:*",
      "route53:*",
      "s3:*",
      "secretsmanager:*",
      "sts:GetCallerIdentity",
      "wafv2:*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "admin" {
  name        = "${var.name_prefix}-admin-policy"
  description = "Administrative access for the fintech stg platform services."
  policy      = data.aws_iam_policy_document.admin.json
  tags        = local.common_tags
}

data "aws_iam_policy_document" "deployer" {
  statement {
    sid       = "AllowEcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowVulnBankImagePushPull"
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

    resources = [local.vuln_bank_ecr_repository_arn]
  }

  statement {
    sid    = "AllowEksDeploymentAccess"
    effect = "Allow"

    actions = [
      "eks:AccessKubernetesApi",
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]

    resources = ["*", local.prod_eks_cluster_arn]
  }

  statement {
    sid    = "AllowDeploymentTroubleshootingRead"
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

resource "aws_iam_policy" "deployer" {
  name        = "${var.name_prefix}-deployer-policy"
  description = "Least-privilege deployment access for ECR image push and EKS app rollout checks."
  policy      = data.aws_iam_policy_document.deployer.json
  tags        = local.common_tags
}

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
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "eks:Describe*",
      "eks:List*",
      "elasticloadbalancing:Describe*",
      "iam:GenerateCredentialReport",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:List*",
      "rds:Describe*",
      "rds:ListTagsForResource",
      "route53:Get*",
      "route53:List*",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "wafv2:Get*",
      "wafv2:List*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "auditor" {
  name        = "${var.name_prefix}-auditor-policy"
  description = "Read-only audit access for compliance checks without reading secret values."
  policy      = data.aws_iam_policy_document.auditor.json
  tags        = local.common_tags
}

data "aws_iam_policy_document" "security_ops" {
  statement {
    sid    = "AllowSecurityOperations"
    effect = "Allow"

    actions = [
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "guardduty:Get*",
      "guardduty:List*",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:List*",
      "securityhub:BatchGet*",
      "securityhub:Describe*",
      "securityhub:Get*",
      "securityhub:List*",
      "wafv2:*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "security_ops" {
  name        = "${var.name_prefix}-security-ops-policy"
  description = "Security operations access for WAF and security monitoring."
  policy      = data.aws_iam_policy_document.security_ops.json
  tags        = local.common_tags
}

resource "aws_iam_group_policy_attachment" "mfa_required" {
  for_each = aws_iam_group.this

  group      = each.value.name
  policy_arn = aws_iam_policy.mfa_required.arn
}

resource "aws_iam_group_policy_attachment" "admin" {
  group      = aws_iam_group.this["admin"].name
  policy_arn = aws_iam_policy.admin.arn
}

resource "aws_iam_group_policy_attachment" "deployer" {
  group      = aws_iam_group.this["deployer"].name
  policy_arn = aws_iam_policy.deployer.arn
}

resource "aws_iam_group_policy_attachment" "auditor" {
  group      = aws_iam_group.this["auditor"].name
  policy_arn = aws_iam_policy.auditor.arn
}

resource "aws_iam_group_policy_attachment" "security_ops" {
  group      = aws_iam_group.this["security_ops"].name
  policy_arn = aws_iam_policy.security_ops.arn
}

resource "aws_iam_group_policy_attachment" "readonly" {
  group      = aws_iam_group.this["readonly"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user" "this" {
  for_each = var.iam_users

  name          = each.key
  path          = "/fintech/${var.env_name}/"
  force_destroy = true
  tags          = merge(local.common_tags, each.value.tags)
}

resource "aws_iam_user_group_membership" "this" {
  for_each = var.iam_users

  user = aws_iam_user.this[each.key].name
  groups = [
    for group_key in each.value.groups : aws_iam_group.this[group_key].name
  ]
}

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
