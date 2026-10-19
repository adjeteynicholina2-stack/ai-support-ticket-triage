variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name. Different from the console-built copies so the two can exist side by side."
  type        = string
  default     = "tf-ticket"
}

variable "alert_email" {
  description = "Email address that receives high and critical ticket alerts and the daily summary."
  type        = string
}
