#--------------------------------------------------------------
# IAM Module Outputs
#--------------------------------------------------------------

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "cluster_autoscaler_role_name" {
  description = "IAM role name for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].name : null
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_load_balancer_controller ? aws_iam_role.load_balancer_controller[0].arn : null
}

output "load_balancer_controller_role_name" {
  description = "IAM role name for AWS Load Balancer Controller"
  value       = var.enable_load_balancer_controller ? aws_iam_role.load_balancer_controller[0].name : null
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
}

output "external_dns_role_name" {
  description = "IAM role name for External DNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].name : null
}

output "app_role_arns" {
  description = "Map of application service account role ARNs"
  value       = { for k, v in aws_iam_role.app : k => v.arn }
}

output "app_role_names" {
  description = "Map of application service account role names"
  value       = { for k, v in aws_iam_role.app : k => v.name }
}
