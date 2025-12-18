# -----------------------------------------------------------------------------
# Dev Environment Variables
# -----------------------------------------------------------------------------
# These variables are passed to the shared platform stack module.
# Environment-specific values are set in terraform.tfvars
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------------
variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "tradebytes"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "eu-north-1"
}

# -----------------------------------------------------------------------------
# Cost Allocation Tags
# -----------------------------------------------------------------------------
variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "application_name" {
  description = "Application name for cost tracking"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Admin Access Configuration
# -----------------------------------------------------------------------------
variable "admin_usernames" {
  description = "List of IAM usernames to grant admin (system:masters) access to the EKS cluster"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (minimum 2 for EKS)"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost savings, less HA)"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "vpc_flow_logs_retention_days" {
  description = "VPC Flow Logs retention in days"
  type        = number
  default     = 7
}

# -----------------------------------------------------------------------------
# EKS Configuration
# -----------------------------------------------------------------------------
variable "cluster_version" {
  description = "EKS cluster Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "coredns_version" {
  description = "CoreDNS addon version"
  type        = string
  default     = "v1.12.4-eksbuild.1"
}

variable "ebs_csi_version" {
  description = "EBS CSI driver addon version"
  type        = string
  default     = "v1.53.0-eksbuild.1"
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access the EKS API endpoint. Empty for most secure."
  type        = list(string)
  default     = []
}

variable "enable_public_access" {
  description = "Enable public access to EKS API endpoint"
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Map of EKS node group configurations"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    ami_type       = string
    disk_size      = number
    desired_size   = number
    min_size       = number
    max_size       = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    general = {
      instance_types = ["m7i-flex.large"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 50
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      labels         = {}
      taints         = []
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Configuration
# -----------------------------------------------------------------------------
variable "enable_cluster_autoscaler" {
  description = "Create IAM role for Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_load_balancer_controller" {
  description = "Create IAM role for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Create IAM role for External DNS"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Ingress Controller Configuration
# -----------------------------------------------------------------------------
variable "ingress_image_repository" {
  description = "Container image repository for AWS Load Balancer Controller"
  type        = string
  default     = "public.ecr.aws/eks/aws-load-balancer-controller"
}

variable "ingress_image_tag" {
  description = "Container image tag for AWS Load Balancer Controller"
  type        = string
  default     = "v2.16.0"
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "alb"
}

variable "ingress_replicas" {
  description = "Number of ingress controller replicas"
  type        = number
  default     = 2
}

variable "ingress_create_ingress_class" {
  description = "Whether to create the IngressClass resource"
  type        = bool
  default     = true
}

variable "ingress_set_as_default" {
  description = "Whether to set the ingress class as the default"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# RDS Configuration
# -----------------------------------------------------------------------------
variable "enable_rds" {
  description = "Enable RDS database creation"
  type        = bool
  default     = true
}

variable "db_engine" {
  description = "Database engine (postgres or mysql)"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  sensitive   = true
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for the database. Set via TF_VAR_db_password env var or GitHub secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights for RDS"
  type        = bool
  default     = true
}

variable "db_performance_insights_retention" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

variable "db_cloudwatch_log_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "db_monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds"
  type        = number
  default     = 60
}

variable "db_max_connections_threshold" {
  description = "Threshold for RDS max connections alarm"
  type        = number
  default     = 80
}

# -----------------------------------------------------------------------------
# CloudWatch Configuration
# -----------------------------------------------------------------------------
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "cloudwatch_app_log_groups" {
  description = "Application log groups to create"
  type        = map(string)
  default = {
    frontend = "Frontend application logs"
    backend  = "Backend application logs"
  }
}

variable "cloudwatch_eks_log_groups" {
  description = "EKS application log groups to create"
  type        = map(string)
  default = {
    frontend      = "Frontend pods"
    backend       = "Backend pods"
    postgres      = "PostgreSQL pods"
    nginx         = "Nginx ingress controller"
    autoscaler    = "Cluster autoscaler"
    lb-controller = "Load balancer controller"
  }
}

variable "cloudwatch_alert_emails" {
  description = "Email addresses for CloudWatch alarms"
  type        = map(string)
  default     = {}
}

variable "enable_cloudwatch_eks_alarms" {
  description = "Enable CloudWatch alarms for EKS"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_rds_alarms" {
  description = "Enable CloudWatch alarms for RDS"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alb_alarms" {
  description = "Enable CloudWatch alarms for ALB"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_nat_alarms" {
  description = "Enable CloudWatch alarms for NAT Gateways"
  type        = bool
  default     = false
}

variable "create_cloudwatch_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Monitoring Stack Configuration
# -----------------------------------------------------------------------------
variable "enable_prometheus_stack" {
  description = "Enable kube-prometheus-stack deployment"
  type        = bool
  default     = true
}

variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 7
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "10Gi"
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus PVCs"
  type        = string
  default     = "gp2"
}

variable "prometheus_replicas" {
  description = "Number of Prometheus replicas"
  type        = number
  default     = 1
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Set via TF_VAR_grafana_admin_password env var or GitHub secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_ingress_enabled" {
  description = "Enable Grafana ingress"
  type        = bool
  default     = false
}

variable "grafana_ingress_host" {
  description = "Grafana ingress hostname"
  type        = string
  default     = "grafana.example.com"
}

variable "grafana_ingress_class" {
  description = "Grafana ingress class"
  type        = string
  default     = "alb"
}

variable "grafana_replicas" {
  description = "Number of Grafana replicas"
  type        = number
  default     = 1
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "2Gi"
}

variable "alertmanager_enabled" {
  description = "Enable Alertmanager"
  type        = bool
  default     = true
}

variable "alertmanager_storage_size" {
  description = "Alertmanager storage size"
  type        = string
  default     = "1Gi"
}

variable "node_exporter_enabled" {
  description = "Enable node-exporter for node metrics"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Enable kube-state-metrics"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tempo Configuration
# -----------------------------------------------------------------------------
variable "tempo_enabled" {
  description = "Enable Tempo for distributed tracing"
  type        = bool
  default     = true
}

variable "tempo_replicas" {
  description = "Number of Tempo replicas"
  type        = number
  default     = 1
}

variable "tempo_storage_size" {
  description = "Tempo storage size"
  type        = string
  default     = "10Gi"
}

variable "tempo_retention_days" {
  description = "Tempo trace retention in days"
  type        = number
  default     = 7
}

# -----------------------------------------------------------------------------
# Loki Configuration
# -----------------------------------------------------------------------------
variable "loki_enabled" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = true
}

variable "loki_replicas" {
  description = "Number of Loki replicas"
  type        = number
  default     = 1
}

variable "loki_storage_size" {
  description = "Loki storage size"
  type        = string
  default     = "10Gi"
}

variable "loki_retention_days" {
  description = "Loki log retention in days"
  type        = number
  default     = 7
}

# -----------------------------------------------------------------------------
# OpenTelemetry Configuration
# -----------------------------------------------------------------------------
variable "otel_operator_enabled" {
  description = "Enable OpenTelemetry Operator"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository name for backend"
  type        = string
  default     = ""
}

variable "github_backend_token" {
  description = "GitHub token for backend repository. Set via TF_VAR_github_backend_token env var."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_frontend_repository" {
  description = "GitHub repository name for frontend"
  type        = string
  default     = ""
}

variable "github_frontend_token" {
  description = "GitHub token for frontend repository. Set via TF_VAR_github_frontend_token env var."
  type        = string
  default     = ""
  sensitive   = true
}
