# ============================================================
# fin-cloudwatch-export-role
# ============================================================
# 용도:
#   SOC 계정의 중앙 Lambda가 각 계정(Prod/Dev/Stg)의
#   CloudWatch Logs를 SOC S3로 export하기 위해 AssumeRole하는 IAM Role.
#
# 배경:
#   - VPC Flow Logs, CloudTrail, Config는 S3로 직접 전송 가능 ✅
#   - EKS, RDS, WAF 로그는 CloudWatch Logs에만 저장됨 ❌
#   - 이런 로그들은 SOC Lambda가 직접 가져가야 하므로
#     SOC가 AssumeRole할 수 있는 Role이 각 계정에 필요함.
#
# 작동 흐름:
#   [SOC 계정 Lambda]
#         ↓ sts:AssumeRole
#   [이 Role (각 계정에 존재)]
#         ↓ CloudWatch Logs 읽기 + S3 쓰기
#   [SOC S3 버킷]
# ============================================================

# [1] IAM Role - SOC 계정에서 AssumeRole 가능
resource "aws_iam_role" "cloudwatch_export" {
  name = "fin-cloudwatch-export-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSOCAccountAssumeRole"
        Effect = "Allow"
        Principal = {
          # SOC Lambda Role 이름이 지정된 경우 → 해당 Role만 허용 (더 안전)
          # 비어있는 경우 → SOC 계정 root (계정 전체) 허용
          AWS = var.soc_lambda_role_name != "" ? "arn:aws:iam::${var.soc_account_id}:role/${var.soc_lambda_role_name}" : "arn:aws:iam::${var.soc_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "fin-cloudwatch-export-role"
    Environment = var.env_name
    ManagedBy   = "Terraform"
    Purpose     = "SOC Lambda AssumeRole for CloudWatch Logs export"
  }
}

# [2] IAM Policy - CloudWatch Logs 읽기 + S3 export 권한
resource "aws_iam_role_policy" "cloudwatch_export" {
  name = "fin-${var.env_name}-cloudwatch-export-policy"
  role = aws_iam_role.cloudwatch_export.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs 읽기 권한
      {
        Sid    = "AllowCloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeExportTasks",
          "logs:DescribeSubscriptionFilters"
        ]
        Resource = "*"
      },
      # CloudWatch Logs Export Task 생성 권한
      {
        Sid    = "AllowCreateExportTask"
        Effect = "Allow"
        Action = [
          "logs:CreateExportTask",
          "logs:CancelExportTask"
        ]
        Resource = "*"
      },
      # SOC S3 버킷에 쓰기 권한 (Export Task 결과물 저장용)
      {
        Sid    = "AllowS3WriteToSOCBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::fin-${var.env_name}-log-s3",
          "arn:aws:s3:::fin-${var.env_name}-log-s3/*"
        ]
      }
    ]
  })
}