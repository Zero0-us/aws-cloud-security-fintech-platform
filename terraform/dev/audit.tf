# ============================================================
# audit.tf — DEV CloudTrail
# ============================================================
# Prod의 modules/audit/ 모듈을 풀어서 작성한 버전.
# Dev에는 CloudTrail이 없었으므로 이번에 신규 추가.
#
# 이 파일에서 관리하는 리소스:
#   ✅ CloudTrail (계정 내 모든 API 호출 추적)
#   ✅ CloudTrail용 S3 버킷
#   ✅ CloudTrail용 CloudWatch Log Group
#   ✅ CloudTrail이 사용하는 IAM Role
# ============================================================

# ────────────────────────────────────────────
# CloudTrail용 S3 버킷
# ────────────────────────────────────────────
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "fin-dev-cloudtrail-${data.aws_caller_identity.current.account_id}-ap-northeast-2"
  force_destroy = true

  tags = {
    Name = "fin-dev-cloudtrail-bucket"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# ────────────────────────────────────────────
# CloudTrail용 CloudWatch Log Group
# ────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/fin-dev-cloudtrail"
  retention_in_days = 90

  tags = {
    Name = "fin-dev-cloudtrail-logs"
  }
}

# ────────────────────────────────────────────
# CloudTrail이 CloudWatch에 쓸 수 있는 IAM Role
# ────────────────────────────────────────────
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "fin-dev-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "fin-dev-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# ────────────────────────────────────────────
# CloudTrail 본체
# ────────────────────────────────────────────
resource "aws_cloudtrail" "main" {
  name                          = "fin-dev-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]

  tags = {
    Name = "fin-dev-cloudtrail"
  }
}