# Keeps Terraform's memory (the state) in S3 instead of on your Mac,
# so your laptop and GitHub Actions both see the same record of what exists.
terraform {
  backend "s3" {
    bucket       = "tf-state-937492565038"
    key          = "ticket-triage/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # stops two runs changing the state at the same time (needs Terraform 1.10+)
  }
}
