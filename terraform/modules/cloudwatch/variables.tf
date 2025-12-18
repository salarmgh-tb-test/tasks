#--------------------------------------------------------------
# CloudWatch Module Variables
#--------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
}

#--------------------------------------------------------------
# Log Groups
#--------------------------------------------------------------
variable "application_log_groups" {
  description = "Map of application log groups to create"
  type        = map(string)
  default = {
    frontend = "Frontend application logs"
    backend  = "Backend application logs"
  }
}

variable "eks_application_log_groups" {
  description = "Map of EKS application log groups to create"
  type        = map(string)
  default = {
    frontend    = "Frontend pods"
    backend     = "Backend pods"
    postgres    = "PostgreSQL pods"
    nginx       = "Nginx ingress controller"
    autoscaler  = "Cluster autoscaler"
    lb-controller = "Load balancer controller"
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for log encryption"
  type        = string
  default     = null
}

#--------------------------------------------------------------
# Alerting
#--------------------------------------------------------------
variable "alert_email_endpoints" {
  description = "Map of email addresses to subscribe to alerts (value: 'critical' or 'standard')"
  type        = map(string)
  default     = {}
  # Example:
  # {
  #   "ops@example.com" = "critical"
  #   "dev@example.com" = "standard"
  # }
}

#--------------------------------------------------------------
# Alarm Toggles
#--------------------------------------------------------------
variable "enable_eks_alarms" {
  description = "Enable EKS CloudWatch alarms"
  type        = bool
  default     = true
}

variable "enable_rds_alarms" {
  description = "Enable RDS CloudWatch alarms"
  type        = bool
  default     = true
}

variable "enable_alb_alarms" {
  description = "Enable ALB CloudWatch alarms (requires alb_arn_suffix to be set)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway_alarms" {
  description = "Enable NAT Gateway CloudWatch alarms"
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Resource IDs for Alarms
#--------------------------------------------------------------
variable "rds_instance_id" {
  description = "RDS instance identifier for alarms"
  type        = string
  default     = ""
}

variable "rds_max_connections_threshold" {
  description = "Threshold for RDS max connections alarm"
  type        = number
  default     = 80
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for metrics (format: app/my-lb/1234567890abcdef)"
  type        = string
  default     = ""
}

variable "nat_gateway_ids" {
  description = "Map of NAT Gateway IDs for alarms"
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# Dashboard
#--------------------------------------------------------------
variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Tags
#--------------------------------------------------------------
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

