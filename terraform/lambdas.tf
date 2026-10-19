# ---------- Packaging ----------
# Terraform zips each Python file for you. Keep the code in ../src/.

data "archive_file" "triage" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda_function.py"
  output_path = "${path.module}/build/triage.zip"
}

data "archive_file" "summary" {
  type        = "zip"
  source_file = "${path.module}/../src/summary_function.py"
  output_path = "${path.module}/build/summary.zip"
}

# ---------- Shared trust policy ----------
# Says "the Lambda service is allowed to use this role". Both roles use it.

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------- Triage function ----------

resource "aws_iam_role" "triage" {
  name               = "${var.name_prefix}-triage-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Lets the function write its own logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "triage_logs" {
  role       = aws_iam_role.triage.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least privilege: save to one table, publish to one topic, nothing else.
data "aws_iam_policy_document" "triage_access" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tickets.arn]
  }
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_iam_role_policy" "triage_access" {
  name   = "triage-access"
  role   = aws_iam_role.triage.id
  policy = data.aws_iam_policy_document.triage_access.json
}

resource "aws_lambda_function" "triage" {
  function_name    = "${var.name_prefix}-triage"
  role             = aws_iam_role.triage.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.triage.output_path
  source_code_hash = data.archive_file.triage.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      TABLE_NAME        = aws_dynamodb_table.tickets.name
      TOPIC_ARN         = aws_sns_topic.alerts.arn
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      JIRA_BASE_URL     = var.jira_base_url
      JIRA_EMAIL        = var.jira_email
      JIRA_API_TOKEN    = var.jira_api_token
      JIRA_PROJECT_KEY  = var.jira_project_key
    }
  }
}

# ---------- Daily summary function ----------

resource "aws_iam_role" "summary" {
  name               = "${var.name_prefix}-summary-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "summary_logs" {
  role       = aws_iam_role.summary.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "summary_access" {
  statement {
    actions   = ["dynamodb:Scan"]
    resources = [aws_dynamodb_table.tickets.arn]
  }
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_iam_role_policy" "summary_access" {
  name   = "summary-access"
  role   = aws_iam_role.summary.id
  policy = data.aws_iam_policy_document.summary_access.json
}

resource "aws_lambda_function" "summary" {
  function_name    = "${var.name_prefix}-daily-summary"
  role             = aws_iam_role.summary.arn
  runtime          = "python3.12"
  handler          = "summary_function.lambda_handler"
  filename         = data.archive_file.summary.output_path
  source_code_hash = data.archive_file.summary.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tickets.name
      TOPIC_ARN  = aws_sns_topic.alerts.arn
    }
  }
}
