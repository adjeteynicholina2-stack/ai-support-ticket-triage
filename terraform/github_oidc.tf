# Lets GitHub Actions sign in to AWS without any stored access keys.
# GitHub proves who it is with a short-lived token, and AWS checks it against this trust rule.

variable "github_repo" {
  description = "GitHub repository allowed to deploy, in the form owner/name."
  type        = string
  default     = "adjeteynicholina2-stack/ai-support-ticket-triage"
}

data "aws_caller_identity" "current" {}

# The account already has this provider, so we look it up instead of creating a second one.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only runs on the main branch of this one repository may use the role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

# The name deliberately does not start with the project prefix.
# That way the deploy role cannot edit its own permissions.
resource "aws_iam_role" "github_deploy" {
  name               = "github-deploy-ticket-triage"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  prefix_arn = var.name_prefix
}

data "aws_iam_policy_document" "github_deploy" {
  # Read access to IAM, so Terraform can check the roles it manages.
  statement {
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  # Write access only to roles that start with the project prefix.
  statement {
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.prefix_arn}-*"]
  }

  statement {
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:${var.region}:${local.account_id}:function:${local.prefix_arn}-*"]
  }

  statement {
    actions   = ["sns:*"]
    resources = ["arn:aws:sns:${var.region}:${local.account_id}:${local.prefix_arn}-*"]
  }

  statement {
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:${var.region}:${local.account_id}:table/${local.prefix_arn}-*"]
  }

  statement {
    actions   = ["events:*"]
    resources = ["arn:aws:events:${var.region}:${local.account_id}:rule/${local.prefix_arn}-*"]
  }

  # API Gateway cannot be limited by name, so this covers the region's HTTP APIs.
  statement {
    actions   = ["apigateway:*"]
    resources = ["arn:aws:apigateway:${var.region}::/*"]
  }

  # Read and write the Terraform state file, and nothing else in S3.
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::tf-state-${local.account_id}"]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::tf-state-${local.account_id}/*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy-ticket-triage"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

output "github_deploy_role_arn" {
  description = "Save this as the AWS_DEPLOY_ROLE_ARN secret in GitHub."
  value       = aws_iam_role.github_deploy.arn
}
