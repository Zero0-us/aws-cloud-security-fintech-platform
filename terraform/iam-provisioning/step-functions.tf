# ============================================================
# Step Functions - IAM Workflow
# 경로: terraform/iamprovisioning/step-functions.tf
# ============================================================

resource "aws_sfn_state_machine" "iam_workflow" {
  name     = "${var.project_name}-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "IAM Provisioning Workflow - Gold Version"
    StartAt = "RouteByRequestType"

    States = {
      # 요청 타입별 분기
      RouteByRequestType = {
        Type = "Choice"
        Comment = "요청 타입별 분기"
        Choices = [
          {
            Variable     = "$.request_type"
            StringEquals = "onboard"
            Next         = "ExecuteOnboard"
          },
          {
            Variable     = "$.request_type"
            StringEquals = "offboard"
            Next         = "ExecuteOffboard"
          },
          {
            Variable     = "$.request_type"
            StringEquals = "modify"
            Next         = "ExecuteModify"
          }
        ]
        Default = "InvalidRequestType"
      }

      # 입사 처리
      ExecuteOnboard = {
        Type     = "Task"
        Comment  = "입사자 IAM 생성"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.iam_executor.arn
          Payload = {
            "action"    = "onboard"
            "request.$" = "$"
          }
        }
        ResultPath = "$.execution_result"
        ResultSelector = {
          "statusCode.$" = "$.Payload.statusCode"
          "result.$"     = "$.Payload.result"
        }
        Retry = [
          {
            ErrorEquals    = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "LogFailure"
          }
        ]
        Next = "LogSuccess"
      }

      # 퇴사 처리
      ExecuteOffboard = {
        Type     = "Task"
        Comment  = "퇴사자 IAM 비활성화"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.iam_executor.arn
          Payload = {
            "action"    = "offboard"
            "request.$" = "$"
          }
        }
        ResultPath = "$.execution_result"
        ResultSelector = {
          "statusCode.$" = "$.Payload.statusCode"
          "result.$"     = "$.Payload.result"
        }
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "LogFailure"
          }
        ]
        Next = "LogSuccess"
      }

      # 권한 변경 처리
      ExecuteModify = {
        Type     = "Task"
        Comment  = "권한 변경"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.iam_executor.arn
          Payload = {
            "action"    = "modify"
            "request.$" = "$"
          }
        }
        ResultPath = "$.execution_result"
        ResultSelector = {
          "statusCode.$" = "$.Payload.statusCode"
          "result.$"     = "$.Payload.result"
        }
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "LogFailure"
          }
        ]
        Next = "LogSuccess"
      }

      # 성공 로그 기록
      LogSuccess = {
        Type     = "Task"
        Comment  = "성공 감사 로그 기록"
        Resource = "arn:aws:states:::dynamodb:putItem"
        Parameters = {
          TableName = aws_dynamodb_table.audit_logs.name
          Item = {
            "request_id"       = { "S.$" = "$.request_id" }
            "timestamp"        = { "S.$" = "$$.State.EnteredTime" }
            "request_type"     = { "S.$" = "$.request_type" }
            "username"         = { "S.$" = "$.user.username" }
            "email"            = { "S.$" = "$.user.email" }
            "status"           = { "S" = "COMPLETED" }
            "approver"         = { "S.$" = "$.approver" }
            "executed_at"      = { "S.$" = "$$.State.EnteredTime" }
          }
        }
        ResultPath = "$.dynamodb_result"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.log_error"
            Next        = "NotifySuccess"
          }
        ]
        Next = "NotifySuccess"
      }

      # 실패 로그 기록
      LogFailure = {
        Type     = "Task"
        Comment  = "실패 감사 로그 기록"
        Resource = "arn:aws:states:::dynamodb:putItem"
        Parameters = {
          TableName = aws_dynamodb_table.audit_logs.name
          Item = {
            "request_id"    = { "S.$" = "$.request_id" }
            "timestamp"     = { "S.$" = "$$.State.EnteredTime" }
            "request_type"  = { "S.$" = "$.request_type" }
            "username"      = { "S.$" = "$.user.username" }
            "email"         = { "S.$" = "$.user.email" }
            "status"        = { "S" = "FAILED" }
            "approver"      = { "S.$" = "$.approver" }
            "error_message" = { "S.$" = "States.JsonToString($.error)" }
          }
        }
        ResultPath = "$.dynamodb_result"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.log_error"
            Next        = "NotifyFailure"
          }
        ]
        Next = "NotifyFailure"
      }

      # 성공 알림
      NotifySuccess = {
        Type     = "Task"
        Comment  = "성공 알림 발송"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.discord_notifier.arn
          Payload = {
            "status"    = "success"
            "request.$" = "$"
          }
        }
        ResultPath = "$.notification_result"
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 1
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        End = true
      }

      # 실패 알림
      NotifyFailure = {
        Type     = "Task"
        Comment  = "실패 알림 발송"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.discord_notifier.arn
          Payload = {
            "status"    = "failure"
            "request.$" = "$"
            "error.$"   = "$.error"
          }
        }
        ResultPath = "$.notification_result"
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 1
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        End = true
      }

      # 잘못된 요청 타입
      InvalidRequestType = {
        Type  = "Fail"
        Error = "InvalidRequestType"
        Cause = "request_type must be 'onboard', 'offboard', or 'modify'"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Name = "${var.project_name}-workflow"
  }
}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${var.project_name}-workflow"
  retention_in_days = 30
}