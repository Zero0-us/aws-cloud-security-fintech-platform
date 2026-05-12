output "audit_vpc_id" {
  description = "Audit VPC ID"
  value       = aws_vpc.audit_vpc.id
}

output "audit_vpc_cidr" {
  description = "Audit VPC CIDR block"
  value       = aws_vpc.audit_vpc.cidr_block
}

output "audit_peering_subnet_2a_id" {
  description = "Audit Peering Subnet 2a ID"
  value       = aws_subnet.peering_subnet_2a.id
}

output "audit_peering_subnet_2c_id" {
  description = "Audit Peering Subnet 2c ID"
  value       = aws_subnet.peering_subnet_2c.id
}

output "s3_cmk_arn" {
  description = "S3 KMS CMK ARN"
  value       = aws_kms_key.s3_cmk.arn
}

output "soc_audit_log_bucket_name" {
  description = "SOC audit log bucket name"
  value       = aws_s3_bucket.soc_audit_log_bucket.id
}

output "stage_log_bucket_name" {
  description = "Staging log bucket name"
  value       = aws_s3_bucket.stage_log_bucket.id
}

output "dev_log_bucket_name" {
  description = "Development log bucket name"
  value       = aws_s3_bucket.dev_log_bucket.id
}

output "soc_athena_results_bucket_name" {
  description = "SOC Athena query results bucket name"
  value       = aws_s3_bucket.soc_athena_results_bucket.id
}

output "cloudwatch_logs_export_destinations" {
  description = "S3 destinations prepared for workload CloudWatch Logs export tasks"
  value = {
    prod = "s3://${aws_s3_bucket.soc_audit_log_bucket.id}/cloudwatch-exports/"
    stg  = "s3://${aws_s3_bucket.stage_log_bucket.id}/cloudwatch-exports/"
    dev  = "s3://${aws_s3_bucket.dev_log_bucket.id}/cloudwatch-exports/"
    soc  = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/soc-logs/cloudwatch-exports/"
  }
}

# ============================================================================
# VPC Flow Logs Outputs
# ============================================================================

output "vpc_flow_logs_group_name" {
  description = "CloudWatch Logs Group Name for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "vpc_flow_logs_group_arn" {
  description = "CloudWatch Logs Group ARN for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

# ============================================================================
# CloudTrail Outputs
# ============================================================================

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.audit_trail.arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_cloudtrail.audit_trail.s3_bucket_name
}

# ============================================================================
# Athena Outputs
# ============================================================================

output "athena_database_name" {
  description = "Athena/Glue database for SOC log analysis"
  value       = aws_glue_catalog_database.soc_logs.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup for SOC log analysis"
  value       = aws_athena_workgroup.soc_logs.name
}

output "athena_query_results_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/athena-results/sc-audit/"
}

# ============================================================================
# Compliance Monitoring Outputs
# ============================================================================

output "soc_audit_notifications_topic_arn" {
  description = "SNS topic ARN for SOC audit and compliance notifications"
  value       = aws_sns_topic.soc_audit_notifications.arn
}

output "monthly_audit_report_schedule" {
  description = "EventBridge schedule expression for monthly audit report notification"
  value       = aws_cloudwatch_event_rule.monthly_audit_report.schedule_expression
}

output "monthly_audit_report_lambda_name" {
  description = "Lambda function that generates monthly SOC audit reports"
  value       = aws_lambda_function.monthly_audit_report.function_name
}

output "cloudwatch_logs_export_lambda_name" {
  description = "Central SOC Lambda function that starts CloudWatch Logs export tasks"
  value       = aws_lambda_function.cloudwatch_logs_export.function_name
}

output "cloudwatch_logs_export_schedule" {
  description = "EventBridge schedule expression for the central CloudWatch Logs export Lambda"
  value       = aws_cloudwatch_event_rule.cloudwatch_logs_export.schedule_expression
}

output "cloudwatch_logs_export_assume_role_arns" {
  description = "Workload account role ARNs that must trust the SOC CloudWatch Logs export Lambda role"
  value       = local.cloudwatch_export_role_arns
}

output "cloudwatch_logs_export_lambda_role_arn" {
  description = "SOC Lambda execution role ARN to allow in workload account trust policies"
  value       = aws_iam_role.cloudwatch_logs_export_lambda.arn
}

output "monthly_audit_report_s3_prefix" {
  description = "S3 prefix where monthly SOC audit reports are archived"
  value       = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/monthly-audit/"
}

output "isms_p_control_mapping_s3_uri" {
  description = "S3 URI of the ISMS-P aligned control mapping baseline"
  value       = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/${aws_s3_object.isms_p_control_mapping.key}"
}

output "service_log_intake_manifest_s3_uri" {
  description = "S3 URI of the central service log intake manifest"
  value       = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/${aws_s3_object.service_log_intake_manifest.key}"
}

# ============================================================================
# Routing Outputs
# ============================================================================

output "peering_route_table_id" {
  description = "Peering Subnet Route Table ID"
  value       = aws_route_table.peering_rt.id
}

# VPN EC2 고정 IP (Corp에 전달 필요)
output "vpn_fixed_ip" {
  description = "VPN EC2 EIP - Corp에 전달 필요"
  value       = aws_eip.vpn_fixed.public_ip
}