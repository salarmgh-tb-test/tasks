#--------------------------------------------------------------
# Monitoring Module Variables
#--------------------------------------------------------------

variable "enabled" {
  description = "Enable monitoring stack deployment"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring"
  type        = string
  default     = "monitoring"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "kube-prometheus-stack chart version"
  type        = string
  default     = "65.0.0"
}

#--------------------------------------------------------------
# Prometheus Configuration
#--------------------------------------------------------------
variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 7
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "50Gi"
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus"
  type        = string
  default     = "gp3"
}

variable "prometheus_replicas" {
  description = "Number of Prometheus replicas"
  type        = number
  default     = 1
}

#--------------------------------------------------------------
# Grafana Configuration
#--------------------------------------------------------------
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "grafana_ingress_enabled" {
  description = "Enable Grafana ingress"
  type        = bool
  default     = false
}

variable "grafana_ingress_host" {
  description = "Grafana ingress hostname"
  type        = string
  default     = ""
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
  default     = "10Gi"
}

variable "grafana_irsa_role_arn" {
  description = "IAM role ARN for Grafana service account (IRSA)"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Component Toggles
#--------------------------------------------------------------
variable "alertmanager_enabled" {
  description = "Enable Alertmanager"
  type        = bool
  default     = true
}

variable "alertmanager_storage_size" {
  description = "Alertmanager storage size"
  type        = string
  default     = "10Gi"
}

variable "node_exporter_enabled" {
  description = "Enable node-exporter"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Enable kube-state-metrics"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Additional Values
#--------------------------------------------------------------
variable "additional_values" {
  description = "Additional Helm values to pass"
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# Tempo Configuration (Distributed Tracing)
#--------------------------------------------------------------
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

#--------------------------------------------------------------
# Loki Configuration (Log Aggregation)
#--------------------------------------------------------------
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

#--------------------------------------------------------------
# S3 Configuration for Tempo and Loki
#--------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for S3 buckets"
  type        = string
  default     = "eu-north-1"
}

variable "tempo_s3_bucket" {
  description = "S3 bucket name for Tempo trace storage"
  type        = string
  default     = ""
}

variable "tempo_irsa_role_arn" {
  description = "IAM role ARN for Tempo service account (IRSA) - required for S3 access"
  type        = string
  default     = ""
}

variable "loki_s3_bucket_chunks" {
  description = "S3 bucket name for Loki chunks storage"
  type        = string
  default     = ""
}

variable "loki_s3_bucket_ruler" {
  description = "S3 bucket name for Loki ruler storage"
  type        = string
  default     = ""
}

variable "loki_irsa_role_arn" {
  description = "IAM role ARN for Loki service account (IRSA) - required for S3 access"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# OpenTelemetry Operator Configuration
#--------------------------------------------------------------
variable "otel_operator_enabled" {
  description = "Enable OpenTelemetry Operator for auto-instrumentation and collector management"
  type        = bool
  default     = false
}

