# Secret values. "sensitive" stops Terraform printing them in plan and apply output.
# Real values go in terraform.tfvars (ignored by git), never in a .tf file.

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL. Leave empty to skip Slack."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jira_base_url" {
  description = "Your Jira site address, for example https://yoursite.atlassian.net. Leave empty to skip Jira."
  type        = string
  default     = ""
}

variable "jira_email" {
  description = "Email of the Atlassian account that owns the API token."
  type        = string
  default     = ""
}

variable "jira_api_token" {
  description = "Jira API token. Leave empty to skip Jira."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jira_project_key" {
  description = "Key of the Jira project that receives tickets."
  type        = string
  default     = "KAN"
}
