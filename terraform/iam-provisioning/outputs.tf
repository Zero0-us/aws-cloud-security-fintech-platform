# ============================================================
# Outputs
# 경로: terraform/iamprovisioning/outputs.tf
# ============================================================

# S3
output "s3_bucket_name" {
  description = "S3 bucket name for provisioning requests"
  value       = aws_s3_bucket.provisioning_requests.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.provisioning_requests.arn
}

# API Gateway
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "approve_endpoint" {
  description = "Approval endpoint URL"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/approve"
}

output "deny_endpoint" {
  description = "Deny endpoint URL"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/deny"
}

# Lambda
output "lambda_arns" {
  description = "Lambda function ARNs"
  value = {
    request_parser   = aws_lambda_function.request_parser.arn
    iam_executor     = aws_lambda_function.iam_executor.arn
    discord_notifier = aws_lambda_function.discord_notifier.arn
    approval_handler = aws_lambda_function.approval_handler.arn
  }
}

# Step Functions
output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.iam_workflow.arn
}

# DynamoDB
output "dynamodb_table_name" {
  description = "DynamoDB audit log table name"
  value       = aws_dynamodb_table.audit_logs.name
}

output "dynamodb_pending_table_name" {
  description = "DynamoDB pending requests table name"
  value       = aws_dynamodb_table.pending_requests.name
}

# Cross-Account Role (조건부 출력)
output "cross_account_role_arn" {
  description = "Cross-account executor role ARN (only when deployed)"
  value       = var.deploy_cross_account_role ? aws_iam_role.cross_account_executor[0].arn : null
}