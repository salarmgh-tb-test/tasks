# -----------------------------------------------------------------------------
# Platform Stack - Shared Infrastructure Module
# -----------------------------------------------------------------------------
# This module deploys the complete platform infrastructure including:
# - VPC with public, private, and database subnets
# - EKS cluster with managed node groups
# - RDS PostgreSQL database
# - IAM roles for IRSA
# - Monitoring stack (Prometheus, Grafana, Tempo, Loki)
# - CloudWatch alarms and dashboards
# - GitHub Actions integration
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Locals - Dynamic Values
# -----------------------------------------------------------------------------
locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  # Construct admin user ARNs dynamically from usernames
  admin_user_arns = [
    for username in var.admin_usernames :
    "arn:aws:iam::${local.account_id}:user/${username}"
  ]

  # Auto-generate S3 bucket names with account ID for uniqueness
  tempo_s3_bucket       = var.tempo_enabled ? "tempo-traces-${var.environment}-${local.account_id}" : ""
  loki_s3_bucket_chunks = var.loki_enabled ? "loki-chunks-${var.environment}-${local.account_id}" : ""
  loki_s3_bucket_ruler  = var.loki_enabled ? "loki-ruler-${var.environment}-${local.account_id}" : ""

  # Generate IRSA service accounts with dynamic bucket ARNs
  monitoring_service_accounts = merge(
    var.tempo_enabled ? {
      tempo = {
        namespace       = "monitoring"
        service_account = "tempo"
        policy_json = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
              ]
              Resource = [
                "arn:aws:s3:::${local.tempo_s3_bucket}",
                "arn:aws:s3:::${local.tempo_s3_bucket}/*"
              ]
            }
          ]
        })
      }
    } : {},
    var.loki_enabled ? {
      loki = {
        namespace       = "monitoring"
        service_account = "loki"
        policy_json = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
              ]
              Resource = [
                "arn:aws:s3:::${local.loki_s3_bucket_chunks}",
                "arn:aws:s3:::${local.loki_s3_bucket_chunks}/*",
                "arn:aws:s3:::${local.loki_s3_bucket_ruler}",
                "arn:aws:s3:::${local.loki_s3_bucket_ruler}/*"
              ]
            }
          ]
        })
      }
    } : {}
  )

  # Passwords must be provided via variables
  # Note: GitHub secrets cannot be read as data sources (security restriction)
  # Passwords should be provided via:
  # - Environment variables: TF_VAR_db_password, TF_VAR_grafana_admin_password
  # - Or manually set in GitHub secrets before running Terraform
  db_password          = var.db_password
  grafana_admin_password = var.grafana_admin_password != "" ? var.grafana_admin_password : "admin"

  # Cost allocation and standard tags
  common_tags = merge(
    {
      Project      = var.project
      Environment  = var.environment
      ManagedBy    = "terraform"
      CostCenter   = var.cost_center
      Application  = var.application_name != "" ? var.application_name : var.project
    },
    var.tags
  )
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  region             = var.region
  cluster_name       = "${local.name}-eks"
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  enable_flow_logs         = var.enable_vpc_flow_logs
  flow_logs_retention_days = var.vpc_flow_logs_retention_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  cluster_name            = "${local.name}-eks"
  cluster_version         = var.cluster_version
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = var.enable_public_access
  public_access_cidrs     = var.enable_public_access && length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : (var.enable_public_access ? ["0.0.0.0/0"] : [])
  enable_ebs_csi_driver   = true

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Node Groups
# -----------------------------------------------------------------------------
module "nodegroups" {
  source = "../../modules/nodegroups"

  cluster_name              = module.eks.cluster_name
  cluster_security_group_id = module.eks.cluster_security_group_id
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  node_groups               = var.node_groups

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM (IRSA Roles)
# -----------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url

  enable_cluster_autoscaler       = var.enable_cluster_autoscaler
  enable_load_balancer_controller = var.enable_load_balancer_controller
  enable_external_dns             = var.enable_external_dns
  service_accounts                = local.monitoring_service_accounts

  load_balancer_controller_namespace       = "kube-system"
  load_balancer_controller_service_account = "aws-load-balancer-controller"

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Node-dependent Add-ons
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [module.nodegroups.node_group_arns]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_version
  service_account_role_arn    = module.eks.ebs_csi_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [module.nodegroups.node_group_arns]
}

