# ============================================================
# iam.tf — Corp 계정 IAM User + AssumeRole 정책
# ============================================================
#
# Apply 순서: prod/dev/soc apply 완료 후 이 파일 apply
#
# 사용자 추가/삭제 방법:
#   variables.tf의 iam_users 맵에서 추가하거나 제거 후 apply
#
# ============================================================

locals {
  role_arns = {
    system_admin     = "arn:aws:iam::${var.prod_account_id}:role/System-Admin-Role"
    prod_viewer      = "arn:aws:iam::${var.prod_account_id}:role/Prod-Viewer-Role"
    dev_manager      = "arn:aws:iam::${var.dev_account_id}:role/Dev-Manager-Role"
    security_audit   = "arn:aws:iam::${var.soc_account_id}:role/Security-Audit-Role"
    dev_system_admin = "arn:aws:iam::${var.dev_account_id}:role/System-Admin-Role"
    soc_system_admin = "arn:aws:iam::${var.soc_account_id}:role/System-Admin-Role"
    stg_system_admin = "arn:aws:iam::${var.stg_account_id}:role/System-Admin-Role"
  }
}

#============================================================
# IAM User 생성
#============================================================
resource "aws_iam_user" "users" {
  for_each = var.iam_users

  name = each.key
  path = "/fintech/"

  tags = { Name = each.key }
}

#============================================================
# MFA 강제 정책 (MFA 없으면 AssumeRole 불가)
#============================================================
resource "aws_iam_policy" "force_mfa" {
  name        = "fin-corp-force-mfa"
  description = "MFA 미설정 시 AssumeRole 차단"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSelfManageMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = { "aws:MultiFactorAuthPresent" = "false" }
        }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "force_mfa" {
  for_each = var.iam_users

  user       = aws_iam_user.users[each.key].name
  policy_arn = aws_iam_policy.force_mfa.arn
}

#============================================================
# 사용자별 AssumeRole 정책
#============================================================
resource "aws_iam_user_policy" "assume_roles" {
  for_each = var.iam_users

  name = "fin-corp-${each.key}-assume-roles"
  user = aws_iam_user.users[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = [for role in each.value.roles : local.role_arns[role]]
    }]
  })
}
