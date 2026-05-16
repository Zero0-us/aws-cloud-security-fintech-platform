# ============================================================
# Lambda Functions
# 경로: terraform/iamprovisioning/lambda.tf
# ============================================================

# ------------------------------
# Lambda 코드 패키징
# ------------------------------

data "archive_file" "request_parser" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/request-parser"
  output_path = "${path.module}/.build/request-parser.zip"
}

data "archive_file" "iam_executor" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/iam-executor"
  output_path = "${path.module}/.build/iam-executor.zip"
}

data "archive_file" "discord_notifier" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/discord-notifier"
  output_path = "${path.module}/.build/discord-notifier.zip"
}

data "archive_file" "approval_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/approval-handler"
  output_path = "${path.module}/.build/approval-handler.zip"
}

# ------------------------------
# 1. Request Parser Lambda
# ------------------------------

resource "aws_lambda_function" "request_parser" {
  function_name = "${var.project_name}-request-parser"
  description   = "Parse S3 YAML requests and send Discord approval notification"

  filename         = data.archive_file.request_parser.output_path
  source_code_hash = data.archive_file.request_parser.output_base64sha256
  handler          = "index.handler"
  runtime          = var.lambda_runtime

  timeout     = var.lambda_timeout["request_parser"]
  memory_size = var.lambda_memory["request_parser"]

  role = aws_iam_role.lambda_request_parser.arn

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
      API_GATEWAY_URL     = aws_apigatewayv2_stage.main.invoke_url
      DYNAMODB_TABLE      = aws_dynamodb_table.audit_logs.name
      PENDING_TABLE       = aws_dynamodb_table.pending_requests.name
      S3_BUCKET           = aws_s3_bucket.provisioning_requests.id
      ALLOWED_ROLES       = jsonencode(var.allowed_roles)
    }
  }

  tags = {
    Name = "${var.project_name}-request-parser"
  }

  depends_on = [
    aws_cloudwatch_log_group.request_parser,
    aws_iam_role_policy.lambda_request_parser
  ]
}

resource "aws_cloudwatch_log_group" "request_parser" {
  name              = "/aws/lambda/${var.project_name}-request-parser"
  retention_in_days = 30
}

# ------------------------------
# 2. IAM Executor Lambda
# ------------------------------

resource "aws_lambda_function" "iam_executor" {
  function_name = "${var.project_name}-iam-executor"
  description   = "Execute IAM operations (create/disable/modify users)"

  filename         = data.archive_file.iam_executor.output_path
  source_code_hash = data.archive_file.iam_executor.output_base64sha256
  handler          = "index.handler"
  runtime          = var.lambda_runtime

  timeout     = var.lambda_timeout["iam_executor"]
  memory_size = var.lambda_memory["iam_executor"]

  role = aws_iam_role.lambda_iam_executor.arn

  environment {
    variables = {
      TARGET_ACCOUNT_IDS = jsonencode(var.target_account_ids)
      DYNAMODB_TABLE     = aws_dynamodb_table.audit_logs.name
      S3_BUCKET          = aws_s3_bucket.provisioning_requests.id
    }
  }

  tags = {
    Name = "${var.project_name}-iam-executor"
  }

  depends_on = [
    aws_cloudwatch_log_group.iam_executor,
    aws_iam_role_policy.lambda_iam_executor
  ]
}

resource "aws_cloudwatch_log_group" "iam_executor" {
  name              = "/aws/lambda/${var.project_name}-iam-executor"
  retention_in_days = 30
}

# ------------------------------
# 3. Discord Notifier Lambda
# ------------------------------

resource "aws_lambda_function" "discord_notifier" {
  function_name = "${var.project_name}-discord-notifier"
  description   = "Send completion/failure notifications to Discord"

  filename         = data.archive_file.discord_notifier.output_path
  source_code_hash = data.archive_file.discord_notifier.output_base64sha256
  handler          = "index.handler"
  runtime          = var.lambda_runtime

  timeout     = var.lambda_timeout["discord_notifier"]
  memory_size = var.lambda_memory["discord_notifier"]

  role = aws_iam_role.lambda_discord_notifier.arn

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }

  tags = {
    Name = "${var.project_name}-discord-notifier"
  }

  depends_on = [
    aws_cloudwatch_log_group.discord_notifier,
    aws_iam_role_policy.lambda_discord_notifier
  ]
}

resource "aws_cloudwatch_log_group" "discord_notifier" {
  name              = "/aws/lambda/${var.project_name}-discord-notifier"
  retention_in_days = 30
}

# ------------------------------
# 4. Approval Handler Lambda
# ------------------------------

resource "aws_lambda_function" "approval_handler" {
  function_name = "${var.project_name}-approval-handler"
  description   = "Handle approval/deny requests from Discord buttons"

  filename         = data.archive_file.approval_handler.output_path
  source_code_hash = data.archive_file.approval_handler.output_base64sha256
  handler          = "index.handler"
  runtime          = var.lambda_runtime

  timeout     = 30
  memory_size = 256

  role = aws_iam_role.lambda_approval_handler.arn

  environment {
    variables = {
      DYNAMODB_TABLE      = aws_dynamodb_table.audit_logs.name
      PENDING_TABLE       = aws_dynamodb_table.pending_requests.name
      STATE_MACHINE_ARN   = aws_sfn_state_machine.iam_workflow.arn
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
      S3_BUCKET           = aws_s3_bucket.provisioning_requests.id
    }
  }

  tags = {
    Name = "${var.project_name}-approval-handler"
  }

  depends_on = [
    aws_cloudwatch_log_group.approval_handler,
    aws_iam_role_policy.lambda_approval_handler
  ]
}

resource "aws_cloudwatch_log_group" "approval_handler" {
  name              = "/aws/lambda/${var.project_name}-approval-handler"
  retention_in_days = 30
}