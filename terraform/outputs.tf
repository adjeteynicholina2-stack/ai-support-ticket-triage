output "api_url" {
  description = "Send POST requests with a JSON body {\"message\": \"...\"} to this address."
  value       = "${aws_apigatewayv2_api.tickets.api_endpoint}/tickets"
}

output "tickets_table" {
  value = aws_dynamodb_table.tickets.name
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
