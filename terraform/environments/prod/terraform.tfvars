# -----------------------------------------------------------------------------
# Production Environment Configuration
# -----------------------------------------------------------------------------
# This file contains environment-specific values for the production environment.
# Sensitive values should be provided via environment variables or GitHub secrets.
# -----------------------------------------------------------------------------

# Core Configuration
project     = "tradebytes"
environment = "prod"
region      = "eu-north-1"

# Cost Allocation Tags
cost_center      = "engineering"
application_name = "tradebytes"

tags = {
  Owner       = "devops-team"
  Environment = "production"
  Criticality = "high"
}

# Admin users - just the username, ARNs are constructed dynamically
admin_usernames = ["tradebytes-production"]

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------
vpc_cidr           = "10.2.0.0/16"  # Different CIDR from dev/staging
az_count           = 3               # 3 AZs for HA (required for prod)
enable_nat_gateway = true
single_nat_gateway = false           # One NAT per AZ for production HA

enable_vpc_flow_logs         = true
vpc_flow_logs_retention_days = 30  # Longer retention for prod

# -----------------------------------------------------------------------------
# EKS Configuration
# -----------------------------------------------------------------------------
cluster_version = "1.34"

# SECURITY: Restrict public access to specific CIDRs for production
# Recommended: Use VPN/bastion or private-only access
enable_public_access = true
public_access_cidrs  = []  # TODO: Add your office/VPN CIDR blocks here

node_groups = {
  general = {
    instance_types = ["m7i-flex.large"]
    capacity_type  = "ON_DEMAND"
    ami_type       = "AL2023_x86_64_STANDARD"
    disk_size      = 100
    desired_size   = 4
    min_size       = 3
    max_size       = 20
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
enable_external_dns             = true  # Enabled for prod

# -----------------------------------------------------------------------------
# RDS Configuration - Production Settings
# -----------------------------------------------------------------------------
db_engine                = "postgres"
db_engine_version        = "18.1"
db_instance_class        = "db.t3.micro"  # Consider upgrading for prod workloads
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_name                  = "appdb"
db_username              = "dbadmin"
# db_password is provided via TF_VAR_db_password environment variable or GitHub secret
db_multi_az              = false  # Enable for production HA
db_backup_retention_period = 1    # Increase for production
db_deletion_protection   = true   # REQUIRED: Protection enabled
db_skip_final_snapshot   = false  # REQUIRED: Always create snapshot

db_performance_insights_enabled   = true
db_performance_insights_retention = 7
db_cloudwatch_log_exports         = ["postgresql", "upgrade"]
db_monitoring_interval            = 60
db_max_connections_threshold      = 80

# -----------------------------------------------------------------------------
# CloudWatch Configuration
# -----------------------------------------------------------------------------
cloudwatch_log_retention_days = 30  # Longer retention for prod

enable_cloudwatch_eks_alarms = true
enable_cloudwatch_rds_alarms = true
enable_cloudwatch_alb_alarms = false  # Enable after deploying Ingress resources
enable_cloudwatch_nat_alarms = true   # Enabled for prod

create_cloudwatch_dashboard = true

# -----------------------------------------------------------------------------
# Monitoring Stack Configuration
# -----------------------------------------------------------------------------
enable_prometheus_stack = true

prometheus_retention_days = 14  # Longer retention for prod
prometheus_storage_size   = "20Gi"
prometheus_storage_class  = "gp2"
prometheus_replicas       = 2  # HA for prod

# grafana_admin_password is provided via TF_VAR_grafana_admin_password or GitHub secret
grafana_ingress_enabled = false
grafana_ingress_host    = "grafana-prod.example.com"
grafana_ingress_class   = "alb"
grafana_replicas        = 2  # HA for prod
grafana_storage_size    = "5Gi"

alertmanager_enabled       = true
alertmanager_storage_size  = "2Gi"
node_exporter_enabled      = true
kube_state_metrics_enabled = true

# -----------------------------------------------------------------------------
# Tempo Configuration (S3 bucket names auto-generated with account ID)
# -----------------------------------------------------------------------------
tempo_enabled        = true
tempo_replicas       = 2  # HA for prod
tempo_storage_size   = "20Gi"
tempo_retention_days = 14

# -----------------------------------------------------------------------------
# Loki Configuration (S3 bucket names auto-generated with account ID)
# -----------------------------------------------------------------------------
loki_enabled        = true
loki_replicas       = 2  # HA for prod
loki_storage_size   = "20Gi"
loki_retention_days = 14

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
# GitHub tokens are provided via environment variables
