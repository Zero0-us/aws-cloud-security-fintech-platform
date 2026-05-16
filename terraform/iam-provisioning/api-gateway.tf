# ============================================================
# API Gateway - Approval/Deny Endpoints
# 경로: terraform/iamprovisioning/api-gateway.tf
# ============================================================

# HTTP API 생성
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "IAM Provisioning Approval API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }

  tags = {
    Name = "${var.project_name}-api-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-api"
  retention_in_days = 30
}

# ------------------------------
# Lambda Integration
# ------------------------------

resource "aws_apigatewayv2_integration" "approval_handler" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.approval_handler.invoke_arn
  payload_format_version = "2.0"
}

# ------------------------------
# Routes
# ------------------------------

resource "aws_apigatewayv2_route" "approve" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /approve"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_route" "deny" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /deny"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_route" "status" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /status/{request_id}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

# GET 방식도 추가 (Discord 버튼이 Link 버튼이면 GET 요청)
resource "aws_apigatewayv2_route" "approve_get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /approve"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_route" "deny_get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /deny"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

# Lambda 호출 권한
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.approval_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}