# -----------------------------------------------------------------------------
# Dev Environment Configuration
# -----------------------------------------------------------------------------
# This file contains environment-specific values for the dev environment.
# Sensitive values should be provided via environment variables or GitHub secrets.
# -----------------------------------------------------------------------------

# Core Configuration
project     = "tradebytes"
environment = "dev"
region      = "eu-north-1"

# Cost Allocation Tags
cost_center      = "engineering"
application_name = "tradebytes"

tags = {
  Owner = "devops-team"
}

# Admin users - just the username, ARNs are constructed dynamically
admin_usernames = ["tradebytes"]

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------
vpc_cidr           = "10.0.0.0/16"
az_count           = 2
enable_nat_gateway = true
single_nat_gateway = true

enable_vpc_flow_logs         = true
vpc_flow_logs_retention_days = 7

# -----------------------------------------------------------------------------
# EKS Configuration
# -----------------------------------------------------------------------------
cluster_version = "1.34"

# Restrict public access to specific CIDRs for security
# Leave empty or set enable_public_access = false for private-only access
# Example: public_access_cidrs = ["1.2.3.4/32", "5.6.7.8/32"]
enable_public_access = true
public_access_cidrs  = []  # Empty means 0.0.0.0/0 when enable_public_access is true

node_groups = {
  general = {
    instance_types = ["m7i-flex.large"]
    capacity_type  = "ON_DEMAND"
    ami_type       = "AL2023_x86_64_STANDARD"
    disk_size      = 20
    desired_size   = 3
    min_size       = 2
    max_size       = 5
    labels = {
      role = "general"
    }
    taints = []
  }
}

# -----------------------------------------------------------------------------
# IAM Configuration
# -----------------------------------------------------------------------------
enable_cluster_autoscaler       = true
enable_load_balancer_controller = true
enable_external_dns             = false

# -----------------------------------------------------------------------------
# RDS Configuration
# -----------------------------------------------------------------------------
enable_rds = false  # Disabled for dev - use local database or external service

# -----------------------------------------------------------------------------
# CloudWatch Configuration
# -----------------------------------------------------------------------------
cloudwatch_log_retention_days = 7

enable_cloudwatch_eks_alarms = true
enable_cloudwatch_rds_alarms = false  # No RDS in dev
enable_cloudwatch_alb_alarms = true
enable_cloudwatch_nat_alarms = false  # Disabled for dev cost savings

create_cloudwatch_dashboard = true

# -----------------------------------------------------------------------------
# Monitoring Stack Configuration
# -----------------------------------------------------------------------------
enable_prometheus_stack = true

prometheus_retention_days = 7
prometheus_storage_size   = "10Gi"
prometheus_storage_class  = "gp2"
prometheus_replicas       = 1

# grafana_admin_password is provided via TF_VAR_grafana_admin_password or GitHub secret
grafana_ingress_enabled = false
grafana_ingress_host    = "grafana-dev.example.com"
grafana_ingress_class   = "alb"
grafana_replicas        = 1
grafana_storage_size    = "2Gi"

alertmanager_enabled       = true
alertmanager_storage_size  = "1Gi"
node_exporter_enabled      = true
kube_state_metrics_enabled = true

# -----------------------------------------------------------------------------
# Tempo Configuration (S3 bucket names auto-generated with account ID)
# -----------------------------------------------------------------------------
tempo_enabled        = true
tempo_replicas       = 1
tempo_storage_size   = "10Gi"
tempo_retention_days = 7

# -----------------------------------------------------------------------------
# Loki Configuration (S3 bucket names auto-generated with account ID)
# -----------------------------------------------------------------------------
loki_enabled        = true
loki_replicas       = 1
loki_storage_size   = "10Gi"
loki_retention_days = 7

# -----------------------------------------------------------------------------
# OpenTelemetry Configuration
# -----------------------------------------------------------------------------
otel_operator_enabled = true

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
github_owner               = "salarmgh-tb-test"
github_repository          = "backend"
github_frontend_repository = "frontend"
# GitHub tokens are provided via:
# - TF_VAR_github_backend_token (or BACKEND_GITHUB_TOKEN mapped to it)
# - TF_VAR_github_frontend_token (or FRONTEND_GITHUB_TOKEN mapped to it)
