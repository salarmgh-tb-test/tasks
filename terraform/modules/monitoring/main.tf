#--------------------------------------------------------------
# Monitoring Module - Prometheus, Grafana, Tempo, Loki, OpenTelemetry
#--------------------------------------------------------------

#--------------------------------------------------------------
# Monitoring Namespace
#--------------------------------------------------------------
resource "kubernetes_namespace" "monitoring" {
  count = var.enabled ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      name                                   = var.namespace
      "pod-security.kubernetes.io/enforce"   = "privileged"
      "pod-security.kubernetes.io/audit"     = "privileged"
      "pod-security.kubernetes.io/warn"      = "privileged"
    }
  }
}

#--------------------------------------------------------------
# kube-prometheus-stack Helm Release
#--------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  count = var.enabled ? 1 : 0

  name       = var.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/values.yaml", {
      cluster_name                     = var.cluster_name
      environment                      = var.environment
      prometheus_replicas             = var.prometheus_replicas
      prometheus_retention_days       = var.prometheus_retention_days
      prometheus_storage_size         = var.prometheus_storage_size
      prometheus_storage_class        = var.prometheus_storage_class
      grafana_admin_password          = var.grafana_admin_password
      grafana_replicas                = var.grafana_replicas
      grafana_storage_size            = var.grafana_storage_size
      grafana_ingress_enabled         = var.grafana_ingress_enabled
      grafana_ingress_host            = var.grafana_ingress_host
      grafana_ingress_class           = var.grafana_ingress_class
      alertmanager_enabled            = var.alertmanager_enabled
      alertmanager_storage_size       = var.alertmanager_storage_size
      node_exporter_enabled           = var.node_exporter_enabled
      kube_state_metrics_enabled      = var.kube_state_metrics_enabled
    })
  ]

  dynamic "set" {
    for_each = var.additional_values
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

#--------------------------------------------------------------
# Grafana Service Account Annotation for IRSA
#--------------------------------------------------------------
resource "kubernetes_annotations" "grafana_service_account" {
  count = var.enabled && var.grafana_irsa_role_arn != "" ? 1 : 0

  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    name      = "${var.release_name}-grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  annotations = {
    "eks.amazonaws.com/role-arn" = var.grafana_irsa_role_arn
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

#--------------------------------------------------------------
# Tempo Helm Release
#--------------------------------------------------------------
resource "helm_release" "tempo" {
  count = var.enabled && var.tempo_enabled ? 1 : 0

  name      = "tempo"
  chart     = "${path.module}/../../charts/tempo"
  namespace = kubernetes_namespace.monitoring[0].metadata[0].name

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/tempo-values.yaml", {
      environment          = var.environment
      tempo_replicas       = var.tempo_replicas
      tempo_storage_size   = var.tempo_storage_size
      tempo_s3_bucket      = var.tempo_s3_bucket
      s3_endpoint          = "s3.${var.aws_region}.amazonaws.com"
      tempo_retention_hours = var.tempo_retention_days * 24
      tempo_irsa_role_arn  = var.tempo_irsa_role_arn
      aws_region           = var.aws_region
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.kube_prometheus_stack,
    aws_s3_bucket.tempo[0]
  ]
}

#--------------------------------------------------------------
# Loki Helm Release
#--------------------------------------------------------------
resource "helm_release" "loki" {
  count = var.enabled && var.loki_enabled ? 1 : 0

  name      = "loki"
  chart     = "${path.module}/../../charts/loki"
  namespace = kubernetes_namespace.monitoring[0].metadata[0].name

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/loki-values.yaml", {
      environment          = var.environment
      loki_replicas        = var.loki_replicas
      loki_storage_size    = var.loki_storage_size
      loki_s3_bucket_chunks = var.loki_s3_bucket_chunks
      loki_s3_bucket_ruler  = var.loki_s3_bucket_ruler
      loki_retention_days  = var.loki_retention_days
      loki_irsa_role_arn   = var.loki_irsa_role_arn
      aws_region           = var.aws_region
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.kube_prometheus_stack,
    aws_s3_bucket.loki_chunks,
    aws_s3_bucket.loki_ruler,
  ]
}

#--------------------------------------------------------------
# S3 Buckets for Tempo and Loki
#--------------------------------------------------------------

