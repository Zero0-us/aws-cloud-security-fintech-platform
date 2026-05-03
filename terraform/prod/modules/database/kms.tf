
data "aws_caller_identity" "current" {}

# RDS 전용 암호화 키 생성
resource "aws_kms_key" "rds" {
  description             = "KMS Key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # [보안] RDS 서비스가 이 키를 사용하여 데이터를 암호화/복호화할 수 있도록 허용
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = { Service = "rds.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/fin-rds-cmk"
  target_key_id = aws_kms_key.rds.key_id
}