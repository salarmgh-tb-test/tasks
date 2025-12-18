#--------------------------------------------------------------
# CloudWatch Module Outputs
#--------------------------------------------------------------

output "app_log_group_names" {
  description = "Map of application log group names"
  value       = { for k, v in aws_cloudwatch_log_group.app : k => v.name }
}

output "eks_app_log_group_names" {
  description = "Map of EKS application log group names"
  value       = { for k, v in aws_cloudwatch_log_group.eks_app : k => v.name }
}

output "cloudwatch_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.cloudwatch_alarms.arn
}

output "critical_alarms_topic_arn" {
  description = "SNS topic ARN for critical alarms"
  value       = aws_sns_topic.critical_alarms.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}

output "eks_alarm_names" {
  description = "List of EKS alarm names"
  value = var.enable_eks_alarms ? [
    aws_cloudwatch_metric_alarm.eks_api_server_availability[0].alarm_name,
    aws_cloudwatch_metric_alarm.node_cpu_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.node_memory_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.pod_restarts[0].alarm_name,
  ] : []
}

output "rds_alarm_names" {
  description = "List of RDS alarm names"
  value = var.enable_rds_alarms && var.rds_instance_id != "" ? [
    aws_cloudwatch_metric_alarm.rds_cpu_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.rds_connections_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.rds_storage_low[0].alarm_name,
    aws_cloudwatch_metric_alarm.rds_read_latency_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.rds_write_latency_high[0].alarm_name,
  ] : []
}

output "alb_alarm_names" {
  description = "List of ALB alarm names"
  value = length(aws_cloudwatch_metric_alarm.alb_5xx_high) > 0 ? [
    aws_cloudwatch_metric_alarm.alb_5xx_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.alb_target_response_time_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.alb_unhealthy_targets[0].alarm_name,
  ] : []
}

