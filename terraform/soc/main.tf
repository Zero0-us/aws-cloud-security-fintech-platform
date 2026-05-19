# ============================================================================
# VPC
# ============================================================================

resource "aws_vpc" "audit_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = var.vpc_name
  }
}

# ============================================================================
# Subnets
# ============================================================================

resource "aws_subnet" "peering_subnet_2a" {
  vpc_id            = aws_vpc.audit_vpc.id
  cidr_block        = var.peering_subnet_2a_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "fin-audit-peering-sub-2a"
  }
}

resource "aws_subnet" "peering_subnet_2c" {
  vpc_id            = aws_vpc.audit_vpc.id
  cidr_block        = var.peering_subnet_2c_cidr
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "fin-audit-peering-sub-2c"
  }
}

# ============================================================================
# KMS
# ============================================================================

data "aws_caller_identity" "current" {}

locals {
  log_source_account_ids = compact([
    data.aws_caller_identity.current.account_id,
    var.prod_account_id,
    var.dev_account_id,
    var.stage_account_id
  ])

  prod_log_source_account_ids = compact([
    data.aws_caller_identity.current.account_id,
    var.prod_account_id
  ])

  stage_log_source_account_ids = compact([
    data.aws_caller_identity.current.account_id,
    var.stage_account_id
  ])

  dev_log_source_account_ids = compact([
    data.aws_caller_identity.current.account_id,
    var.dev_account_id
  ])

  prod_cloudwatch_logs_source_arns = [
    for account_id in local.prod_log_source_account_ids :
    "arn:aws:logs:${var.aws_region}:${account_id}:log-group:*"
  ]

  stage_cloudwatch_logs_source_arns = [
    for account_id in local.stage_log_source_account_ids :
    "arn:aws:logs:${var.aws_region}:${account_id}:log-group:*"
  ]

  dev_cloudwatch_logs_source_arns = [
    for account_id in local.dev_log_source_account_ids :
    "arn:aws:logs:${var.aws_region}:${account_id}:log-group:*"
  ]

  peering_routes = {
    for route in [
      {
        cidr_block                = var.prod_vpc_cidr
        vpc_peering_connection_id = var.prod_vpc_peering_connection_id
      },
      {
        cidr_block                = var.dev_vpc_cidr
        vpc_peering_connection_id = var.dev_vpc_peering_connection_id
      },
      {
        cidr_block                = var.stage_vpc_cidr
        vpc_peering_connection_id = var.stage_vpc_peering_connection_id
      }
    ] : route.cidr_block => route if route.vpc_peering_connection_id != ""
  }

  service_log_intake_manifest = {
    version = "2026-05-06"
    purpose = "CloudWatch Logs based central SOC log archive intake contract"
    central_buckets = {
      prod   = var.soc_audit_log_bucket_name
      stage  = var.stage_log_bucket_name
      dev    = var.dev_log_bucket_name
      athena = var.soc_athena_results_bucket_name
    }
    accepted_sources = [
      {
        service = "cloudtrail"
        prefix  = "cloudwatch-exports/cloudtrail/<log-group-name>/"
        status  = "export_from_workload_cloudwatch_logs"
      },
      {
        service = "aws-config"
        prefix  = "cloudwatch-exports/config/<log-group-name>/"
        status  = "export_from_workload_cloudwatch_logs"
      },
      {
        service = "vpc-flow-logs"
        prefix  = "cloudwatch-exports/vpc-flow-logs/<log-group-name>/"
        status  = "export_from_workload_cloudwatch_logs"
      },
      {
        service = "application-logs"
        prefix  = "cloudwatch-exports/app/<log-group-name>/"
        status  = "export_from_workload_cloudwatch_logs"
      },
      {
        service = "soc-cloudwatch-logs"
        prefix  = "soc-logs/cloudwatch-exports/<log-group-name>/"
        status  = "export_from_soc_cloudwatch_logs"
      },
      {
        service = "alb-access-logs"
        prefix  = "alb/AWSLogs/<account-id>/"
        status  = "central_bucket_policy_ready_configure_in_workload_accounts"
      },
      {
        service = "waf-logs"
        prefix  = "waf/AWSLogs/<account-id>/WAFLogs/"
        status  = "central_bucket_policy_ready_configure_in_workload_accounts"
      },
      {
        service = "eks-audit-logs"
        prefix  = "eks/AWSLogs/<account-id>/"
        status  = "central_bucket_policy_ready_configure_cloudwatch_export_in_workload_accounts"
      }
    ]
  }

  isms_p_control_mapping = {
    version   = "2026-04-30"
    framework = "ISMS-P aligned cloud security baseline"
    controls = [
      {
        control_id = "ISMS-P-2.6.1"
        title      = "Network access control"
        evidence   = "AWS Config INCOMING_SSH_DISABLED and VPC Flow Logs"
        config_rules = [
          "soc-incoming-ssh-disabled",
          "soc-vpc-flow-logs-enabled"
        ]
      },
      {
        control_id = "ISMS-P-2.6.2"
        title      = "Information system access control"
        evidence   = "IAM MFA and root MFA AWS Config managed rules"
        config_rules = [
          "soc-iam-user-mfa-enabled",
          "soc-root-account-mfa-enabled"
        ]
      },
      {
        control_id = "ISMS-P-2.9.4"
        title      = "Log generation and retention"
        evidence   = "CloudTrail, AWS Config delivery, VPC Flow Logs, S3 lifecycle"
        config_rules = [
          "soc-cloudtrail-enabled",
          "soc-vpc-flow-logs-enabled"
        ]
      },
      {
        control_id = "ISMS-P-2.9.5"
        title      = "Log review and monitoring"
        evidence   = "Monthly Lambda report, Athena summaries, SNS notifications"
        config_rules = [
          "soc-cloudtrail-enabled"
        ]
      },
      {
        control_id = "ISMS-P-2.10.1"
        title      = "Security system operation"
        evidence   = "AWS Config rules and audit log review evidence"
        config_rules = [
          "soc-cloudtrail-enabled",
          "soc-s3-encryption-enabled"
        ]
      },
      {
        control_id = "ISMS-P-2.11.1"
        title      = "Incident detection and response evidence"
        evidence   = "Central audit bucket, Athena incident query results, compliance report archive"
        config_rules = [
          "soc-s3-public-read-prohibited",
          "soc-s3-public-write-prohibited",
          "soc-s3-encryption-enabled"
        ]
      }
    ]
  }
}

