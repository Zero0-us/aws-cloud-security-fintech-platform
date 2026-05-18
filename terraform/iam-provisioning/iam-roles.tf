# ============================================================
# IAM Roles for Lambda & Step Functions
# 경로: terraform/iamprovisioning/iam-roles.tf
# ============================================================

# ------------------------------
# Lambda: Request Parser Role
# ------------------------------

resource "aws_iam_role" "lambda_request_parser" {
  name = "${var.project_name}-lambda-request-parser-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-request-parser-role"
  }
}

resource "aws_iam_role_policy" "lambda_request_parser" {
  name = "${var.project_name}-lambda-request-parser-policy"
  role = aws_iam_role.lambda_request_parser.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:HeadObject"
        ]
        Resource = "${aws_s3_bucket.provisioning_requests.arn}/requests/*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.audit_logs.arn,
          aws_dynamodb_table.pending_requests.arn
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.request_parser.arn}:*"
      }
    ]
  })
}

# ------------------------------
# Lambda: IAM Executor Role
# ------------------------------

resource "aws_iam_role" "lambda_iam_executor" {
  name = "${var.project_name}-lambda-iam-executor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-iam-executor-role"
  }
}

resource "aws_iam_role_policy" "lambda_iam_executor" {
  name = "${var.project_name}-lambda-iam-executor-policy"
  role = aws_iam_role.lambda_iam_executor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeRoleToTargetAccounts"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          for account_id in values(var.target_account_ids) :
          "arn:aws:iam::${account_id}:role/IAMProvisioningExecutorRole"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:CopyObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.provisioning_requests.arn}/*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.audit_logs.arn,
          aws_dynamodb_table.pending_requests.arn
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.iam_executor.arn}:*"
      }
    ]
  })
}

# ------------------------------
# Lambda: Discord Notifier Role
# ------------------------------

resource "aws_iam_role" "lambda_discord_notifier" {
  name = "${var.project_name}-lambda-discord-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-discord-notifier-role"
  }
}

resource "aws_iam_role_policy" "lambda_discord_notifier" {
  name = "${var.project_name}-lambda-discord-notifier-policy"
  role = aws_iam_role.lambda_discord_notifier.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.discord_notifier.arn}:*"
      }
    ]
  })
}

# ------------------------------
# Lambda: Approval Handler Role
# ------------------------------

resource "aws_iam_role" "lambda_approval_handler" {
  name = "${var.project_name}-lambda-approval-handler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-approval-handler-role"
  }
}

resource "aws_iam_role_policy" "lambda_approval_handler" {
  name = "${var.project_name}-lambda-approval-handler-policy"
  role = aws_iam_role.lambda_approval_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StepFunctionsAccess"
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.iam_workflow.arn
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.pending_requests.arn,
          aws_dynamodb_table.audit_logs.arn,
          "${aws_dynamodb_table.audit_logs.arn}/index/*"
        ]
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:CopyObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.provisioning_requests.arn}/*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.approval_handler.arn}:*"
      }
    ]
  })
}

# ------------------------------
# Step Functions Role
# ------------------------------

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-step-functions-role"
  }
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.project_name}-step-functions-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.iam_executor.arn,
          aws_lambda_function.discord_notifier.arn
        ]
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.audit_logs.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# ------------------------------
# Cross-Account Executor Role (조건부 생성)
# 대상 계정(dev, stg, prod)에 배포할 때만 사용
# ------------------------------

resource "aws_iam_role" "cross_account_executor" {
  count = var.deploy_cross_account_role ? 1 : 0
  
  name = "IAMProvisioningExecutorRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.soc_account_id}:role/${var.project_name}-lambda-iam-executor-role"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "IAMProvisioningExecutorRole"
    Purpose     = "Cross-account IAM provisioning"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "cross_account_executor" {
  count = var.deploy_cross_account_role ? 1 : 0
  
  name = "IAMProvisioningExecutorPolicy"
  role = aws_iam_role.cross_account_executor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMUserManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:ListUsers",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:UpdateUser",
          "iam:CreateLoginProfile",
          "iam:DeleteLoginProfile",
          "iam:GetLoginProfile",
          "iam:UpdateLoginProfile",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
          "iam:UpdateAccessKey",
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:DeactivateMFADevice",
          "iam:EnableMFADevice",
          "iam:ListMFADevices",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListAttachedUserPolicies",
          "iam:ListUserPolicies",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:AddUserToGroup",
          "iam:RemoveUserFromGroup",
          "iam:ListGroupsForUser"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicies",
          "iam:GetGroup",
          "iam:ListGroups"
        ]
        Resource = "*"
      }
    ]
  })
}