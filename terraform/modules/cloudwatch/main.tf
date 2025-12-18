#--------------------------------------------------------------
# CloudWatch Module - Logs, Metrics, Alarms
#--------------------------------------------------------------

#--------------------------------------------------------------
# Application Log Groups
#--------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  for_each = var.application_log_groups

  name              = "/app/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days

  kms_key_id = var.kms_key_id

  tags = merge(var.tags, {
    Name        = "${var.environment}-${each.key}-logs"
    Application = each.key
  })
}

#--------------------------------------------------------------
# EKS Application Log Groups
#--------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks_app" {
  for_each = var.eks_application_log_groups

  name              = "/eks/${var.environment}/${var.cluster_name}/${each.key}"
  retention_in_days = var.log_retention_days

  kms_key_id = var.kms_key_id

  tags = merge(var.tags, {
    Name        = "${var.environment}-${each.key}-eks-logs"
    Application = each.key
  })
}

#--------------------------------------------------------------
# SNS Topics for Alerting
#--------------------------------------------------------------
resource "aws_sns_topic" "cloudwatch_alarms" {
  name              = "${var.environment}-cloudwatch-alarms"
  display_name      = "CloudWatch Alarms - ${var.environment}"
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    Name = "${var.environment}-cloudwatch-alarms"
  })
}

resource "aws_sns_topic" "critical_alarms" {
  name              = "${var.environment}-critical-alarms"
  display_name      = "Critical Alarms (SEV-1) - ${var.environment}"
  kms_master_key_id = var.kms_key_id

  tags = merge(var.tags, {
    Name     = "${var.environment}-critical-alarms"
    Severity = "SEV-1"
  })
}

# Email subscriptions (optional, can be managed manually)
resource "aws_sns_topic_subscription" "email" {
  for_each = var.alert_email_endpoints

  topic_arn = each.value == "critical" ? aws_sns_topic.critical_alarms.arn : aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = each.key
}

#--------------------------------------------------------------
# EKS Cluster Alarms
#--------------------------------------------------------------
# API Server Availability
resource "aws_cloudwatch_metric_alarm" "eks_api_server_availability" {
  count = var.enable_eks_alarms ? 1 : 0

  alarm_name          = "${var.environment}-eks-api-server-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "cluster_failed_node_count"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "EKS API Server is experiencing issues"
  alarm_actions       = [aws_sns_topic.critical_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# Node CPU Utilization
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  count = var.enable_eks_alarms ? 1 : 0

  alarm_name          = "${var.environment}-eks-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node CPU utilization is high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# Node Memory Utilization
resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  count = var.enable_eks_alarms ? 1 : 0

  alarm_name          = "${var.environment}-eks-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node memory utilization is high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# Pod Restarts
resource "aws_cloudwatch_metric_alarm" "pod_restarts" {
  count = var.enable_eks_alarms ? 1 : 0

  alarm_name          = "${var.environment}-eks-high-pod-restarts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High number of pod restarts detected"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

#--------------------------------------------------------------
# RDS Alarms
#--------------------------------------------------------------
# RDS CPU High
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.enable_rds_alarms && var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

# RDS Connections High
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count = var.enable_rds_alarms && var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_max_connections_threshold
  alarm_description   = "RDS database connections are high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

# RDS Storage Low
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  count = var.enable_rds_alarms && var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240  # 10GB in bytes
  alarm_description   = "RDS free storage space is low"
  alarm_actions       = [aws_sns_topic.critical_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

# RDS Read Latency High
resource "aws_cloudwatch_metric_alarm" "rds_read_latency_high" {
  count = var.enable_rds_alarms && var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.environment}-rds-read-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1  # 100ms
  alarm_description   = "RDS read latency is high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

# RDS Write Latency High
resource "aws_cloudwatch_metric_alarm" "rds_write_latency_high" {
  count = var.enable_rds_alarms && var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.environment}-rds-write-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1  # 100ms
  alarm_description   = "RDS write latency is high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}

#--------------------------------------------------------------
# ALB Alarms (if enabled and ALB exists)
#--------------------------------------------------------------
# ALB alarms are only created when alb_arn_suffix is provided (non-empty)
# The ALB is created when an Ingress resource is deployed, not by the controller itself

# ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  count = var.enable_alb_alarms && var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.environment}-alb-5xx-errors-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "ALB is experiencing high 5xx errors"
  alarm_actions       = [aws_sns_topic.critical_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time_high" {
  count = var.enable_alb_alarms && var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.environment}-alb-target-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0  # 1 second
  alarm_description   = "ALB target response time is high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB Unhealthy Target Count
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = var.enable_alb_alarms && var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB has unhealthy targets"
  alarm_actions       = [aws_sns_topic.critical_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

#--------------------------------------------------------------
# NAT Gateway Alarms
#--------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "nat_gateway_connections_high" {
  for_each = var.enable_nat_gateway_alarms ? var.nat_gateway_ids : {}

  alarm_name          = "${var.environment}-nat-${each.key}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ActiveConnectionCount"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Maximum"
  threshold           = 55000  # NAT Gateway limit is ~55k
  alarm_description   = "NAT Gateway active connections approaching limit"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    NatGatewayId = each.value
  }

  tags = var.tags
}

#--------------------------------------------------------------
# CloudWatch Dashboards
#--------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.environment}-overview"

  dashboard_body = jsonencode({
    widgets = [
      # EKS Cluster Health
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", { stat = "Average", label = "Node CPU" }],
            [".", "node_memory_utilization", { stat = "Average", label = "Node Memory" }],
            [".", "pod_cpu_utilization", { stat = "Average", label = "Pod CPU" }],
            [".", "pod_memory_utilization", { stat = "Average", label = "Pod Memory" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EKS Cluster Resource Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # RDS Metrics
      {
        type = "metric"
        properties = {
          metrics = var.rds_instance_id != "" ? [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "CPU %" }],
            [".", "DatabaseConnections", { stat = "Average", label = "Connections" }],
            [".", "FreeStorageSpace", { stat = "Average", label = "Free Storage" }],
            [".", "ReadLatency", { stat = "Average", label = "Read Latency" }],
            [".", "WriteLatency", { stat = "Average", label = "Write Latency" }]
          ] : []
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Metrics"
        }
      },
      # ALB Metrics
      {
        type = "metric"
        properties = {
          metrics = var.alb_arn_suffix != "" ? [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum", label = "Requests" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", label = "5xx Errors" }],
            [".", "TargetResponseTime", { stat = "Average", label = "Response Time" }],
            [".", "UnHealthyHostCount", { stat = "Average", label = "Unhealthy Targets" }]
          ] : []
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ALB Metrics"
        }
      }
    ]
  })
}