# -----------------------------------------------------------------------------
# Ingress Controller
# -----------------------------------------------------------------------------
module "ingress" {
  source = "../../modules/ingress"

  enabled      = var.enable_load_balancer_controller
  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id
  iam_role_arn = module.iam.load_balancer_controller_role_arn
  aws_region   = var.region

  image_repository = var.ingress_image_repository
  image_tag        = var.ingress_image_tag
  ingress_class    = var.ingress_class
  replicas         = var.ingress_replicas

  create_ingress_class         = var.ingress_create_ingress_class
  set_as_default_ingress_class = var.ingress_set_as_default

  depends_on = [
    module.iam,
    module.nodegroups.node_group_arns
  ]
}

# -----------------------------------------------------------------------------
# AWS Auth ConfigMap
# -----------------------------------------------------------------------------
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<-EOT
      - rolearn: ${module.nodegroups.node_role_arn}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
    EOT
    mapUsers = yamlencode(concat(
      # Admin users with system:masters access
      [for user_arn in local.admin_user_arns : {
        userarn  = user_arn
        username = split("/", user_arn)[1]
        groups   = ["system:masters"]
      }],
      # GitHub Actions deployer
      [{
        userarn  = module.github_actions_ecr.user_arn
        username = "github-actions-deployer"
        groups   = ["github-actions-deployers"]
      }]
    ))
  }

  force = true

  depends_on = [
    module.eks,
    module.nodegroups
  ]
}

# -----------------------------------------------------------------------------
# Kubernetes Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.project
    labels = {
      name        = var.project
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  depends_on = [module.nodegroups.node_group_arns]
}

