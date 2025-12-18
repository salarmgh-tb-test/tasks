# -----------------------------------------------------------------------------
# Dev Environment Configuration
# -----------------------------------------------------------------------------
# This file configures the dev environment using the shared platform stack.
# Environment-specific values are provided via terraform.tfvars
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment  = var.environment
      Project      = var.project
      ManagedBy    = "terraform"
      CostCenter   = var.cost_center
      Application  = var.application_name != "" ? var.application_name : var.project
    }
  }
}

provider "kubernetes" {
  host                   = module.platform.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.platform.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.platform.eks_cluster_name,
      "--region",
      var.region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.platform.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.platform.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.platform.eks_cluster_name,
        "--region",
        var.region
      ]
    }
  }
}

# GitHub provider - uses backend token which should have access to both repos in the same org
provider "github" {
  owner = var.github_owner != "" ? var.github_owner : null
  token = var.github_backend_token != "" ? var.github_backend_token : null
}

# Frontend provider alias (uses same token if frontend token not provided)
provider "github" {
  alias = "frontend"
  owner = var.github_owner != "" ? var.github_owner : null
  token = var.github_frontend_token != "" ? var.github_frontend_token : var.github_backend_token != "" ? var.github_backend_token : null
}

# -----------------------------------------------------------------------------
# Platform Stack Module
# -----------------------------------------------------------------------------
module "platform" {
  source = "../../stacks/platform"

  # Core Configuration
  project          = var.project
  environment      = var.environment
  region           = var.region
  cost_center      = var.cost_center
  application_name = var.application_name
  tags             = var.tags

  # Admin Access
  admin_usernames = var.admin_usernames

  # VPC Configuration
  vpc_cidr                     = var.vpc_cidr
  az_count                     = var.az_count
  enable_nat_gateway           = var.enable_nat_gateway
  single_nat_gateway           = var.single_nat_gateway
  enable_vpc_flow_logs         = var.enable_vpc_flow_logs
  vpc_flow_logs_retention_days = var.vpc_flow_logs_retention_days

  # EKS Configuration
  cluster_version      = var.cluster_version
  coredns_version      = var.coredns_version
  ebs_csi_version      = var.ebs_csi_version
  public_access_cidrs  = var.public_access_cidrs
  enable_public_access = var.enable_public_access
  node_groups          = var.node_groups

  # IAM Configuration
  enable_cluster_autoscaler       = var.enable_cluster_autoscaler
  enable_load_balancer_controller = var.enable_load_balancer_controller
  enable_external_dns             = var.enable_external_dns

  # Ingress Configuration
  ingress_image_repository     = var.ingress_image_repository
  ingress_image_tag            = var.ingress_image_tag
  ingress_class                = var.ingress_class
  ingress_replicas             = var.ingress_replicas
  ingress_create_ingress_class = var.ingress_create_ingress_class
  ingress_set_as_default       = var.ingress_set_as_default

  # RDS Configuration
  enable_rds                        = var.enable_rds
  db_engine                         = var.db_engine
  db_engine_version                 = var.db_engine_version
  db_instance_class                 = var.db_instance_class
  db_allocated_storage              = var.db_allocated_storage
  db_max_allocated_storage          = var.db_max_allocated_storage
  db_name                           = var.db_name
  db_username                       = var.db_username
  db_password                       = var.db_password
  db_multi_az                       = var.db_multi_az
  db_backup_retention_period        = var.db_backup_retention_period
  db_deletion_protection            = var.db_deletion_protection
  db_skip_final_snapshot            = var.db_skip_final_snapshot
  db_performance_insights_enabled   = var.db_performance_insights_enabled
  db_performance_insights_retention = var.db_performance_insights_retention
  db_cloudwatch_log_exports         = var.db_cloudwatch_log_exports
  db_monitoring_interval            = var.db_monitoring_interval
  db_max_connections_threshold      = var.db_max_connections_threshold

  # CloudWatch Configuration
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  cloudwatch_app_log_groups     = var.cloudwatch_app_log_groups
  cloudwatch_eks_log_groups     = var.cloudwatch_eks_log_groups
  cloudwatch_alert_emails       = var.cloudwatch_alert_emails
  enable_cloudwatch_eks_alarms  = var.enable_cloudwatch_eks_alarms
  enable_cloudwatch_rds_alarms  = var.enable_cloudwatch_rds_alarms
  enable_cloudwatch_alb_alarms  = var.enable_cloudwatch_alb_alarms
  enable_cloudwatch_nat_alarms  = var.enable_cloudwatch_nat_alarms
  create_cloudwatch_dashboard   = var.create_cloudwatch_dashboard

  # Monitoring Stack Configuration
  enable_prometheus_stack    = var.enable_prometheus_stack
  prometheus_retention_days  = var.prometheus_retention_days
  prometheus_storage_size    = var.prometheus_storage_size
  prometheus_storage_class   = var.prometheus_storage_class
  prometheus_replicas        = var.prometheus_replicas
  grafana_admin_password     = var.grafana_admin_password
  grafana_ingress_enabled    = var.grafana_ingress_enabled
  grafana_ingress_host       = var.grafana_ingress_host
  grafana_ingress_class      = var.grafana_ingress_class
  grafana_replicas           = var.grafana_replicas
  grafana_storage_size       = var.grafana_storage_size
  alertmanager_enabled       = var.alertmanager_enabled
  alertmanager_storage_size  = var.alertmanager_storage_size
  node_exporter_enabled      = var.node_exporter_enabled
  kube_state_metrics_enabled = var.kube_state_metrics_enabled

  # Tempo Configuration
  tempo_enabled        = var.tempo_enabled
  tempo_replicas       = var.tempo_replicas
  tempo_storage_size   = var.tempo_storage_size
  tempo_retention_days = var.tempo_retention_days

  # Loki Configuration
  loki_enabled        = var.loki_enabled
  loki_replicas       = var.loki_replicas
  loki_storage_size   = var.loki_storage_size
  loki_retention_days = var.loki_retention_days

  # OpenTelemetry Configuration
  otel_operator_enabled = var.otel_operator_enabled

  # GitHub Configuration
  github_owner               = var.github_owner
  github_repository          = var.github_repository
  github_backend_token       = var.github_backend_token
  github_frontend_repository = var.github_frontend_repository
  github_frontend_token      = var.github_frontend_token

  providers = {
    github          = github
    github.frontend = github.frontend
  }
}
