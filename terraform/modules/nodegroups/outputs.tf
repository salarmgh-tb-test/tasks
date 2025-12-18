output "node_security_group_id" {
  description = "Security group ID for the node groups"
  value       = aws_security_group.node.id
}

output "node_role_arn" {
  description = "IAM role ARN for the node groups"
  value       = aws_iam_role.node.arn
}

output "node_group_arns" {
  description = "ARNs of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.arn }
}

output "node_group_statuses" {
  description = "Status of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.status }
}