# Tempo S3 Bucket for trace storage
resource "aws_s3_bucket" "tempo" {
  count = var.enabled && var.tempo_enabled && var.tempo_s3_bucket != "" ? 1 : 0

  bucket = var.tempo_s3_bucket

  tags = {
    Name        = var.tempo_s3_bucket
    Environment = var.environment
    Purpose     = "tempo-traces"
    ManagedBy   = "terraform"
  }
}

# Block public access for Tempo bucket
resource "aws_s3_bucket_public_access_block" "tempo" {
  count  = var.enabled && var.tempo_enabled && var.tempo_s3_bucket != "" ? 1 : 0
  bucket = aws_s3_bucket.tempo[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for Tempo bucket (optional but recommended)
resource "aws_s3_bucket_versioning" "tempo" {
  count = var.enabled && var.tempo_enabled && var.tempo_s3_bucket != "" ? 1 : 0

  bucket = aws_s3_bucket.tempo[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for Tempo bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  count = var.enabled && var.tempo_enabled && var.tempo_s3_bucket != "" ? 1 : 0

  bucket = aws_s3_bucket.tempo[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for Tempo bucket (auto-delete old traces)
resource "aws_s3_bucket_lifecycle_configuration" "tempo" {
  count = var.enabled && var.tempo_enabled && var.tempo_s3_bucket != "" ? 1 : 0

  bucket = aws_s3_bucket.tempo[0].id

  rule {
    id     = "delete-old-traces"
    status = "Enabled"

    filter {}

    expiration {
      days = var.tempo_retention_days
    }
  }
}

# Loki S3 Bucket for log chunks storage
resource "aws_s3_bucket" "loki_chunks" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_chunks != "" ? 1 : 0

  bucket = var.loki_s3_bucket_chunks

  tags = {
    Name        = var.loki_s3_bucket_chunks
    Environment = var.environment
    Purpose     = "loki-chunks"
    ManagedBy   = "terraform"
  }
}

# Block public access for Loki chunks bucket
resource "aws_s3_bucket_public_access_block" "loki_chunks" {
  count  = var.enabled && var.loki_enabled && var.loki_s3_bucket_chunks != "" ? 1 : 0
  bucket = aws_s3_bucket.loki_chunks[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for Loki chunks bucket
resource "aws_s3_bucket_versioning" "loki_chunks" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_chunks != "" ? 1 : 0

  bucket = aws_s3_bucket.loki_chunks[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for Loki chunks bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_chunks" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_chunks != "" ? 1 : 0

  bucket = aws_s3_bucket.loki_chunks[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for Loki chunks bucket
resource "aws_s3_bucket_lifecycle_configuration" "loki_chunks" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_chunks != "" ? 1 : 0

  bucket = aws_s3_bucket.loki_chunks[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.loki_retention_days
    }
  }
}

# Loki S3 Bucket for ruler storage
resource "aws_s3_bucket" "loki_ruler" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_ruler != "" ? 1 : 0

  bucket = var.loki_s3_bucket_ruler

  tags = {
    Name        = var.loki_s3_bucket_ruler
    Environment = var.environment
    Purpose     = "loki-ruler"
    ManagedBy   = "terraform"
  }
}

# Block public access for Loki ruler bucket
resource "aws_s3_bucket_public_access_block" "loki_ruler" {
  count  = var.enabled && var.loki_enabled && var.loki_s3_bucket_ruler != "" ? 1 : 0
  bucket = aws_s3_bucket.loki_ruler[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for Loki ruler bucket
resource "aws_s3_bucket_versioning" "loki_ruler" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_ruler != "" ? 1 : 0

  bucket = aws_s3_bucket.loki_ruler[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for Loki ruler bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_ruler" {
  count = var.enabled && var.loki_enabled && var.loki_s3_bucket_ruler != "" ? 1 : 0

  bucket = aws_s3_bucket.loki_ruler[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#--------------------------------------------------------------
# OpenTelemetry Operator
#--------------------------------------------------------------
resource "helm_release" "otel_operator" {
  count = var.enabled && var.otel_operator_enabled ? 1 : 0

  name      = "opentelemetry-operator"
  chart     = "${path.module}/../../charts/opentelemetry-operator"
  namespace = kubernetes_namespace.monitoring[0].metadata[0].name

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/otel-operator-values.yaml", {
      environment         = var.environment
      certmanager_enabled = false  # Set to true if cert-manager is installed
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.kube_prometheus_stack,
  ]
}
