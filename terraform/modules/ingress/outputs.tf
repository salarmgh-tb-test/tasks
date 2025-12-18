output "namespace" {
  description = "Namespace where the ingress controller is deployed"
  value       = var.enabled ? local.namespace_name : null
}

output "service_account_name" {
  description = "Name of the service account for the ingress controller"
  value       = var.enabled ? var.service_account_name : null
}

output "release_name" {
  description = "Name of the Helm release for the ingress controller"
  value       = var.enabled ? var.release_name : null
}

output "ingress_class" {
  description = "Ingress class name"
  value       = var.enabled ? var.ingress_class : null
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics (extracted from load balancer)"
  value       = var.enabled ? try(split("/", data.kubernetes_service.alb_service[0].status[0].load_balancer[0].ingress[0].hostname)[0], "") : ""
}

# Data source to get ALB information
data "kubernetes_service" "alb_service" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = local.namespace_name
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

