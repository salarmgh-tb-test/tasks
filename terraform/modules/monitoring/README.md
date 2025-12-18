# Monitoring Module

Deploys a complete monitoring stack with Prometheus, Grafana, Tempo, Loki, and OpenTelemetry.

## Features

- **kube-prometheus-stack**: Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics
- **Tempo**: Distributed tracing with S3 backend
- **Loki**: Log aggregation with S3 backend
- **OpenTelemetry Operator**: Auto-instrumentation and collector management
- S3 buckets with encryption and lifecycle policies
- Public access blocked on all S3 buckets
- IRSA integration for AWS API access

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  enabled      = true
  cluster_name = module.eks.cluster_name
  environment  = "dev"

  # Prometheus
  prometheus_retention_days = 7
  prometheus_storage_size   = "50Gi"
  prometheus_storage_class  = "gp3"

  # Grafana
  grafana_admin_password  = var.grafana_password
  grafana_ingress_enabled = false

  # Tempo (distributed tracing)
  tempo_enabled        = true
  tempo_s3_bucket      = "tempo-traces-dev"
  tempo_retention_days = 7
  tempo_irsa_role_arn  = module.iam.app_role_arns["tempo"]

  # Loki (log aggregation)
  loki_enabled          = true
  loki_s3_bucket_chunks = "loki-chunks-dev"
  loki_s3_bucket_ruler  = "loki-ruler-dev"
  loki_retention_days   = 7
  loki_irsa_role_arn    = module.iam.app_role_arns["loki"]

  # OpenTelemetry
  otel_operator_enabled = true

  aws_region = var.region

  depends_on = [module.nodegroups]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| enabled | Enable monitoring stack deployment | `bool` | `true` | no |
| cluster_name | EKS cluster name | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| prometheus_retention_days | Prometheus data retention in days | `number` | `7` | no |
| prometheus_storage_size | Prometheus storage size | `string` | `"50Gi"` | no |
| prometheus_storage_class | Storage class for Prometheus | `string` | `"gp3"` | no |
| grafana_admin_password | Grafana admin password | `string` | `"admin"` | no |
| grafana_ingress_enabled | Enable Grafana ingress | `bool` | `false` | no |
| tempo_enabled | Enable Tempo | `bool` | `true` | no |
| tempo_s3_bucket | S3 bucket for Tempo traces | `string` | `""` | no |
| loki_enabled | Enable Loki | `bool` | `true` | no |
| loki_s3_bucket_chunks | S3 bucket for Loki chunks | `string` | `""` | no |
| loki_s3_bucket_ruler | S3 bucket for Loki ruler | `string` | `""` | no |
| otel_operator_enabled | Enable OpenTelemetry Operator | `bool` | `false` | no |
| aws_region | AWS region for S3 buckets | `string` | `"eu-north-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Monitoring namespace |
| prometheus_service | Prometheus service name |
| grafana_service | Grafana service name |
| grafana_admin_password | Grafana admin password (sensitive) |