resource "aws_kms_key" "s3_cmk" {
  description             = "KMS key for S3 log bucket encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIamRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailToEncryptLogs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AllowConfigAndLogDeliveryToUseKey"
        Effect = "Allow"
        Principal = {
          Service = [
            "config.amazonaws.com",
            "delivery.logs.amazonaws.com",
            "logs.${var.aws_region}.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      }
    ]
  })

  tags = {
    Name = var.kms_key_name
  }
}

resource "aws_kms_alias" "s3_cmk_alias" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.s3_cmk.key_id
}

# ============================================================================
# S3 Buckets
# ============================================================================

resource "aws_s3_bucket" "soc_audit_log_bucket" {
  bucket        = var.soc_audit_log_bucket_name
  force_destroy = true

  tags = {
    Name      = var.soc_audit_log_bucket_name
    DataClass = "audit-log"
  }
}

resource "aws_s3_bucket" "stage_log_bucket" {
  bucket        = var.stage_log_bucket_name
  force_destroy = true

  tags = {
    Name      = var.stage_log_bucket_name
    DataClass = "stage-log"
  }
}

resource "aws_s3_bucket" "dev_log_bucket" {
  bucket        = var.dev_log_bucket_name
  force_destroy = true

  tags = {
    Name      = var.dev_log_bucket_name
    DataClass = "dev-log"
  }
}

resource "aws_s3_bucket" "soc_athena_results_bucket" {
  bucket        = var.soc_athena_results_bucket_name
  force_destroy = true

  tags = {
    Name      = var.soc_athena_results_bucket_name
    DataClass = "athena-results"
  }
}

# ============================================================================
# S3 Public Access Block
# ============================================================================