# -----------------------------------------------------------------------------
# Kubernetes RBAC for GitHub Actions
# -----------------------------------------------------------------------------
resource "kubernetes_role" "github_actions_deployer" {
  metadata {
    name      = "github-actions-deployer"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims", "serviceaccounts"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Postgres-operator CRDs (acid.zalan.do API group)
  rule {
    api_groups = ["acid.zalan.do"]
    resources  = ["postgresqls", "postgresqls/status", "operatorconfigurations", "postgresteams"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [kubernetes_namespace.app]
}

resource "kubernetes_role_binding" "github_actions_deployer" {
  metadata {
    name      = "github-actions-deployer"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.github_actions_deployer.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "github-actions-deployers"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_role.github_actions_deployer]
}

# -----------------------------------------------------------------------------
# Cluster-scoped RBAC for GitHub Actions (CRD and ClusterRole installation)
# -----------------------------------------------------------------------------
# This ClusterRole allows GitHub Actions to install CRDs and cluster-scoped RBAC
# resources from Helm charts (e.g., postgres-operator CRDs and ClusterRoles).
# It also includes all permissions that postgres-operator ClusterRoles grant,
# since Kubernetes requires you to have permissions before granting them.
resource "kubernetes_cluster_role" "github_actions_deployer_crds" {
  metadata {
    name = "github-actions-deployer-crds"
    labels = {
      managed-by = "terraform"
      purpose    = "github-actions-crd-installation"
    }
  }

  # CRD management
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }

  # Cluster RBAC management
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Namespace-scoped RBAC (cluster-wide access needed to grant via ClusterRole)
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # PriorityClass management
  rule {
    api_groups = ["scheduling.k8s.io"]
    resources  = ["priorityclasses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Core resources (required by postgres-operator)
  rule {
    api_groups = [""]
    resources  = ["configmaps", "endpoints", "events", "namespaces", "nodes", "secrets", "serviceaccounts", "services"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete", "deletecollection"]
  }

  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims", "persistentvolumes"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Postgres-operator CRDs (acid.zalan.do)
  rule {
    api_groups = ["acid.zalan.do"]
    resources  = ["postgresqls", "postgresqls/status", "operatorconfigurations", "postgresteams"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete", "deletecollection"]
  }

  # Apps resources (deployments, statefulsets)
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "replicasets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Batch resources (cronjobs)
  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Policy resources (poddisruptionbudgets)
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [module.eks]
}

resource "kubernetes_cluster_role_binding" "github_actions_deployer_crds" {
  metadata {
    name = "github-actions-deployer-crds"
    labels = {
      managed-by = "terraform"
      purpose    = "github-actions-crd-installation"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.github_actions_deployer_crds.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "github-actions-deployers"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_cluster_role.github_actions_deployer_crds]
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------
# Moved blocks to handle migration from non-count to count-based module
moved {
  from = module.rds
  to   = module.rds[0]
}

module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

  identifier                 = "${local.name}-db"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  allowed_security_group_ids = [module.nodegroups.node_security_group_id]

  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  database_name   = var.db_name
  master_username = var.db_username
  master_password = local.db_password

  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot

  performance_insights_enabled          = var.db_performance_insights_enabled
  performance_insights_retention_period = var.db_performance_insights_retention
  cloudwatch_log_exports                = var.db_cloudwatch_log_exports
  monitoring_interval                   = var.db_monitoring_interval

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch
# -----------------------------------------------------------------------------
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment  = var.environment
  cluster_name = module.eks.cluster_name
  region       = var.region

  log_retention_days = var.cloudwatch_log_retention_days

  application_log_groups     = var.cloudwatch_app_log_groups
  eks_application_log_groups = var.cloudwatch_eks_log_groups

  alert_email_endpoints = var.cloudwatch_alert_emails

  enable_eks_alarms         = var.enable_cloudwatch_eks_alarms
  enable_rds_alarms         = var.enable_rds && var.enable_cloudwatch_rds_alarms
  enable_alb_alarms         = var.enable_cloudwatch_alb_alarms
  enable_nat_gateway_alarms = var.enable_cloudwatch_nat_alarms

  rds_instance_id               = var.enable_rds ? module.rds[0].db_instance_identifier : ""
  rds_max_connections_threshold = var.db_max_connections_threshold
  alb_arn_suffix                = try(module.ingress.alb_arn_suffix, "")
  nat_gateway_ids               = module.vpc.nat_gateway_ids

  create_dashboard = var.create_cloudwatch_dashboard

  tags = local.common_tags

  depends_on = [
    module.eks,
    module.rds,
    module.ingress
  ]
}

# -----------------------------------------------------------------------------
# Monitoring Stack
# -----------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  enabled      = var.enable_prometheus_stack
  cluster_name = module.eks.cluster_name
  environment  = var.environment

  prometheus_retention_days = var.prometheus_retention_days
  prometheus_storage_size   = var.prometheus_storage_size
  prometheus_storage_class  = var.prometheus_storage_class
  prometheus_replicas       = var.prometheus_replicas

  grafana_admin_password  = local.grafana_admin_password
  grafana_ingress_enabled = var.grafana_ingress_enabled
  grafana_ingress_host    = var.grafana_ingress_host
  grafana_ingress_class   = var.grafana_ingress_class
  grafana_replicas        = var.grafana_replicas
  grafana_storage_size    = var.grafana_storage_size

  alertmanager_enabled       = var.alertmanager_enabled
  alertmanager_storage_size  = var.alertmanager_storage_size
  node_exporter_enabled      = var.node_exporter_enabled
  kube_state_metrics_enabled = var.kube_state_metrics_enabled

  tempo_enabled        = var.tempo_enabled
  tempo_replicas       = var.tempo_replicas
  tempo_storage_size   = var.tempo_storage_size
  tempo_retention_days = var.tempo_retention_days
  tempo_s3_bucket      = local.tempo_s3_bucket
  tempo_irsa_role_arn  = try(module.iam.app_role_arns["tempo"], "")

  loki_enabled          = var.loki_enabled
  loki_replicas         = var.loki_replicas
  loki_storage_size     = var.loki_storage_size
  loki_retention_days   = var.loki_retention_days
  loki_s3_bucket_chunks = local.loki_s3_bucket_chunks
  loki_s3_bucket_ruler  = local.loki_s3_bucket_ruler
  loki_irsa_role_arn    = try(module.iam.app_role_arns["loki"], "")

  otel_operator_enabled = var.otel_operator_enabled

  aws_region = var.region

  depends_on = [
    module.eks,
    module.nodegroups,
    module.iam,
    aws_eks_addon.coredns
  ]
}

# -----------------------------------------------------------------------------
# GitHub Actions ECR
# -----------------------------------------------------------------------------
module "github_actions_ecr" {
  source = "../../modules/github-actions-ecr"

  user_name         = "github-actions-ecr-${var.environment}"
  aws_region        = var.region
  ecr_repositories  = ["backend", "frontend"]
  create_access_key = true

  enable_eks_access = true
  eks_cluster_arns  = [module.eks.cluster_arn]

  enable_rds_access = var.enable_rds
  rds_instance_arns = var.enable_rds ? [module.rds[0].db_instance_arn] : []

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
data "github_repository" "backend" {
  count     = var.github_repository != "" ? 1 : 0
  full_name = "${var.github_owner}/${var.github_repository}"
}

resource "github_repository_environment" "backend" {
  count       = var.github_repository != "" ? 1 : 0
  repository  = var.github_repository
  environment = var.environment == "prod" ? "production" : var.environment

  depends_on = [data.github_repository.backend]
}

resource "github_repository_environment" "frontend" {
  count       = var.github_frontend_repository != "" ? 1 : 0
  provider    = github.frontend
  repository  = var.github_frontend_repository
  environment = var.environment == "prod" ? "production" : var.environment
}

# -----------------------------------------------------------------------------
# GitHub Environment Secrets - Backend
# -----------------------------------------------------------------------------
resource "github_actions_environment_secret" "aws_access_key_id" {
  count = var.github_repository != "" ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = module.github_actions_ecr.access_key_id

  depends_on = [github_repository_environment.backend]
}

resource "github_actions_environment_secret" "aws_secret_access_key" {
  count = var.github_repository != "" ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = module.github_actions_ecr.secret_access_key

  depends_on = [github_repository_environment.backend]
}

resource "github_actions_environment_secret" "eks_cluster_name" {
  count = var.github_repository != "" ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "EKS_CLUSTER_NAME"
  plaintext_value = module.eks.cluster_name

  depends_on = [github_repository_environment.backend]
}

resource "github_actions_environment_secret" "rds_identifier" {
  count = var.github_repository != "" && var.enable_rds ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "RDS_IDENTIFIER"
  plaintext_value = module.rds[0].db_instance_identifier

  depends_on = [github_repository_environment.backend]
}

resource "github_actions_environment_secret" "rds_username" {
  count = var.github_repository != "" && var.enable_rds ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "RDS_USERNAME"
  plaintext_value = var.db_username

  depends_on = [github_repository_environment.backend]
}

resource "github_actions_environment_secret" "rds_password" {
  count = var.github_repository != "" && var.db_password != "" && var.enable_rds ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "RDS_PASSWORD"
  plaintext_value = var.db_password

  depends_on = [github_repository_environment.backend]
}

resource "github_actions_environment_secret" "grafana_admin_password" {
  count = var.github_repository != "" && var.grafana_admin_password != "" ? 1 : 0

  repository      = var.github_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "GRAFANA_ADMIN_PASSWORD"
  plaintext_value = var.grafana_admin_password

  depends_on = [github_repository_environment.backend]
}

# -----------------------------------------------------------------------------
# GitHub Environment Secrets - Frontend
# -----------------------------------------------------------------------------
# Note: Frontend secrets use the frontend provider alias
# Falls back to backend token if frontend token not provided
resource "github_actions_environment_secret" "frontend_aws_access_key_id" {
  count    = var.github_frontend_repository != "" ? 1 : 0
  provider = github.frontend

  repository      = var.github_frontend_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = module.github_actions_ecr.access_key_id

  depends_on = [github_repository_environment.frontend]
}

resource "github_actions_environment_secret" "frontend_aws_secret_access_key" {
  count    = var.github_frontend_repository != "" ? 1 : 0
  provider = github.frontend

  repository      = var.github_frontend_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = module.github_actions_ecr.secret_access_key

  depends_on = [github_repository_environment.frontend]
}

resource "github_actions_environment_secret" "frontend_eks_cluster_name" {
  count    = var.github_frontend_repository != "" ? 1 : 0
  provider = github.frontend

  repository      = var.github_frontend_repository
  environment     = var.environment == "prod" ? "production" : var.environment
  secret_name     = "EKS_CLUSTER_NAME"
  plaintext_value = module.eks.cluster_name

  depends_on = [github_repository_environment.frontend]
}

