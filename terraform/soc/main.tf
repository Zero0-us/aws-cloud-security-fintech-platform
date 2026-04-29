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

resource "aws_subnet" "bastion_subnet_2a" {
  vpc_id            = aws_vpc.audit_vpc.id
  cidr_block        = var.bastion_subnet_2a_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "fin-audit-bastion-sub-2a"
  }
}

resource "aws_subnet" "bastion_subnet_2c" {
  vpc_id            = aws_vpc.audit_vpc.id
  cidr_block        = var.bastion_subnet_2c_cidr
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "fin-audit-bastion-sub-2c"
  }
}

resource "aws_subnet" "tgw_subnet_2a" {
  vpc_id            = aws_vpc.audit_vpc.id
  cidr_block        = var.tgw_subnet_2a_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "fin-audit-tgw-sub-2a"
  }
}

resource "aws_subnet" "tgw_subnet_2c" {
  vpc_id            = aws_vpc.audit_vpc.id
  cidr_block        = var.tgw_subnet_2c_cidr
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "fin-audit-tgw-sub-2c"
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
    var.dev_account_id
  ])

  peering_routes = {
    for route in [
      {
        cidr_block                = var.prod_vpc_cidr
        vpc_peering_connection_id = var.prod_vpc_peering_connection_id
      },
      {
        cidr_block                = var.dev_vpc_cidr
        vpc_peering_connection_id = var.dev_vpc_peering_connection_id
      }
    ] : route.cidr_block => route if route.vpc_peering_connection_id != ""
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
            "delivery.logs.amazonaws.com"
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
  bucket        = "${var.soc_audit_log_bucket_name}-${var.log_bucket_suffix}"
  force_destroy = true

  tags = {
    Name      = "${var.soc_audit_log_bucket_name}-${var.log_bucket_suffix}"
    DataClass = "audit-log"
  }
}

resource "aws_s3_bucket" "soc_compliance_bucket" {
  bucket        = "${var.soc_compliance_bucket_name}-${var.log_bucket_suffix}"
  force_destroy = true

  tags = {
    Name      = "${var.soc_compliance_bucket_name}-${var.log_bucket_suffix}"
    DataClass = "compliance"
  }
}

