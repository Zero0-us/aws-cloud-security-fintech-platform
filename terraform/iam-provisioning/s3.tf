# ============================================================
# S3 Bucket - Provisioning Requests
# ============================================================

resource "aws_s3_bucket" "provisioning_requests" {
  bucket = "${var.project_name}-requests-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-requests"
  }
}

# 버전 관리
resource "aws_s3_bucket_versioning" "provisioning_requests" {
  bucket = aws_s3_bucket.provisioning_requests.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "provisioning_requests" {
  bucket = aws_s3_bucket.provisioning_requests.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "provisioning_requests" {
  bucket = aws_s3_bucket.provisioning_requests.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle 규칙
resource "aws_s3_bucket_lifecycle_configuration" "provisioning_requests" {
  bucket = aws_s3_bucket.provisioning_requests.id

  # 처리 완료된 요청
  rule {
    id     = "expire-processed-requests"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    expiration {
      days = var.s3_lifecycle_expiration_days
    }
  }

  # 거부된 요청
  rule {
    id     = "expire-rejected-requests"
    status = "Enabled"

    filter {
      prefix = "rejected/"
    }

    expiration {
      days = 30
    }
  }
}

# EventBridge 알림 활성화
resource "aws_s3_bucket_notification" "provisioning_requests" {
  bucket      = aws_s3_bucket.provisioning_requests.id
  eventbridge = true
}

# 폴더 구조 생성 (빈 객체)
resource "aws_s3_object" "folders" {
  for_each = toset([
    "requests/onboard/",
    "requests/offboard/",
    "requests/modify/",
    "processed/",
    "rejected/"
  ])

  bucket  = aws_s3_bucket.provisioning_requests.id
  key     = each.value
  content = ""
}