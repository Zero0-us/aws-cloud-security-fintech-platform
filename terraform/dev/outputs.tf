data "aws_caller_identity" "current" {}

output "vpc_id" {
  description = "Dev VPC ID"
  value       = aws_vpc.dev.id
}

output "vpc_cidr" {
  description = "Dev VPC CIDR"
  value       = aws_vpc.dev.cidr_block
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.dev.name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = aws_eks_cluster.dev.endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.dev.version
}

output "rds_endpoint" {
  description = "RDS endpoint with port"
  value       = aws_db_instance.dev.endpoint
}

output "rds_address" {
  description = "RDS hostname without port"
  value       = aws_db_instance.dev.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.dev.port
}

output "rds_database_name" {
  description = "DB name"
  value       = aws_db_instance.dev.db_name
}

output "rds_engine" {
  description = "DB engine"
  value       = aws_db_instance.dev.engine
}

output "rds_secret_name" {
  description = "Secrets Manager secret name for DB password"
  value       = aws_secretsmanager_secret.db_password.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.dev.dns_name
}

output "alb_target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.dev.arn
}

output "cloudtrail_name" {
  description = "Dev CloudTrail name"
  value       = aws_cloudtrail.dev.name
}

output "cloudtrail_s3_bucket" {
  description = "SOC S3 bucket for dev CloudTrail"
  value       = var.soc_log_bucket_name
}

output "cloudtrail_s3_prefix" {
  description = "SOC S3 prefix for dev CloudTrail"
  value       = var.cloudtrail_s3_key_prefix
}

output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch Logs group"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "vpc_flow_log_group" {
  description = "VPC Flow Logs CloudWatch Logs group"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "waf_log_group" {
  description = "WAF CloudWatch Logs group"
  value       = aws_cloudwatch_log_group.waf.name
}

output "eks_cluster_log_group" {
  description = "EKS control plane CloudWatch Logs group"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "config_recorder_name" {
  description = "AWS Config recorder name"
  value       = aws_config_configuration_recorder.dev.name
}

output "config_delivery_bucket" {
  description = "SOC S3 bucket for AWS Config delivery"
  value       = var.soc_log_bucket_name
}

output "config_delivery_prefix" {
  description = "SOC S3 prefix for AWS Config delivery"
  value       = var.config_s3_key_prefix
}

output "cloudwatch_export_role_arn" {
  description = "CloudWatch Logs export role ARN for SOC automation"
  value       = aws_iam_role.cloudwatch_export.arn
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP"
  value       = aws_eip.nat.public_ip
}

output "vuln_bank_ecr_repository" {
  description = "Dev ECR repository URL for vuln-bank"
  value       = aws_ecr_repository.vuln_bank.repository_url
}

output "peering_info" {
  description = "VPC peering information for the Security/Audit account"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    vpc_id     = aws_vpc.dev.id
    vpc_cidr   = aws_vpc.dev.cidr_block
    region     = var.region
  }
}
