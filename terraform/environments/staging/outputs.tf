# -----------------------------------------------------------------------------
# Staging Environment Outputs
# -----------------------------------------------------------------------------
# All outputs are forwarded from the platform stack module.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.platform.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.platform.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.platform.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.platform.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = module.platform.database_subnet_ids
}

# -----------------------------------------------------------------------------
# EKS Outputs
# -----------------------------------------------------------------------------
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.platform.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.platform.eks_cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.platform.eks_cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS worker node security group ID"
  value       = module.platform.node_security_group_id
}

# -----------------------------------------------------------------------------
# RDS Outputs
# -----------------------------------------------------------------------------
output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.platform.rds_instance_id
}

output "rds_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = module.platform.rds_instance_endpoint
}

output "rds_instance_address" {
  description = "RDS instance address"
  value       = module.platform.rds_instance_address
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = module.platform.rds_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.platform.rds_database_name
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.platform.rds_security_group_id
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------
output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = module.platform.cluster_autoscaler_role_arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.platform.load_balancer_controller_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = module.platform.external_dns_role_arn
}

output "app_role_arns" {
  description = "Map of application service account role ARNs"
  value       = module.platform.app_role_arns
}

# -----------------------------------------------------------------------------
# CloudWatch Outputs
# -----------------------------------------------------------------------------
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.platform.cloudwatch_dashboard_name
}

output "cloudwatch_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = module.platform.cloudwatch_alarms_topic_arn
}

output "critical_alarms_topic_arn" {
  description = "SNS topic ARN for critical alarms"
  value       = module.platform.critical_alarms_topic_arn
}

output "app_log_groups" {
  description = "Application log group names"
  value       = module.platform.app_log_groups
}

output "eks_app_log_groups" {
  description = "EKS application log group names"
  value       = module.platform.eks_app_log_groups
}

# -----------------------------------------------------------------------------
# GitHub Actions Outputs
# -----------------------------------------------------------------------------
output "github_actions_ecr_user_name" {
  description = "GitHub Actions ECR IAM user name"
  value       = module.platform.github_actions_ecr_user_name
}

output "github_actions_ecr_access_key_id" {
  description = "GitHub Actions ECR access key ID"
  value       = module.platform.github_actions_ecr_access_key_id
}

output "github_actions_ecr_secret_access_key" {
  description = "GitHub Actions ECR secret access key"
  value       = module.platform.github_actions_ecr_secret_access_key
  sensitive   = true
}

output "github_actions_ecr_registry_url" {
  description = "ECR registry URL"
  value       = module.platform.github_actions_ecr_registry_url
}

output "github_secrets_status" {
  description = "Status of GitHub secrets configuration"
  value       = module.platform.github_secrets_status
}

# -----------------------------------------------------------------------------
# Kubernetes Outputs
# -----------------------------------------------------------------------------
output "k8s_namespace" {
  description = "Kubernetes namespace for application deployments"
  value       = module.platform.k8s_namespace
}

output "k8s_deployer_role" {
  description = "Kubernetes role for GitHub Actions deployer"
  value       = module.platform.k8s_deployer_role
}

# -----------------------------------------------------------------------------
# Monitoring Outputs
# -----------------------------------------------------------------------------
output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = module.platform.monitoring_namespace
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = module.platform.prometheus_service
}

output "grafana_service" {
  description = "Grafana service name"
  value       = module.platform.grafana_service
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = module.platform.grafana_admin_password
  sensitive   = true
}

output "grafana_access_instructions" {
  description = "Instructions to access Grafana"
  value       = module.platform.grafana_access_instructions
}

# -----------------------------------------------------------------------------
# S3 Bucket Names (Auto-generated)
# -----------------------------------------------------------------------------
output "tempo_s3_bucket" {
  description = "S3 bucket name for Tempo traces"
  value       = module.platform.tempo_s3_bucket
}

output "loki_s3_bucket_chunks" {
  description = "S3 bucket name for Loki chunks"
  value       = module.platform.loki_s3_bucket_chunks
}

output "loki_s3_bucket_ruler" {
  description = "S3 bucket name for Loki ruler"
  value       = module.platform.loki_s3_bucket_ruler
}

# -----------------------------------------------------------------------------
# Account Information
# -----------------------------------------------------------------------------
output "aws_account_id" {
  description = "AWS Account ID"
  value       = module.platform.aws_account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = module.platform.aws_region
}
