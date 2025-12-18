#--------------------------------------------------------------
# Ingress Module - AWS Load Balancer Controller
# Using Helm for best practice - automatically handles CRDs
#--------------------------------------------------------------

#--------------------------------------------------------------
# Namespace for AWS Load Balancer Controller
#--------------------------------------------------------------
# Use data source for kube-system (always exists) or create for other namespaces
data "kubernetes_namespace" "aws_load_balancer_controller" {
  count = var.enabled && var.namespace == "kube-system" ? 1 : 0
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_namespace" "aws_load_balancer_controller" {
  count = var.enabled && var.namespace != "kube-system" ? 1 : 0

  metadata {
    name = var.namespace
    labels = merge(var.labels, {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    })
  }
}

locals {
  # Reference the namespace from either data source or created resource
  namespace_name = var.enabled ? (
    var.namespace == "kube-system"
      ? data.kubernetes_namespace.aws_load_balancer_controller[0].metadata[0].name
      : kubernetes_namespace.aws_load_balancer_controller[0].metadata[0].name
  ) : ""

  # Helm values for AWS Load Balancer Controller
  helm_values = merge({
    clusterName = var.cluster_name
    region      = var.aws_region
    vpcId       = var.vpc_id

    serviceAccount = {
      create = false
      name   = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = var.iam_role_arn
      }
    }

    replicaCount = var.replicas

    image = {
      repository = var.image_repository
      tag        = var.image_tag
    }

    ingressClass             = var.ingress_class
    createIngressClassResource = var.create_ingress_class

    resources = {
      requests = var.resources.requests
      limits   = var.resources.limits
    }
  }, length(var.node_selector) > 0 ? {
    nodeSelector = var.node_selector
  } : {  }, length(var.tolerations) > 0 ? {
    tolerations = var.tolerations
  } : {}, var.replicas > 1 ? {
    podDisruptionBudget = {
      enabled        = true
      maxUnavailable = 1
    }
  } : {}, var.create_ingress_class ? {
    ingressClassConfig = {
      default = var.set_as_default_ingress_class
    }
  } : {}, length(var.extra_args) > 0 ? {
    extraArgs = var.extra_args
  } : {})
}

#--------------------------------------------------------------
# Service Account (created separately to ensure IRSA annotation is set before Helm)
#--------------------------------------------------------------
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = local.namespace_name
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = var.iam_role_arn
    }
  }
}

#--------------------------------------------------------------
# AWS Load Balancer Controller via Helm
#--------------------------------------------------------------
# Using Helm is the recommended approach as it:
# 1. Automatically installs CRDs (including TargetGroupBinding)
# 2. Manages all resources (Deployment, ClusterRole, ClusterRoleBinding, etc.)
# 3. Follows AWS best practices
# 4. Easier to maintain and update
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enabled ? 1 : 0

  name       = var.release_name
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.helm_chart_version
  namespace  = local.namespace_name

  # Install CRDs automatically (Helm v3 behavior)
  # The official chart includes CRDs in the crds/ directory
  skip_crds = false

  values = [
    yamlencode(local.helm_values)
  ]

  # Wait for deployment to be ready
  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

# Note: IngressClass is now managed by Helm chart
# The Helm chart automatically creates the IngressClass based on the values
# No separate Terraform resource needed
