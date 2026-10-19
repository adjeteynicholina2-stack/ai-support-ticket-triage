# ---------- Daily summary schedule ----------
# EventBridge rules use UTC. Ghana is on UTC all year, so 08:00 UTC is 08:00 in Ghana.

resource "aws_cloudwatch_event_rule" "daily_summary" {
  name                = "${var.name_prefix}-daily-summary-0800"
  description         = "Runs the daily ticket summary at 08:00 UTC"
  schedule_expression = "cron(0 8 * * ? *)"
}

resource "aws_cloudwatch_event_target" "daily_summary" {
  rule = aws_cloudwatch_event_rule.daily_summary.name
  arn  = aws_lambda_function.summary.arn
}

# A role lets the function act. This permission lets EventBridge start the function.
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summary.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_summary.arn
}

# ---------- Public API: POST /tickets ----------

resource "aws_apigatewayv2_api" "tickets" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "triage" {
  api_id                 = aws_apigatewayv2_api.tickets.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.triage.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_tickets" {
  api_id    = aws_apigatewayv2_api.tickets.id
  route_key = "POST /tickets"
  target    = "integrations/${aws_apigatewayv2_integration.triage.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.tickets.id
  name        = "$default"
  auto_deploy = true

  # Throttling caps how fast anyone can call the API. This protects you from a
  # runaway script or a stranger flooding Slack and Jira.
  default_route_settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }
}

# Lets API Gateway start the triage function.
resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.triage.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.tickets.execution_arn}/*/*"
}
