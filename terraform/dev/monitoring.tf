# ============================================================
# monitoring.tf — DEV → Audit Account (SOC) 로그 전송
# ============================================================
# stg/monitoring.tf 패턴을 dev에 동일하게 적용한 파일.
#
# 이 파일에서 관리하는 리소스:
#   ✅ VPC Flow Logs → CloudWatch Logs + SOC S3
#   ✅ AWS Config → SOC S3
#
# 이 파일에서 관리하지 않는 리소스 (별도):
#   ❌ CloudTrail → audit.tf 에서 관리
#   ❌ SOC 계정의 S3 버킷/KMS/Athena/Glue/GuardDuty/Security Hub
#      → SOC 계정 자체에서 관리
# ============================================================

# ============================================================
# VPC Flow Logs → CloudWatch Logs (모니터링/실시간 알림용)
# ============================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/fin-${var.env_name}-flow-logs"
  retention_in_days = var.soc_monitoring_retention_days

  tags = {
    Name = "fin-dev-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "fin-dev-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "fin-dev-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc_to_cloudwatch" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.dev.id   # ⭐ Dev는 직접 참조!

  tags = {
    Name = "fin-dev-vpc-flow-logs-cw"
  }
}

# ============================================================
# VPC Flow Logs → SOC S3 (장기 보관 / 컴플라이언스용)
# ============================================================
resource "aws_flow_log" "vpc_to_soc_s3" {
  log_destination      = "arn:aws:s3:::${var.soc_log_bucket_name}/${var.soc_log_bucket_prefix}/vpc-flow-logs"
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.dev.id

  tags = {
    Name = "fin-dev-vpc-flow-logs-soc-s3"
  }
}

# ============================================================
# AWS Config → SOC S3
# ============================================================
resource "aws_iam_role" "config" {
  name = "fin-dev-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "soc_audit" {
  name     = "fin-dev-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "soc_audit" {
  name           = "fin-dev-config-delivery"
  s3_bucket_name = var.soc_log_bucket_name
  s3_key_prefix  = "${var.soc_log_bucket_prefix}/config"

  depends_on = [aws_config_configuration_recorder.soc_audit]
}

resource "aws_config_configuration_recorder_status" "soc_audit" {
  name       = aws_config_configuration_recorder.soc_audit.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.soc_audit]
}