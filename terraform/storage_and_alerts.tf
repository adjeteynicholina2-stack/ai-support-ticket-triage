# Where every triaged ticket is saved.
resource "aws_dynamodb_table" "tickets" {
  name         = "${var.name_prefix}-tickets"
  billing_mode = "PAY_PER_REQUEST" # no capacity to manage, you pay per request
  hash_key     = "ticket_id"

  attribute {
    name = "ticket_id"
    type = "S"
  }
}

# The channel that carries alerts and the daily summary to your inbox.
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
}

# AWS emails a confirmation link after apply. Click it once, or no mail is delivered.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