resource "aws_s3_bucket_public_access_block" "soc_audit_log_bucket_pab" {
  bucket = aws_s3_bucket.soc_audit_log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "stage_log_bucket_pab" {
  bucket = aws_s3_bucket.stage_log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "dev_log_bucket_pab" {
  bucket = aws_s3_bucket.dev_log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "soc_athena_results_bucket_pab" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# S3 Versioning
# ============================================================================

resource "aws_s3_bucket_versioning" "soc_audit_log_bucket_versioning" {
  bucket = aws_s3_bucket.soc_audit_log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "stage_log_bucket_versioning" {
  bucket = aws_s3_bucket.stage_log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "dev_log_bucket_versioning" {
  bucket = aws_s3_bucket.dev_log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "soc_athena_results_bucket_versioning" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================================
# S3 Encryption
# ============================================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "soc_audit_log_bucket_encryption" {
  bucket = aws_s3_bucket.soc_audit_log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_cmk.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "stage_log_bucket_encryption" {
  bucket = aws_s3_bucket.stage_log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_cmk.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dev_log_bucket_encryption" {
  bucket = aws_s3_bucket.dev_log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_cmk.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "soc_athena_results_bucket_encryption" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_cmk.arn
    }
    bucket_key_enabled = true
  }
}

# ============================================================================
# S3 Object Ownership
# ============================================================================

resource "aws_s3_bucket_ownership_controls" "soc_audit_log_bucket_ownership" {
  bucket = aws_s3_bucket.soc_audit_log_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "stage_log_bucket_ownership" {
  bucket = aws_s3_bucket.stage_log_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "dev_log_bucket_ownership" {
  bucket = aws_s3_bucket.dev_log_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "soc_athena_results_bucket_ownership" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "soc_audit_log_bucket_lifecycle" {
  bucket = aws_s3_bucket.soc_audit_log_bucket.id

  rule {
    id     = "audit-log-retention"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "stage_log_bucket_lifecycle" {
  bucket = aws_s3_bucket.stage_log_bucket.id

  rule {
    id     = "stage-log-retention"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "dev_log_bucket_lifecycle" {
  bucket = aws_s3_bucket.dev_log_bucket.id

  rule {
    id     = "dev-log-retention"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "soc_athena_results_bucket_lifecycle" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  rule {
    id     = "ops-results-30d"
    status = "Enabled"

    filter {
      prefix = "athena-results/ops/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "security-audit-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/sc-audit/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1095
    }
  }

  rule {
    id     = "incident-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/incident/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }

  rule {
    id     = "compliance-result-staging"
    status = "Enabled"

    filter {
      prefix = "athena-results/compliance-result/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1095
    }
  }

  rule {
    id     = "monthly-audit-query-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/monthly-audit/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1095
    }
  }

  rule {
    id     = "ad-hoc-query-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/ad-hoc/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "temporary-query-results"
    status = "Enabled"

    filter {
      prefix = "athena-results/temp/"
    }

    expiration {
      days = 7
    }
  }

  rule {
    id     = "soc-log-retention"
    status = "Enabled"

    filter {
      prefix = "soc-logs/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }

  rule {
    id     = "compliance-baseline-retention"
    status = "Enabled"

    filter {
      prefix = "baseline/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }

  rule {
    id     = "monthly-audit-report-retention"
    status = "Enabled"

    filter {
      prefix = "monthly-audit/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 1825
    }
  }

  rule {
    id     = "tax-offshore-evidence-retention"
    status = "Enabled"

    filter {
      prefix = "tax-offshore-evidence/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }

  rule {
    id     = "commercial-ledger-retention"
    status = "Enabled"

    filter {
      prefix = "commercial-ledger/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 3650
    }
  }
}

# ============================================================================
# Route Table (Peering Subnet) - 다른 VPC로의 라우팅
# ============================================================================

resource "aws_route_table" "peering_rt" {
  vpc_id = aws_vpc.audit_vpc.id

  dynamic "route" {
    for_each = local.peering_routes

    content {
      cidr_block                = route.value.cidr_block
      vpc_peering_connection_id = route.value.vpc_peering_connection_id
    }
  }

  tags = {
    Name = "fin-audit-peering-rt"
  }
}

resource "aws_route_table_association" "peering_2a_rta" {
  subnet_id      = aws_subnet.peering_subnet_2a.id
  route_table_id = aws_route_table.peering_rt.id
}

resource "aws_route_table_association" "peering_2c_rta" {
  subnet_id      = aws_subnet.peering_subnet_2c.id
  route_table_id = aws_route_table.peering_rt.id
}

# ============================================================================
# VPC Flow Logs (보안 모니터링)
# ============================================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/fin-audit-vpc"
  retention_in_days = var.flow_logs_retention_days

  tags = {
    Name = "fin-audit-vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name_prefix = "vpc-flow-logs-"

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

  tags = {
    Name = "vpc-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name_prefix = "vpc-flow-logs-"
  role        = aws_iam_role.vpc_flow_logs_role.id

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
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = aws_vpc.audit_vpc.id

  tags = {
    Name = "fin-audit-vpc-flow-logs"
  }

  depends_on = [aws_iam_role_policy.vpc_flow_logs_policy]
}

# S3에 VPC Flow Logs 저장 (장기 보관)
resource "aws_flow_log" "vpc_flow_log_s3" {
  log_destination_type = "s3"
  log_destination      = "arn:aws:s3:::${aws_s3_bucket.soc_athena_results_bucket.id}/soc-logs/vpc-flow-logs/"
  traffic_type         = var.flow_logs_traffic_type
  vpc_id               = aws_vpc.audit_vpc.id

  tags = {
    Name = "fin-audit-vpc-flow-logs-s3"
  }

  depends_on = [
    aws_s3_bucket_policy.soc_athena_results_bucket_policy,
    aws_s3_bucket_server_side_encryption_configuration.soc_athena_results_bucket_encryption
  ]
}

# ============================================================================
# CloudTrail (감사 추적 - 모든 API 호출 기록)
# ============================================================================

resource "aws_cloudtrail" "audit_trail" {
  name                          = "fin-audit-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.soc_athena_results_bucket.id
  s3_key_prefix                 = "soc-logs/cloudtrail"
  kms_key_id                    = aws_kms_key.s3_cmk.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.soc_athena_results_bucket_policy]

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"
      values = [
        "${aws_s3_bucket.soc_audit_log_bucket.arn}/",
        "${aws_s3_bucket.stage_log_bucket.arn}/",
        "${aws_s3_bucket.dev_log_bucket.arn}/",
        "${aws_s3_bucket.soc_athena_results_bucket.arn}/"
      ]
    }

  }

  tags = {
    Name = "fin-audit-cloudtrail"
  }
}

# Central log archive S3 policy
resource "aws_s3_bucket_policy" "soc_audit_log_bucket_policy" {
  bucket = aws_s3_bucket.soc_audit_log_bucket.id

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
        Resource = aws_s3_bucket.soc_audit_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_audit_log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailCrossAccountWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_audit_log_bucket.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.soc_audit_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.soc_audit_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_audit_log_bucket.arn}/AWSLogs/*/Config/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.soc_audit_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_audit_log_bucket.arn}/vpc-flow-logs/AWSLogs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSServiceLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = [
            "delivery.logs.amazonaws.com",
            "logdelivery.elasticloadbalancing.amazonaws.com"
          ]
        }
        Action = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.soc_audit_log_bucket.arn}/alb/AWSLogs/*",
          "${aws_s3_bucket.soc_audit_log_bucket.arn}/waf/AWSLogs/*",
          "${aws_s3_bucket.soc_audit_log_bucket.arn}/eks/AWSLogs/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "CloudWatchLogsExportAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.soc_audit_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.prod_log_source_account_ids
          }
          ArnLike = {
            "aws:SourceArn" = local.prod_cloudwatch_logs_source_arns
          }
        }
      },
      {
        Sid    = "CloudWatchLogsExportWrite"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_audit_log_bucket.arn}/cloudwatch-exports/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.prod_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
          ArnLike = {
            "aws:SourceArn" = local.prod_cloudwatch_logs_source_arns
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.soc_audit_log_bucket.arn,
          "${aws_s3_bucket.soc_audit_log_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "stage_log_bucket_policy" {
  bucket = aws_s3_bucket.stage_log_bucket.id

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
        Resource = aws_s3_bucket.stage_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.stage_log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailCrossAccountWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.stage_log_bucket.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.stage_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.stage_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.stage_log_bucket.arn}/AWSLogs/*/Config/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.stage_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.stage_log_bucket.arn}/vpc-flow-logs/AWSLogs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSServiceLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = [
            "delivery.logs.amazonaws.com",
            "logdelivery.elasticloadbalancing.amazonaws.com"
          ]
        }
        Action = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.stage_log_bucket.arn}/alb/AWSLogs/*",
          "${aws_s3_bucket.stage_log_bucket.arn}/waf/AWSLogs/*",
          "${aws_s3_bucket.stage_log_bucket.arn}/eks/AWSLogs/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "CloudWatchLogsExportAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.stage_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.stage_log_source_account_ids
          }
          ArnLike = {
            "aws:SourceArn" = local.stage_cloudwatch_logs_source_arns
          }
        }
      },
      {
        Sid    = "CloudWatchLogsExportWrite"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.stage_log_bucket.arn}/cloudwatch-exports/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.stage_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
          ArnLike = {
            "aws:SourceArn" = local.stage_cloudwatch_logs_source_arns
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.stage_log_bucket.arn,
          "${aws_s3_bucket.stage_log_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "dev_log_bucket_policy" {
  bucket = aws_s3_bucket.dev_log_bucket.id

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
        Resource = aws_s3_bucket.dev_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSCloudTrailCrossAccountWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dev_log_bucket.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.dev_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.dev_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dev_log_bucket.arn}/AWSLogs/*/Config/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.dev_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dev_log_bucket.arn}/vpc-flow-logs/AWSLogs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSServiceLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = [
            "delivery.logs.amazonaws.com",
            "logdelivery.elasticloadbalancing.amazonaws.com"
          ]
        }
        Action = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.dev_log_bucket.arn}/alb/AWSLogs/*",
          "${aws_s3_bucket.dev_log_bucket.arn}/waf/AWSLogs/*",
          "${aws_s3_bucket.dev_log_bucket.arn}/eks/AWSLogs/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "CloudWatchLogsExportAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.dev_log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
          }
          ArnLike = {
            "aws:SourceArn" = local.dev_cloudwatch_logs_source_arns
          }
        }
      },
      {
        Sid    = "CloudWatchLogsExportWrite"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dev_log_bucket.arn}/cloudwatch-exports/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.dev_log_source_account_ids
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
          ArnLike = {
            "aws:SourceArn" = local.dev_cloudwatch_logs_source_arns
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.dev_log_bucket.arn,
          "${aws_s3_bucket.dev_log_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "soc_athena_results_bucket_policy" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SOCCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.soc_athena_results_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "SOCCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_athena_results_bucket.arn}/soc-logs/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "SOCConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.soc_athena_results_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "SOCConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.soc_athena_results_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "SOCConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_athena_results_bucket.arn}/soc-logs/config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "SOCLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.soc_athena_results_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "SOCLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_athena_results_bucket.arn}/soc-logs/vpc-flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "SOCCloudWatchLogsExportAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.soc_athena_results_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
      {
        Sid    = "SOCCloudWatchLogsExportWrite"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.soc_athena_results_bucket.arn}/soc-logs/cloudwatch-exports/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.soc_athena_results_bucket.arn,
          "${aws_s3_bucket.soc_athena_results_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================================
# Compliance Evidence Baselines
# ============================================================================

resource "aws_s3_object" "service_log_intake_manifest" {
  bucket                 = aws_s3_bucket.soc_athena_results_bucket.id
  key                    = "baseline/service-log-intake-manifest.json"
  content                = jsonencode(local.service_log_intake_manifest)
  content_type           = "application/json"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.s3_cmk.arn

  depends_on = [
    aws_s3_bucket_policy.soc_athena_results_bucket_policy,
    aws_s3_bucket_server_side_encryption_configuration.soc_athena_results_bucket_encryption
  ]
}

resource "aws_s3_object" "isms_p_control_mapping" {
  bucket                 = aws_s3_bucket.soc_athena_results_bucket.id
  key                    = "baseline/isms-p-control-mapping.json"
  content                = jsonencode(local.isms_p_control_mapping)
  content_type           = "application/json"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.s3_cmk.arn

  depends_on = [
    aws_s3_bucket_policy.soc_athena_results_bucket_policy,
    aws_s3_bucket_server_side_encryption_configuration.soc_athena_results_bucket_encryption
  ]
}

# ============================================================================
# AWS Config (컴플라이언스 모니터링)
# ============================================================================

resource "aws_iam_role" "config_role" {
  name_prefix = "aws-config-"

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

  tags = {
    Name = "aws-config-role"
  }
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "recorder" {
  name       = "fin-audit-config-recorder"
  role_arn   = aws_iam_role.config_role.arn
  depends_on = [aws_iam_role_policy_attachment.config_policy]

  recording_group {
    all_supported = true
  }
}

resource "aws_config_configuration_recorder_status" "recorder_status" {
  name       = aws_config_configuration_recorder.recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.channel]
}

resource "aws_config_delivery_channel" "channel" {
  name           = "fin-audit-config-channel"
  s3_bucket_name = aws_s3_bucket.soc_athena_results_bucket.id
  s3_key_prefix  = "soc-logs/config"
  s3_kms_key_arn = aws_kms_key.s3_cmk.arn
  depends_on = [
    aws_config_configuration_recorder.recorder,
    aws_s3_bucket_policy.soc_athena_results_bucket_policy
  ]
}

# ============================================================================
# Compliance Monitoring and Audit Automation
# ============================================================================

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "soc-cloudtrail-enabled"
  description = "Checks whether CloudTrail is enabled for the account."

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "s3_public_read_prohibited" {
  name        = "soc-s3-public-read-prohibited"
  description = "Checks that S3 buckets do not allow public read access."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "s3_public_write_prohibited" {
  name        = "soc-s3-public-write-prohibited"
  description = "Checks that S3 buckets do not allow public write access."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "s3_encryption_enabled" {
  name        = "soc-s3-encryption-enabled"
  description = "Checks that S3 buckets have server-side encryption enabled."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  name        = "soc-vpc-flow-logs-enabled"
  description = "Checks that VPC Flow Logs are enabled."

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "incoming_ssh_disabled" {
  name        = "soc-incoming-ssh-disabled"
  description = "Checks that security groups do not allow unrestricted SSH access."

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "iam_user_mfa_enabled" {
  name        = "soc-iam-user-mfa-enabled"
  description = "Checks whether MFA is enabled for IAM users."

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_config_config_rule" "root_account_mfa_enabled" {
  name        = "soc-root-account-mfa-enabled"
  description = "Checks whether MFA is enabled for the root user."

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.recorder_status]
}

resource "aws_sns_topic" "soc_audit_notifications" {
  name = "fin-soc-audit-notifications"

  tags = {
    Name = "fin-soc-audit-notifications"
  }
}

resource "aws_sns_topic_subscription" "soc_audit_email" {
  count     = var.audit_notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.soc_audit_notifications.arn
  protocol  = "email"
  endpoint  = var.audit_notification_email
}

resource "aws_sns_topic_policy" "soc_audit_notifications" {
  arn = aws_sns_topic.soc_audit_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.soc_audit_notifications.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name        = "fin-soc-config-noncompliant"
  description = "Routes AWS Config non-compliant changes to SOC audit notifications."

  event_pattern = jsonencode({
    source        = ["aws.config"]
    "detail-type" = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "config_noncompliant_sns" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "soc-audit-notifications"
  arn       = aws_sns_topic.soc_audit_notifications.arn
}

resource "aws_cloudwatch_event_rule" "monthly_audit_report" {
  name                = "fin-soc-monthly-audit-report"
  description         = "Runs the monthly SOC audit report generator."
  schedule_expression = var.monthly_audit_schedule_expression
}

locals {
  config_rule_names = [
    aws_config_config_rule.cloudtrail_enabled.name,
    aws_config_config_rule.s3_public_read_prohibited.name,
    aws_config_config_rule.s3_public_write_prohibited.name,
    aws_config_config_rule.s3_encryption_enabled.name,
    aws_config_config_rule.vpc_flow_logs_enabled.name,
    aws_config_config_rule.incoming_ssh_disabled.name,
    aws_config_config_rule.iam_user_mfa_enabled.name,
    aws_config_config_rule.root_account_mfa_enabled.name
  ]

  cloudwatch_export_targets = concat(
    var.prod_account_id != "" ? [
      {
        name               = "prod"
        account_id         = var.prod_account_id
        role_arn           = "arn:aws:iam::${var.prod_account_id}:role/${var.cloudwatch_export_role_name}"
        bucket             = aws_s3_bucket.soc_audit_log_bucket.id
        destination_prefix = "cloudwatch-exports"
      }
    ] : [],
    var.stage_account_id != "" ? [
      {
        name               = "stg"
        account_id         = var.stage_account_id
        role_arn           = "arn:aws:iam::${var.stage_account_id}:role/${var.cloudwatch_export_role_name}"
        bucket             = aws_s3_bucket.stage_log_bucket.id
        destination_prefix = "cloudwatch-exports"
      }
    ] : [],
    var.dev_account_id != "" ? [
      {
        name               = "dev"
        account_id         = var.dev_account_id
        role_arn           = "arn:aws:iam::${var.dev_account_id}:role/${var.cloudwatch_export_role_name}"
        bucket             = aws_s3_bucket.dev_log_bucket.id
        destination_prefix = "cloudwatch-exports"
      }
    ] : [],
    [
      {
        name               = "soc"
        account_id         = data.aws_caller_identity.current.account_id
        role_arn           = ""
        bucket             = aws_s3_bucket.soc_athena_results_bucket.id
        destination_prefix = "soc-logs/cloudwatch-exports"
      }
    ]
  )

  cloudwatch_export_role_arns = [
    for target in local.cloudwatch_export_targets : target.role_arn
    if target.role_arn != ""
  ]
}

data "archive_file" "monthly_audit_report" {
  type        = "zip"
  source_file = "${path.module}/lambda/monthly_audit_report.py"
  output_path = "${path.module}/build/monthly_audit_report.zip"
}

resource "aws_iam_role" "monthly_audit_report_lambda" {
  name_prefix = "monthly-audit-report-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "monthly-audit-report-lambda-role"
  }
}

resource "aws_iam_role_policy" "monthly_audit_report_lambda" {
  name_prefix = "monthly-audit-report-"
  role        = aws_iam_role.monthly_audit_report_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/fin-soc-monthly-audit-report*"
      },
      {
        Sid    = "ReadConfigCompliance"
        Effect = "Allow"
        Action = [
          "config:DescribeComplianceByConfigRule",
          "config:DescribeConfigRules",
          "config:GetComplianceDetailsByConfigRule"
        ]
        Resource = "*"
      },
      {
        Sid    = "RunAthenaAuditQueries"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = [
          aws_athena_workgroup.soc_logs.arn
        ]
      },
      {
        Sid    = "ReadGlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadAuditLogsAndBaselines"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.soc_audit_log_bucket.arn,
          "${aws_s3_bucket.soc_audit_log_bucket.arn}/*",
          aws_s3_bucket.stage_log_bucket.arn,
          "${aws_s3_bucket.stage_log_bucket.arn}/*",
          aws_s3_bucket.dev_log_bucket.arn,
          "${aws_s3_bucket.dev_log_bucket.arn}/*",
          aws_s3_bucket.soc_athena_results_bucket.arn,
          "${aws_s3_bucket.soc_athena_results_bucket.arn}/*"
        ]
      },
      {
        Sid    = "WriteReportsAndAthenaResults"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.soc_athena_results_bucket.arn,
          "${aws_s3_bucket.soc_athena_results_bucket.arn}/athena-results/monthly-audit/*",
          "${aws_s3_bucket.soc_athena_results_bucket.arn}/monthly-audit/*"
        ]
      },
      {
        Sid    = "UseReportKmsKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.s3_cmk.arn
      },
      {
        Sid      = "PublishAuditNotification"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.soc_audit_notifications.arn
      }
    ]
  })
}

resource "aws_lambda_function" "monthly_audit_report" {
  function_name    = "fin-soc-monthly-audit-report"
  role             = aws_iam_role.monthly_audit_report_lambda.arn
  handler          = "monthly_audit_report.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.monthly_audit_report.output_path
  source_code_hash = data.archive_file.monthly_audit_report.output_base64sha256
  timeout          = 900
  memory_size      = 256

  environment {
    variables = {
      COMPLIANCE_BUCKET       = aws_s3_bucket.soc_athena_results_bucket.id
      ATHENA_DATABASE         = aws_glue_catalog_database.soc_logs.name
      ATHENA_WORKGROUP        = aws_athena_workgroup.soc_logs.name
      ATHENA_RESULTS_BUCKET   = aws_s3_bucket.soc_athena_results_bucket.id
      SNS_TOPIC_ARN           = aws_sns_topic.soc_audit_notifications.arn
      CONTROL_MAPPING_KEY     = aws_s3_object.isms_p_control_mapping.key
      LOG_INTAKE_MANIFEST_KEY = aws_s3_object.service_log_intake_manifest.key
      CONFIG_RULE_NAMES       = join(",", local.config_rule_names)
    }
  }

  depends_on = [
    aws_iam_role_policy.monthly_audit_report_lambda,
    aws_s3_object.isms_p_control_mapping,
    aws_s3_object.service_log_intake_manifest
  ]

  tags = {
    Name = "fin-soc-monthly-audit-report"
  }
}

resource "aws_cloudwatch_event_target" "monthly_audit_report_lambda" {
  rule      = aws_cloudwatch_event_rule.monthly_audit_report.name
  target_id = "soc-monthly-audit-report"
  arn       = aws_lambda_function.monthly_audit_report.arn
}

resource "aws_lambda_permission" "allow_monthly_audit_eventbridge" {
  statement_id  = "AllowMonthlyAuditEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monthly_audit_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_audit_report.arn
}

resource "aws_cloudwatch_event_rule" "cloudwatch_logs_export" {
  name                = "fin-soc-cloudwatch-logs-export"
  description         = "Runs the central SOC CloudWatch Logs export scheduler."
  schedule_expression = var.cloudwatch_export_schedule_expression
}

data "archive_file" "cloudwatch_logs_export" {
  type        = "zip"
  source_file = "${path.module}/lambda/cloudwatch_logs_export.py"
  output_path = "${path.module}/build/cloudwatch_logs_export.zip"
}

resource "aws_iam_role" "cloudwatch_logs_export_lambda" {
  name_prefix = "cloudwatch-logs-export-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "cloudwatch-logs-export-lambda-role"
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs_export_lambda" {
  name_prefix = "cloudwatch-logs-export-"
  role        = aws_iam_role.cloudwatch_logs_export_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "WriteLambdaLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/fin-soc-cloudwatch-logs-export*"
        },
        {
          Sid    = "ManageSocCloudWatchExportTasks"
          Effect = "Allow"
          Action = [
            "logs:CreateExportTask",
            "logs:DescribeExportTasks",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:CancelExportTask"
          ]
          Resource = "*"
        },
        {
          Sid      = "PublishExportNotification"
          Effect   = "Allow"
          Action   = "sns:Publish"
          Resource = aws_sns_topic.soc_audit_notifications.arn
        }
      ],
      length(local.cloudwatch_export_role_arns) > 0 ? [
        {
          Sid      = "AssumeWorkloadCloudWatchExportRoles"
          Effect   = "Allow"
          Action   = "sts:AssumeRole"
          Resource = local.cloudwatch_export_role_arns
        }
      ] : []
    )
  })
}

resource "aws_lambda_function" "cloudwatch_logs_export" {
  function_name    = "fin-soc-cloudwatch-logs-export"
  role             = aws_iam_role.cloudwatch_logs_export_lambda.arn
  handler          = "cloudwatch_logs_export.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.cloudwatch_logs_export.output_path
  source_code_hash = data.archive_file.cloudwatch_logs_export.output_base64sha256
  timeout          = 900
  memory_size      = 256

  environment {
    variables = {
      AWS_REGION_NAME       = var.aws_region
      TARGET_ACCOUNTS       = jsonencode(local.cloudwatch_export_targets)
      LOG_GROUP_PREFIXES    = jsonencode(var.cloudwatch_export_log_group_prefixes)
      LOOKBACK_HOURS        = tostring(var.cloudwatch_export_lookback_hours)
      MAX_TASKS_PER_ACCOUNT = tostring(var.cloudwatch_export_max_tasks_per_account)
      SNS_TOPIC_ARN         = aws_sns_topic.soc_audit_notifications.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.cloudwatch_logs_export_lambda,
    aws_s3_bucket_policy.soc_audit_log_bucket_policy,
    aws_s3_bucket_policy.stage_log_bucket_policy,
    aws_s3_bucket_policy.dev_log_bucket_policy,
    aws_s3_bucket_policy.soc_athena_results_bucket_policy
  ]

  tags = {
    Name = "fin-soc-cloudwatch-logs-export"
  }
}

resource "aws_cloudwatch_event_target" "cloudwatch_logs_export_lambda" {
  rule      = aws_cloudwatch_event_rule.cloudwatch_logs_export.name
  target_id = "soc-cloudwatch-logs-export"
  arn       = aws_lambda_function.cloudwatch_logs_export.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_logs_export_eventbridge" {
  statement_id  = "AllowCloudWatchLogsExportEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_logs_export.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudwatch_logs_export.arn
}

# ============================================================================
# Athena (SOC Log Analysis)
# ============================================================================

resource "aws_glue_catalog_database" "soc_logs" {
  name        = var.athena_database_name
  description = "SOC log archive database for CloudTrail and VPC Flow Logs"
}

resource "aws_athena_workgroup" "soc_logs" {
  name          = var.athena_workgroup_name
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = false

    result_configuration {
      output_location = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/athena-results/sc-audit/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.s3_cmk.arn
      }
    }
  }

  tags = {
    Name = var.athena_workgroup_name
  }

  depends_on = [aws_s3_bucket_policy.soc_athena_results_bucket_policy]
}

resource "aws_athena_named_query" "create_cloudtrail_table" {
  name        = "create-cloudtrail-logs-table"
  workgroup   = aws_athena_workgroup.soc_logs.name
  database    = aws_glue_catalog_database.soc_logs.name
  description = "Template query to create a CloudTrail table over the central SOC S3 log archive"
  query       = <<-SQL
    CREATE EXTERNAL TABLE IF NOT EXISTS cloudtrail_logs (
      eventversion string,
      useridentity string,
      eventtime string,
      eventsource string,
      eventname string,
      awsregion string,
      sourceipaddress string,
      useragent string,
      errorcode string,
      errormessage string,
      requestparameters string,
      responseelements string,
      additionaleventdata string,
      requestid string,
      eventid string,
      readonly string,
      resources string,
      eventtype string,
      apiversion string,
      recipientaccountid string,
      serviceeventdetails string,
      sharedeventid string,
      vpcendpointid string
    )
    ROW FORMAT SERDE 'com.amazon.emr.hive.serde.CloudTrailSerde'
    STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
    OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
    LOCATION 's3://${aws_s3_bucket.soc_athena_results_bucket.id}/soc-logs/cloudtrail/AWSLogs/';
  SQL
}

resource "aws_athena_named_query" "create_vpc_flow_logs_table" {
  name        = "create-vpc-flow-logs-table"
  workgroup   = aws_athena_workgroup.soc_logs.name
  database    = aws_glue_catalog_database.soc_logs.name
  description = "Template query to create a VPC Flow Logs table over the central SOC S3 log archive"
  query       = <<-SQL
    CREATE EXTERNAL TABLE IF NOT EXISTS vpc_flow_logs (
      version int,
      account_id string,
      interface_id string,
      srcaddr string,
      dstaddr string,
      srcport int,
      dstport int,
      protocol bigint,
      packets bigint,
      bytes bigint,
      start_time bigint,
      end_time bigint,
      action string,
      log_status string
    )
    ROW FORMAT DELIMITED
    FIELDS TERMINATED BY ' '
    LOCATION 's3://${aws_s3_bucket.soc_athena_results_bucket.id}/soc-logs/vpc-flow-logs/AWSLogs/';
  SQL
}

resource "aws_athena_named_query" "create_workload_cloudwatch_export_tables" {
  name        = "create-workload-cloudwatch-export-tables"
  workgroup   = aws_athena_workgroup.soc_logs.name
  database    = aws_glue_catalog_database.soc_logs.name
  description = "Template query to create raw CloudWatch Logs export tables for Prod, Staging, and Dev buckets"
  query       = <<-SQL
    CREATE EXTERNAL TABLE IF NOT EXISTS prod_cloudwatch_exports (
      raw_line string
    )
    ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
    WITH SERDEPROPERTIES ('input.regex'='^(.*)$')
    STORED AS TEXTFILE
    LOCATION 's3://${aws_s3_bucket.soc_audit_log_bucket.id}/cloudwatch-exports/';

    CREATE EXTERNAL TABLE IF NOT EXISTS stg_cloudwatch_exports (
      raw_line string
    )
    ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
    WITH SERDEPROPERTIES ('input.regex'='^(.*)$')
    STORED AS TEXTFILE
    LOCATION 's3://${aws_s3_bucket.stage_log_bucket.id}/cloudwatch-exports/';

    CREATE EXTERNAL TABLE IF NOT EXISTS dev_cloudwatch_exports (
      raw_line string
    )
    ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
    WITH SERDEPROPERTIES ('input.regex'='^(.*)$')
    STORED AS TEXTFILE
    LOCATION 's3://${aws_s3_bucket.dev_log_bucket.id}/cloudwatch-exports/';
  SQL
}

resource "aws_athena_named_query" "recent_cloudtrail_errors" {
  name        = "recent-cloudtrail-errors"
  workgroup   = aws_athena_workgroup.soc_logs.name
  database    = aws_glue_catalog_database.soc_logs.name
  description = "Investigate recent AWS API errors after creating the CloudTrail table"
  query       = <<-SQL
    SELECT eventtime, recipientaccountid, eventsource, eventname, sourceipaddress, errorcode, errormessage
    FROM cloudtrail_logs
    WHERE errorcode IS NOT NULL
    ORDER BY eventtime DESC
    LIMIT 100;
  SQL
}

resource "aws_athena_named_query" "rejected_vpc_flows" {
  name        = "rejected-vpc-flows"
  workgroup   = aws_athena_workgroup.soc_logs.name
  database    = aws_glue_catalog_database.soc_logs.name
  description = "Investigate rejected VPC flows after creating the VPC Flow Logs table"
  query       = <<-SQL
    SELECT account_id, interface_id, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, action
    FROM vpc_flow_logs
    WHERE action = 'REJECT'
    LIMIT 100;
  SQL
}

resource "aws_athena_named_query" "monthly_cloudtrail_activity_summary" {
  name        = "monthly-cloudtrail-activity-summary"
  workgroup   = aws_athena_workgroup.soc_logs.name
  database    = aws_glue_catalog_database.soc_logs.name
  description = "Monthly CloudTrail activity summary for SOC audit reports"
  query       = <<-SQL
    SELECT recipientaccountid, eventsource, eventname, COUNT(*) AS event_count
    FROM cloudtrail_logs
    WHERE eventtime >= date_format(date_add('month', -1, current_date), '%Y-%m-%d')
    GROUP BY recipientaccountid, eventsource, eventname
    ORDER BY event_count DESC
    LIMIT 200;
  SQL
}

# ============================================================================
# 현재 region 정보
data "aws_region" "current" {
}
