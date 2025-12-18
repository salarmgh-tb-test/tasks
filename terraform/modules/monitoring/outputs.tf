#--------------------------------------------------------------
# Monitoring Module Outputs
#--------------------------------------------------------------

output "namespace" {
  description = "Monitoring namespace"
  value       = var.enabled ? kubernetes_namespace.monitoring[0].metadata[0].name : null
}

output "prometheus_endpoint" {
  description = "Prometheus service endpoint"
  value       = var.enabled ? "${var.release_name}-prometheus.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:9090" : null
}

output "grafana_endpoint" {
  description = "Grafana service endpoint"
  value       = var.enabled ? "${var.release_name}-grafana.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:80" : null
}

output "alertmanager_endpoint" {
  description = "Alertmanager service endpoint"
  value       = var.enabled && var.alertmanager_enabled ? "${var.release_name}-alertmanager.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:9093" : null
}

output "tempo_endpoint" {
  description = "Tempo service endpoint for traces"
  value       = var.enabled && var.tempo_enabled ? "tempo.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:3100" : null
}

output "tempo_otlp_grpc_endpoint" {
  description = "Tempo OTLP gRPC endpoint"
  value       = var.enabled && var.tempo_enabled ? "tempo.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:4317" : null
}

output "tempo_otlp_http_endpoint" {
  description = "Tempo OTLP HTTP endpoint"
  value       = var.enabled && var.tempo_enabled ? "http://tempo.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:4318" : null
}

output "loki_endpoint" {
  description = "Loki service endpoint for logs"
  value       = var.enabled && var.loki_enabled ? "loki-gateway.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:80" : null
}

output "loki_push_endpoint" {
  description = "Loki push endpoint for log ingestion"
  value       = var.enabled && var.loki_enabled ? "http://loki-gateway.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:80/loki/api/v1/push" : null
}

# Additional outputs for compatibility
output "prometheus_service" {
  description = "Prometheus service name"
  value       = var.enabled ? "${var.release_name}-prometheus" : null
}

output "grafana_service" {
  description = "Grafana service name"
  value       = var.enabled ? "${var.release_name}-grafana" : null
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "otel_operator_status" {
  description = "OpenTelemetry Operator deployment status"
  value = var.enabled && var.otel_operator_enabled ? {
    release_name = try(helm_release.otel_operator[0].name, null)
    namespace    = try(helm_release.otel_operator[0].namespace, null)
    version      = try(helm_release.otel_operator[0].version, null)
    status       = try(helm_release.otel_operator[0].status, null)
  } : null
}
