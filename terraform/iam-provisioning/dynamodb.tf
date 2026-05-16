# ============================================================
# DynamoDB - Audit Logs
# ============================================================

resource "aws_dynamodb_table" "audit_logs" {
  name         = "${var.project_name}-audit-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"
  range_key    = "timestamp"

  # Primary Key
  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # GSI용 속성
  attribute {
    name = "username"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI: username으로 조회
  global_secondary_index {
    name            = "username-index"
    hash_key        = "username"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # GSI: status로 조회
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # TTL 설정 (365일)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-audit-logs"
  }
}

# 요청 상태 추적 테이블 (pending 요청 관리)
resource "aws_dynamodb_table" "pending_requests" {
  name         = "${var.project_name}-pending-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  # TTL 설정 (7일 - pending 요청 자동 만료)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-pending-requests"
  }
}