#--------------------------------------------------------------
# GitHub Actions ECR IAM User Module Outputs
#--------------------------------------------------------------

output "user_name" {
  description = "IAM user name"
  value       = aws_iam_user.github_actions_ecr.name
}

output "user_arn" {
  description = "IAM user ARN"
  value       = aws_iam_user.github_actions_ecr.arn
}

output "access_key_id" {
  description = "Access key ID (only if create_access_key is true). Add this to GitHub Secrets as AWS_ACCESS_KEY_ID"
  value       = var.create_access_key ? aws_iam_access_key.github_actions_ecr[0].id : null
  sensitive   = false
}

output "secret_access_key" {
  description = "Secret access key (only if create_access_key is true). Add this to GitHub Secrets as AWS_SECRET_ACCESS_KEY"
  value       = var.create_access_key ? aws_iam_access_key.github_actions_ecr[0].secret : null
  sensitive   = true
}

output "ecr_registry_url" {
  description = "ECR registry URL for the repositories"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repositories" {
  description = "List of ECR repository names"
  value       = var.ecr_repositories
}

