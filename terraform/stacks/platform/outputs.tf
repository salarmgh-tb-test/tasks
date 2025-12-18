# -----------------------------------------------------------------------------
# Platform Stack Outputs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

# -----------------------------------------------------------------------------
# EKS Outputs
# -----------------------------------------------------------------------------
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate data (base64 encoded)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Node Group Outputs
# -----------------------------------------------------------------------------
output "node_security_group_id" {
  description = "EKS worker node security group ID"
  value       = module.nodegroups.node_security_group_id
}

output "node_role_arn" {
  description = "EKS worker node IAM role ARN"
  value       = module.nodegroups.node_role_arn
}

# -----------------------------------------------------------------------------
# RDS Outputs
# -----------------------------------------------------------------------------
output "rds_instance_id" {
  description = "RDS instance ID"
  value       = var.enable_rds ? module.rds[0].db_instance_id : null
}

output "rds_instance_identifier" {
  description = "RDS instance identifier"
  value       = var.enable_rds ? module.rds[0].db_instance_identifier : null
}

output "rds_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = var.enable_rds ? module.rds[0].db_instance_endpoint : null
}

output "rds_instance_address" {
  description = "RDS instance address"
  value       = var.enable_rds ? module.rds[0].db_instance_address : null
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = var.enable_rds ? module.rds[0].db_instance_port : null
}

output "rds_database_name" {
  description = "RDS database name"
  value       = var.enable_rds ? module.rds[0].db_instance_name : null
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = var.enable_rds ? module.rds[0].security_group_id : null
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------
output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = module.iam.cluster_autoscaler_role_arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.iam.load_balancer_controller_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = module.iam.external_dns_role_arn
}

output "app_role_arns" {
  description = "Map of application service account role ARNs"
  value       = module.iam.app_role_arns
}

# -----------------------------------------------------------------------------
# CloudWatch Outputs
# -----------------------------------------------------------------------------
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.cloudwatch.dashboard_name
}

output "cloudwatch_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = module.cloudwatch.cloudwatch_alarms_topic_arn
}

output "critical_alarms_topic_arn" {
  description = "SNS topic ARN for critical alarms"
  value       = module.cloudwatch.critical_alarms_topic_arn
}

output "app_log_groups" {
  description = "Application log group names"
  value       = module.cloudwatch.app_log_group_names
}

output "eks_app_log_groups" {
  description = "EKS application log group names"
  value       = module.cloudwatch.eks_app_log_group_names
}

# -----------------------------------------------------------------------------
# GitHub Actions Outputs
# -----------------------------------------------------------------------------
output "github_actions_ecr_user_name" {
  description = "GitHub Actions ECR IAM user name"
  value       = module.github_actions_ecr.user_name
}

output "github_actions_ecr_access_key_id" {
  description = "GitHub Actions ECR access key ID"
  value       = module.github_actions_ecr.access_key_id
}

output "github_actions_ecr_secret_access_key" {
  description = "GitHub Actions ECR secret access key"
  value       = module.github_actions_ecr.secret_access_key
  sensitive   = true
}

output "github_actions_ecr_registry_url" {
  description = "ECR registry URL"
  value       = module.github_actions_ecr.ecr_registry_url
}

output "github_secrets_status" {
  description = "Status of GitHub secrets configuration"
  value = var.github_repository != "" ? (
    "[OK] Configured - Secrets created in ${var.github_repository} environment: ${var.environment}"
  ) : "[ERROR] Not configured - Set github_repository to enable"
}

# -----------------------------------------------------------------------------
# Kubernetes Outputs
# -----------------------------------------------------------------------------
output "k8s_namespace" {
  description = "Kubernetes namespace for application deployments"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "k8s_deployer_role" {
  description = "Kubernetes role for GitHub Actions deployer"
  value       = kubernetes_role.github_actions_deployer.metadata[0].name
}

# -----------------------------------------------------------------------------
# Monitoring Outputs
# -----------------------------------------------------------------------------
output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = module.monitoring.namespace
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = module.monitoring.prometheus_service
}

output "grafana_service" {
  description = "Grafana service name"
  value       = module.monitoring.grafana_service
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = module.monitoring.grafana_admin_password
  sensitive   = true
}

output "grafana_access_instructions" {
  description = "Instructions to access Grafana"
  value = var.enable_prometheus_stack ? (
    "Port-forward to access Grafana: kubectl port-forward -n ${module.monitoring.namespace} svc/${module.monitoring.grafana_service} 3000:80"
  ) : "Monitoring stack not enabled"
}

# -----------------------------------------------------------------------------
# S3 Bucket Names (Auto-generated)
# -----------------------------------------------------------------------------
output "tempo_s3_bucket" {
  description = "S3 bucket name for Tempo traces"
  value       = local.tempo_s3_bucket
}

output "loki_s3_bucket_chunks" {
  description = "S3 bucket name for Loki chunks"
  value       = local.loki_s3_bucket_chunks
}

output "loki_s3_bucket_ruler" {
  description = "S3 bucket name for Loki ruler"
  value       = local.loki_s3_bucket_ruler
}

# -----------------------------------------------------------------------------
# Account Information
# -----------------------------------------------------------------------------
output "aws_account_id" {
  description = "AWS Account ID (for reference)"
  value       = local.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.region
}