resource "aws_s3_bucket" "soc_athena_results_bucket" {
  bucket        = "${var.soc_athena_results_bucket_name}-${var.log_bucket_suffix}"
  force_destroy = true

  tags = {
    Name      = "${var.soc_athena_results_bucket_name}-${var.log_bucket_suffix}"
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

resource "aws_s3_bucket_public_access_block" "soc_compliance_bucket_pab" {
  bucket = aws_s3_bucket.soc_compliance_bucket.id

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

resource "aws_s3_bucket_versioning" "soc_compliance_bucket_versioning" {
  bucket = aws_s3_bucket.soc_compliance_bucket.id

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

resource "aws_s3_bucket_server_side_encryption_configuration" "soc_compliance_bucket_encryption" {
  bucket = aws_s3_bucket.soc_compliance_bucket.id

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

resource "aws_s3_bucket_ownership_controls" "soc_compliance_bucket_ownership" {
  bucket = aws_s3_bucket.soc_compliance_bucket.id

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
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "soc_compliance_bucket_lifecycle" {
  bucket = aws_s3_bucket.soc_compliance_bucket.id

  rule {
    id     = "compliance-retention"
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
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "soc_athena_results_bucket_lifecycle" {
  bucket = aws_s3_bucket.soc_athena_results_bucket.id

  rule {
    id     = "ops-results-30d"
    status = "Enabled"

    filter {
      prefix = "ops/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "security-audit-results"
    status = "Enabled"

    filter {
      prefix = "sc-audit/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "incident-results"
    status = "Enabled"

    filter {
      prefix = "incident/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "compliance-result-staging"
    status = "Enabled"

    filter {
      prefix = "compliance-result/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

# ============================================================================
# Internet Gateway
# ============================================================================

resource "aws_internet_gateway" "audit_igw" {
  vpc_id = aws_vpc.audit_vpc.id

  tags = {
    Name = "fin-audit-igw"
  }
}

# ============================================================================
# Route Table (Bastion Subnet)
# ============================================================================

resource "aws_route_table" "bastion_rt" {
  vpc_id = aws_vpc.audit_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.audit_igw.id
  }

  dynamic "route" {
    for_each = local.peering_routes

    content {
      cidr_block                = route.value.cidr_block
      vpc_peering_connection_id = route.value.vpc_peering_connection_id
    }
  }

  tags = {
    Name = "fin-audit-bastion-rt"
  }
}

# ============================================================================
# Route Table (TGW Subnet) - 다른 VPC로의 라우팅
# ============================================================================

resource "aws_route_table" "tgw_rt" {
  vpc_id = aws_vpc.audit_vpc.id

  dynamic "route" {
    for_each = var.transit_gateway_id != "" ? [var.prod_vpc_cidr, var.dev_vpc_cidr] : []

    content {
      cidr_block         = route.value
      transit_gateway_id = var.transit_gateway_id
    }
  }

  dynamic "route" {
    for_each = local.peering_routes

    content {
      cidr_block                = route.value.cidr_block
      vpc_peering_connection_id = route.value.vpc_peering_connection_id
    }
  }

  tags = {
    Name = "fin-audit-tgw-rt"
  }
}

resource "aws_route_table_association" "bastion_2a_rta" {
  subnet_id      = aws_subnet.bastion_subnet_2a.id
  route_table_id = aws_route_table.bastion_rt.id
}

resource "aws_route_table_association" "bastion_2c_rta" {
  subnet_id      = aws_subnet.bastion_subnet_2c.id
  route_table_id = aws_route_table.bastion_rt.id
}

# ============================================================================
# Route Table Association for TGW Subnet
# ============================================================================

resource "aws_route_table_association" "tgw_2a_rta" {
  subnet_id      = aws_subnet.tgw_subnet_2a.id
  route_table_id = aws_route_table.tgw_rt.id
}

resource "aws_route_table_association" "tgw_2c_rta" {
  subnet_id      = aws_subnet.tgw_subnet_2c.id
  route_table_id = aws_route_table.tgw_rt.id
}

# ============================================================================
# Security Group (Bastion)
# ============================================================================

resource "aws_security_group" "bastion_sg" {
  name_prefix = "fin-audit-bastion-"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.audit_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-audit-bastion-sg"
  }
}

# ============================================================================
# Data source for latest Amazon Linux 2 AMI
# ============================================================================

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# EC2 Bastion Instance
# ============================================================================

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.bastion_subnet_2a.id
  key_name               = var.bastion_key_pair_name != "" ? var.bastion_key_pair_name : null
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  associate_public_ip_address = true

  tags = {
    Name = "fin-audit-bastion"
  }
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
  log_destination      = "arn:aws:s3:::${aws_s3_bucket.soc_audit_log_bucket.id}/vpc-flow-logs/"
  traffic_type         = var.flow_logs_traffic_type
  vpc_id               = aws_vpc.audit_vpc.id

  tags = {
    Name = "fin-audit-vpc-flow-logs-s3"
  }

  depends_on = [
    aws_s3_bucket_policy.soc_audit_log_bucket_policy,
    aws_s3_bucket_server_side_encryption_configuration.soc_audit_log_bucket_encryption
  ]
}

# ============================================================================
# CloudTrail (감사 추적 - 모든 API 호출 기록)
# ============================================================================

resource "aws_cloudtrail" "audit_trail" {
  name                          = "fin-audit-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.soc_audit_log_bucket.id
  kms_key_id                    = aws_kms_key.s3_cmk.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.soc_audit_log_bucket_policy]

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"
      values = [
        "${aws_s3_bucket.soc_audit_log_bucket.arn}/",
        "${aws_s3_bucket.soc_compliance_bucket.arn}/"
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

resource "aws_s3_bucket_policy" "soc_compliance_bucket_policy" {
  bucket = aws_s3_bucket.soc_compliance_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.soc_compliance_bucket.arn,
          "${aws_s3_bucket.soc_compliance_bucket.arn}/*"
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
  s3_bucket_name = aws_s3_bucket.soc_audit_log_bucket.id
  s3_kms_key_arn = aws_kms_key.s3_cmk.arn
  depends_on = [
    aws_config_configuration_recorder.recorder,
    aws_s3_bucket_policy.soc_audit_log_bucket_policy
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
  description         = "Monthly SOC audit report reminder."
  schedule_expression = var.monthly_audit_schedule_expression
}

resource "aws_cloudwatch_event_target" "monthly_audit_report_sns" {
  rule      = aws_cloudwatch_event_rule.monthly_audit_report.name
  target_id = "soc-monthly-audit-report"
  arn       = aws_sns_topic.soc_audit_notifications.arn

  input = jsonencode({
    title            = "Monthly SOC audit report"
    message          = "Run the SOC audit review using AWS Config compliance results and Athena named queries, then archive the report in the SOC compliance bucket."
    compliance_s3    = "s3://${aws_s3_bucket.soc_compliance_bucket.id}/monthly-audit/"
    athena_database  = aws_glue_catalog_database.soc_logs.name
    athena_workgroup = aws_athena_workgroup.soc_logs.name
  })
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
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/sc-audit/"

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
    LOCATION 's3://${aws_s3_bucket.soc_audit_log_bucket.id}/AWSLogs/';
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
    LOCATION 's3://${aws_s3_bucket.soc_audit_log_bucket.id}/vpc-flow-logs/AWSLogs/';
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
# GuardDuty (위협 탐지)
# ============================================================================

resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = {
    Name = "fin-audit-guardduty"
  }
}

# ============================================================================
# Security Hub (중앙 보안 대시보드)
# ============================================================================

resource "aws_securityhub_account" "main" {
  count = var.enable_securityhub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_securityhub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "pci" {
  count         = var.enable_securityhub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.main]
}

# 현재 region 정보
data "aws_region" "current" {
}
