# ============================================================
# EventBridge - S3 Event Detection
# ============================================================

# S3 객체 생성 이벤트 규칙
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.project_name}-s3-trigger"
  description = "Trigger on S3 object creation in requests folder"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.provisioning_requests.id]
      }
      object = {
        key = [{
          prefix = "requests/"
        }]
      }
    }
  })

  tags = {
    Name = "${var.project_name}-s3-trigger"
  }
}

# Lambda 타겟 연결
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "request-parser-lambda"
  arn       = aws_lambda_function.request_parser.arn
}

# Lambda 호출 권한
resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.request_parser.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}