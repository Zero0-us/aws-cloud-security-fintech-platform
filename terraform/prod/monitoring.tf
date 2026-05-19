# ============================================================
# monitoring.tf — PROD → Audit Account (SOC) 로그 전송
# ============================================================
# stg/monitoring.tf 패턴을 prod에 동일하게 적용한 파일.
#
# 이 파일에서 관리하는 리소스:
#   ✅ VPC Flow Logs → CloudWatch Logs + SOC S3
#   ✅ AWS Config → SOC S3
#
# 이 파일에서 관리하지 않는 리소스 (별도):
#   ❌ CloudTrail → modules/audit/ 에서 관리 중 (module "prod_audit")
#   ❌ SOC 계정의 S3 버킷/KMS/Athena/Glue/GuardDuty/Security Hub
#      → SOC 계정 자체에서 관리
#
# 참고: stg/monitoring.tf와 동일한 구조이며, prod 환경 변수만 다름.
# ============================================================

locals {
  soc_log_bucket_name   = var.soc_log_bucket_name != "" ? var.soc_log_bucket_name : "fin-${var.env_name}-log-s3"
  soc_log_bucket_prefix = var.soc_log_bucket_prefix != "" ? trim(var.soc_log_bucket_prefix, "/") : var.env_name
  soc_log_bucket_arn    = "arn:aws:s3:::${local.soc_log_bucket_name}"

  soc_vpc_flow_logs_prefix = "vpc-flow-logs"
  soc_config_prefix        = ""
}

# ============================================================
# VPC Flow Logs → CloudWatch Logs (모니터링/실시간 알림용)
# ============================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_soc_monitoring ? 1 : 0

  name              = "/aws/vpc/fin-${var.env_name}-flow-logs"
  retention_in_days = var.soc_monitoring_retention_days

  tags = {
    Name        = "fin-${var.env_name}-flow-logs"
    Environment = var.env_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-vpc-flow-logs-role"

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
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

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
  count = var.enable_soc_monitoring ? 1 : 0

  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn
  traffic_type         = "ALL"
  vpc_id               = module.prod_vpc.vpc_id

  tags = {
    Name        = "fin-${var.env_name}-vpc-flow-logs-cw"
    Environment = var.env_name
  }
}

# ============================================================
# VPC Flow Logs → SOC S3 (장기 보관 / 컴플라이언스용)
# ============================================================
resource "aws_flow_log" "vpc_to_soc_s3" {
  count = var.enable_soc_monitoring ? 1 : 0

  log_destination      = "${local.soc_log_bucket_arn}/${local.soc_vpc_flow_logs_prefix}"
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.prod_vpc.vpc_id

  tags = {
    Name        = "fin-${var.env_name}-vpc-flow-logs-soc-s3"
    Environment = var.env_name
  }
}

# ============================================================
# AWS Config → SOC S3
# ============================================================
# AWS Config Recorder + Delivery Channel 구성.
# 리소스 변경 사항을 추적하고 SOC S3로 전송하여 컴플라이언스 대응.
# ============================================================

resource "aws_iam_role" "config" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-aws-config-role"

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
  count = var.enable_soc_monitoring ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name     = "fin-${var.env_name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name           = "fin-${var.env_name}-config-delivery"
  s3_bucket_name = local.soc_log_bucket_name
  s3_key_prefix  = local.soc_config_prefix != "" ? local.soc_config_prefix : null

  depends_on = [aws_config_configuration_recorder.soc_audit]
}

resource "aws_config_configuration_recorder_status" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name       = aws_config_configuration_recorder.soc_audit[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.soc_audit]
}