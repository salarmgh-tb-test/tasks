# Task D1 - Build a Logging & Monitoring Strategy

## Implementation Status

**This monitoring and logging strategy has been implemented in Terraform.**

### Terraform Implementation Paths

- **Monitoring Stack Module**: `terraform/modules/monitoring/`

  - Prometheus, Grafana, Alertmanager, Tempo, Loki, OpenTelemetry Operator
  - Helm charts and Kubernetes resources
  - S3 buckets for Tempo traces and Loki logs

- **CloudWatch Module**: `terraform/modules/cloudwatch/`

  - CloudWatch Log Groups
  - CloudWatch Alarms
  - SNS Topics for alerting
  - CloudWatch Dashboards

- **Platform Stack Integration**: `terraform/stacks/platform/main.tf`

  - Orchestrates monitoring and CloudWatch modules
  - Environment-specific configurations

- **Environment Configurations**:
  - `terraform/environments/dev/`
  - `terraform/environments/staging/`
  - `terraform/environments/prod/`

### Documentation and Implementation Details

Below is the complete documentation and implementation details for the logging and monitoring strategy:

---

## Problem Statement

Design a comprehensive observability strategy including:

- CloudWatch logs & metrics
- Prometheus + Grafana
- OpenTelemetry
- Alerting strategy (incidents/SEV definitions)
- Log retention and indexing plan
- Example dashboards

---

## Observability Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                            Observability Architecture                                    │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                              Data Sources                                        │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │   │
│   │  │ Application │  │ Kubernetes  │  │    AWS      │  │  External   │            │   │
│   │  │   Pods      │  │   Events    │  │  Services   │  │    APIs     │            │   │
│   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │   │
│   └─────────┼────────────────┼────────────────┼────────────────┼────────────────────┘   │
│             │                │                │                │                         │
│             ▼                ▼                ▼                ▼                         │
│   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│   │                         OpenTelemetry Collector                                  │   │
│   │                    (Unified Collection & Processing)                             │   │
│   │  ┌──────────────────┬──────────────────┬──────────────────┐                     │   │
│   │  │     Traces       │     Metrics      │      Logs        │                     │   │
│   │  └────────┬─────────┴────────┬─────────┴────────┬─────────┘                     │   │
│   └───────────┼──────────────────┼──────────────────┼────────────────────────────────┘   │
│               │                  │                  │                                    │
│     ┌─────────┴─────┐   ┌───────┴────────┐  ┌──────┴───────┐                           │
│     ▼               ▼   ▼                ▼  ▼              ▼                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │  Tempo   │  │ Jaeger   │  │Prometheus│  │CloudWatch│  │  Loki    │                 │
│  │ (Traces) │  │ (Traces) │  │(Metrics) │  │  (AWS)   │  │ (Logs)   │                 │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
│       │             │             │             │             │                        │
│       └─────────────┴──────┬──────┴─────────────┴─────────────┘                        │
│                            │                                                            │
│                            ▼                                                            │
│              ┌─────────────────────────────┐                                           │
│              │         Grafana             │                                           │
│              │   (Unified Visualization)   │                                           │
│              └──────────────┬──────────────┘                                           │
│                             │                                                           │
│                             ▼                                                           │
│              ┌─────────────────────────────┐                                           │
│              │      Alert Manager          │───────▶ PagerDuty / Slack / Email        │
│              └─────────────────────────────┘                                           │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Three Pillars of Observability

### 1. Logs

| Component        | Tool                   | Purpose                |
| ---------------- | ---------------------- | ---------------------- |
| Application Logs | Loki / CloudWatch Logs | Application debugging  |
| Kubernetes Logs  | Fluent Bit → Loki      | Container logs         |
| AWS Service Logs | CloudWatch Logs        | Infrastructure logging |
| Audit Logs       | CloudTrail             | Security compliance    |

### 2. Metrics

| Component              | Tool               | Purpose            |
| ---------------------- | ------------------ | ------------------ |
| Application Metrics    | Prometheus         | Custom app metrics |
| Kubernetes Metrics     | kube-state-metrics | Cluster health     |
| Infrastructure Metrics | CloudWatch Metrics | AWS resources      |
| Business Metrics       | Custom exporters   | KPIs               |

### 3. Traces

| Component             | Tool                   | Purpose               |
| --------------------- | ---------------------- | --------------------- |
| Distributed Traces    | Tempo / Jaeger         | Request flow tracking |
| Service Dependencies  | Service mesh telemetry | Service topology      |
| Performance Profiling | Continuous profiling   | Code-level insights   |

---

## CloudWatch Configuration

### Log Groups Structure

```
/aws/
├── eks/
│   └── myapp-cluster/
│       ├── cluster                    # Control plane logs
│       ├── containers                 # Application container logs
│       └── performance                # Metrics from Container Insights
├── rds/
│   └── myapp-db/
│       ├── postgresql                 # PostgreSQL logs
│       └── upgrade                    # Upgrade logs
├── lambda/
│   └── myapp-functions/               # Lambda execution logs
├── apigateway/
│   └── myapp-api/                     # API Gateway access logs
└── vpc/
    └── myapp-vpc/
        └── flow-logs                  # VPC Flow Logs
```

### CloudWatch Agent Configuration

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent",
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/myapp/*.log",
            "log_group_name": "/aws/eks/myapp-cluster/containers",
            "log_stream_name": "{instance_id}/{hostname}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S",
            "multi_line_start_pattern": "^\\d{4}-\\d{2}-\\d{2}",
            "retention_in_days": 30
          }
        ]
      }
    },
    "log_stream_name": "default",
    "force_flush_interval": 15
  },
  "metrics": {
    "namespace": "MyApp/Custom",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent", "disk_free"],
        "resources": ["/", "/data"],
        "metrics_collection_interval": 60
      },
      "net": {
        "measurement": ["net_bytes_sent", "net_bytes_recv"],
        "metrics_collection_interval": 60
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  }
}
```

### CloudWatch Alarms

```yaml
# CloudWatch Alarms via Terraform
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "myapp-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5XX errors exceeded threshold"

  dimensions = {
    ApiName = "myapp-api"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "myapp-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 500  # 500ms
  alarm_description   = "API P99 latency exceeded 500ms"

  dimensions = {
    ApiName = "myapp-api"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

## Prometheus + Grafana Stack

### Prometheus Architecture

```yaml
# Prometheus deployment via Helm values
prometheus:
  server:
    retention: "15d"
    retentionSize: "50GB"

    persistentVolume:
      enabled: true
      size: 100Gi
      storageClass: gp3

    resources:
      requests:
        cpu: "500m"
        memory: "2Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"

    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    # Remote write for long-term storage
    remoteWrite:
      - url: "http://thanos-receive:19291/api/v1/receive"
        write_relabel_configs:
          - source_labels: [__name__]
            regex: "go_.*"
            action: drop

  alertmanager:
    enabled: true
    config:
      global:
        slack_api_url: "${SLACK_WEBHOOK_URL}"
        pagerduty_url: "https://events.pagerduty.com/v2/enqueue"

      route:
        group_by: ["alertname", "cluster", "service"]
        group_wait: 30s
        group_interval: 5m
        repeat_interval: 4h
        receiver: "default-receiver"
        routes:
          - match:
              severity: critical
            receiver: "pagerduty-critical"
            continue: true
          - match:
              severity: warning
            receiver: "slack-warnings"

      receivers:
        - name: "default-receiver"
          slack_configs:
            - channel: "#alerts"
              send_resolved: true

        - name: "pagerduty-critical"
          pagerduty_configs:
            - service_key: "${PAGERDUTY_SERVICE_KEY}"
              severity: critical

        - name: "slack-warnings"
          slack_configs:
            - channel: "#alerts-warnings"
              send_resolved: true
```

### Prometheus Rules

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
  namespace: monitoring
spec:
  groups:
    - name: myapp.rules
      interval: 30s
      rules:
        # High error rate
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            / sum(rate(http_requests_total[5m])) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value | humanizePercentage }} (>5%)"

        # High latency
        - alert: HighLatency
          expr: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
            ) > 0.5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High P99 latency"
            description: "P99 latency is {{ $value | humanizeDuration }}"

        # Pod restarts
        - alert: PodRestartingTooOften
          expr: |
            increase(kube_pod_container_status_restarts_total[1h]) > 3
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} restarting frequently"
            description: "Pod has restarted {{ $value }} times in the last hour"

        # Memory usage
        - alert: HighMemoryUsage
          expr: |
            container_memory_working_set_bytes
            / container_spec_memory_limit_bytes > 0.9
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage in {{ $labels.pod }}"
            description: "Memory usage is {{ $value | humanizePercentage }}"

        # Disk space
        - alert: LowDiskSpace
          expr: |
            (node_filesystem_avail_bytes{mountpoint="/"}
            / node_filesystem_size_bytes{mountpoint="/"}) < 0.15
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Low disk space on {{ $labels.instance }}"
            description: "Only {{ $value | humanizePercentage }} disk space remaining"

        # Database connections
        - alert: HighDatabaseConnections
          expr: |
            pg_stat_activity_count > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High database connections"
            description: "{{ $value }} active database connections"
```

### ServiceMonitor for Application

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-backend
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: backend
  namespaceSelector:
    matchNames:
      - production
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
      scheme: http
```

---

## OpenTelemetry Configuration

### OpenTelemetry Collector

```yaml
# otel-collector-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: monitoring
data:
  otel-collector-config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      prometheus:
        config:
          scrape_configs:
            - job_name: 'otel-collector'
              scrape_interval: 10s
              static_configs:
                - targets: ['localhost:8888']

      k8s_cluster:
        collection_interval: 10s

      k8s_events:
        namespaces: [production, staging]

    processors:
      batch:
        timeout: 10s
        send_batch_size: 1000

      memory_limiter:
        check_interval: 1s
        limit_mib: 1000
        spike_limit_mib: 200

      resource:
        attributes:
          - key: environment
            value: production
            action: upsert
          - key: service.namespace
            from_attribute: k8s.namespace.name
            action: upsert

      filter:
        traces:
          span:
            - 'attributes["http.target"] == "/health"'
            - 'attributes["http.target"] == "/ready"'

    exporters:
      otlp:
        endpoint: tempo:4317
        tls:
          insecure: true

      prometheus:
        endpoint: 0.0.0.0:8889
        namespace: otel
        send_timestamps: true

      loki:
        endpoint: http://loki:3100/loki/api/v1/push
        labels:
          attributes:
            severity: ""
            service.name: ""
          resource:
            k8s.namespace.name: "namespace"
            k8s.pod.name: "pod"

      awsxray:
        region: us-east-1

      awscloudwatchlogs:
        log_group_name: "/aws/otel/application"
        log_stream_name: "otel-stream"
        region: us-east-1

    extensions:
      health_check:
        endpoint: 0.0.0.0:13133
      zpages:
        endpoint: 0.0.0.0:55679

    service:
      extensions: [health_check, zpages]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource, filter]
          exporters: [otlp, awsxray]

        metrics:
          receivers: [otlp, prometheus, k8s_cluster]
          processors: [memory_limiter, batch, resource]
          exporters: [prometheus]

        logs:
          receivers: [otlp, k8s_events]
          processors: [memory_limiter, batch, resource]
          exporters: [loki, awscloudwatchlogs]
```

### Application Instrumentation (Node.js)

```javascript
// tracing.js
const { NodeSDK } = require("@opentelemetry/sdk-node");
const {
  getNodeAutoInstrumentations,
} = require("@opentelemetry/auto-instrumentations-node");
const {
  OTLPTraceExporter,
} = require("@opentelemetry/exporter-trace-otlp-grpc");
const {
  OTLPMetricExporter,
} = require("@opentelemetry/exporter-metrics-otlp-grpc");
const { PeriodicExportingMetricReader } = require("@opentelemetry/sdk-metrics");
const { Resource } = require("@opentelemetry/resources");
const {
  SemanticResourceAttributes,
} = require("@opentelemetry/semantic-conventions");

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: "myapp-backend",
    [SemanticResourceAttributes.SERVICE_VERSION]:
      process.env.APP_VERSION || "1.0.0",
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]:
      process.env.NODE_ENV || "development",
  }),

  traceExporter: new OTLPTraceExporter({
    url:
      process.env.OTEL_EXPORTER_OTLP_ENDPOINT || "http://otel-collector:4317",
  }),

  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url:
        process.env.OTEL_EXPORTER_OTLP_ENDPOINT || "http://otel-collector:4317",
    }),
    exportIntervalMillis: 60000,
  }),

  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-fs": { enabled: false },
      "@opentelemetry/instrumentation-http": {
        ignoreIncomingRequestHook: (request) => {
          return request.url === "/health" || request.url === "/ready";
        },
      },
    }),
  ],
});

sdk.start();

process.on("SIGTERM", () => {
  sdk
    .shutdown()
    .then(() => console.log("Tracing terminated"))
    .catch((error) => console.log("Error terminating tracing", error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
```

---

## Alerting Strategy

### Severity Levels (SEV)

| Severity            | Definition                                   | Response Time     | Examples                                       |
| ------------------- | -------------------------------------------- | ----------------- | ---------------------------------------------- |
| **SEV1 - Critical** | Service completely down, data loss imminent  | < 15 minutes      | Production outage, security breach             |
| **SEV2 - Major**    | Significant degradation, many users affected | < 30 minutes      | High error rate, critical feature broken       |
| **SEV3 - Minor**    | Limited impact, workaround available         | < 2 hours         | Single component failure, degraded performance |
| **SEV4 - Low**      | Minimal impact, informational                | Next business day | Warnings, capacity planning                    |

### Alert Routing

```yaml
# alertmanager-config.yaml
global:
  resolve_timeout: 5m
  slack_api_url: "${SLACK_WEBHOOK_URL}"
  pagerduty_url: "https://events.pagerduty.com/v2/enqueue"

route:
  receiver: "default"
  group_by: ["alertname", "severity", "service"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    # SEV1 - Critical: Page immediately
    - match:
        severity: critical
      receiver: "pagerduty-sev1"
      group_wait: 0s
      repeat_interval: 5m
      continue: true

    # SEV1 - Also notify Slack
    - match:
        severity: critical
      receiver: "slack-critical"
      continue: true

    # SEV2 - Major: Page during business hours
    - match:
        severity: warning
        business_critical: "true"
      receiver: "pagerduty-sev2"
      active_time_intervals:
        - business_hours
      continue: true

    # SEV3/4 - Minor/Low: Slack only
    - match_re:
        severity: (info|warning)
      receiver: "slack-warnings"

receivers:
  - name: "default"
    slack_configs:
      - channel: "#alerts-default"
        send_resolved: true

  - name: "pagerduty-sev1"
    pagerduty_configs:
      - service_key: "${PAGERDUTY_SEV1_KEY}"
        severity: critical
        description: "{{ .GroupLabels.alertname }}: {{ .Annotations.summary }}"
        details:
          firing: "{{ .Alerts.Firing | len }}"
          resolved: "{{ .Alerts.Resolved | len }}"

  - name: "pagerduty-sev2"
    pagerduty_configs:
      - service_key: "${PAGERDUTY_SEV2_KEY}"
        severity: error

  - name: "slack-critical"
    slack_configs:
      - channel: "#alerts-critical"
        color: "#FF0000"
        title: "🚨 CRITICAL: {{ .GroupLabels.alertname }}"
        text: "{{ .Annotations.description }}"
        send_resolved: true

  - name: "slack-warnings"
    slack_configs:
      - channel: "#alerts-warnings"
        color: "#FFA500"
        send_resolved: true

time_intervals:
  - name: business_hours
    time_intervals:
      - weekdays: ["monday:friday"]
        times:
          - start_time: "09:00"
            end_time: "18:00"
```

### Alert Templates

```yaml
# Alert template examples
templates:
  - 'slack.tmpl'

# slack.tmpl
{{ define "slack.title" }}
[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}
{{ end }}

{{ define "slack.text" }}
{{ range .Alerts }}
*Alert:* {{ .Annotations.summary }}
*Description:* {{ .Annotations.description }}
*Severity:* {{ .Labels.severity }}
*Service:* {{ .Labels.service }}
*Started:* {{ .StartsAt.Format "2006-01-02 15:04:05 UTC" }}
{{ if .EndsAt }}*Resolved:* {{ .EndsAt.Format "2006-01-02 15:04:05 UTC" }}{{ end }}
---
{{ end }}
{{ end }}
```

---

## Log Retention and Indexing Plan

### Retention Policy

| Log Type         | Hot Storage | Warm Storage | Cold Storage | Archive |
| ---------------- | ----------- | ------------ | ------------ | ------- |
| Application Logs | 7 days      | 30 days      | 90 days      | 1 year  |
| Security/Audit   | 30 days     | 90 days      | 1 year       | 7 years |
| Infrastructure   | 7 days      | 30 days      | 90 days      | Delete  |
| Debug Logs       | 3 days      | 7 days       | Delete       | Delete  |
| Access Logs      | 7 days      | 30 days      | 90 days      | 1 year  |

### CloudWatch Logs Lifecycle

```hcl
# Log group with retention
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/myapp/application"
  retention_in_days = 30

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

# Subscription filter to S3 for archival
resource "aws_cloudwatch_log_subscription_filter" "archive" {
  name            = "archive-to-s3"
  log_group_name  = aws_cloudwatch_log_group.application.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs.arn
  role_arn        = aws_iam_role.cloudwatch_logs.arn
}

# Firehose for S3 delivery
resource "aws_kinesis_firehose_delivery_stream" "logs" {
  name        = "logs-to-s3"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.logs_archive.arn
    prefix     = "logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size     = 128
    buffering_interval = 300

    compression_format = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/logs"
      log_stream_name = "delivery"
    }
  }
}

# S3 lifecycle for tiered storage
resource "aws_s3_bucket_lifecycle_configuration" "logs_archive" {
  bucket = aws_s3_bucket.logs_archive.id

  rule {
    id     = "archive-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}
```

### Log Indexing Strategy (Loki)

```yaml
# Loki configuration for efficient indexing
loki:
  config:
    schema_config:
      configs:
        - from: 2024-01-01
          store: boltdb-shipper
          object_store: s3
          schema: v12
          index:
            prefix: loki_index_
            period: 24h

    storage_config:
      boltdb_shipper:
        active_index_directory: /loki/index
        cache_location: /loki/cache
        shared_store: s3

      aws:
        s3: s3://loki-data-bucket
        region: us-east-1

    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      ingestion_rate_mb: 16
      ingestion_burst_size_mb: 32
      max_streams_per_user: 10000
      max_label_name_length: 1024
      max_label_value_length: 2048

    chunk_store_config:
      max_look_back_period: 0s

    table_manager:
      retention_deletes_enabled: true
      retention_period: 720h # 30 days
```

---

## Example Dashboards

### Application Overview Dashboard

```json
{
  "dashboard": {
    "title": "Application Overview",
    "panels": [
      {
        "title": "Request Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m]))",
            "legendFormat": "req/s"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "gauge",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100",
            "legendFormat": "Error %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                { "value": 0, "color": "green" },
                { "value": 1, "color": "yellow" },
                { "value": 5, "color": "red" }
              ]
            },
            "max": 100
          }
        }
      },
      {
        "title": "Latency (P50, P95, P99)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "P50"
          },
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "P95"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "P99"
          }
        ]
      },
      {
        "title": "Active Pods",
        "type": "stat",
        "targets": [
          {
            "expr": "count(kube_pod_status_ready{namespace=\"production\", condition=\"true\"})"
          }
        ]
      },
      {
        "title": "CPU Usage by Pod",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\"}[5m])) by (pod)",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Memory Usage by Pod",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(container_memory_working_set_bytes{namespace=\"production\"}) by (pod)",
            "legendFormat": "{{pod}}"
          }
        ]
      }
    ]
  }
}
```

### Infrastructure Dashboard

```json
{
  "dashboard": {
    "title": "Infrastructure Health",
    "panels": [
      {
        "title": "Node CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Node Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Disk Usage",
        "type": "gauge",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes{mountpoint=\"/\"} - node_filesystem_avail_bytes{mountpoint=\"/\"}) / node_filesystem_size_bytes{mountpoint=\"/\"} * 100",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Database Connections",
        "type": "stat",
        "targets": [
          {
            "expr": "pg_stat_activity_count"
          }
        ]
      },
      {
        "title": "Database Query Duration",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(pg_stat_statements_seconds_total[5m])",
            "legendFormat": "{{query}}"
          }
        ]
      },
      {
        "title": "Cache Hit Ratio",
        "type": "gauge",
        "targets": [
          {
            "expr": "redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total) * 100"
          }
        ]
      }
    ]
  }
}
```

---

## Summary

This observability strategy provides:

**Unified Data Collection**: OpenTelemetry for traces, metrics, and logs
**Multi-Backend Support**: Prometheus, Loki, Tempo, CloudWatch integration
**Intelligent Alerting**: Severity-based routing with PagerDuty and Slack
**Cost-Effective Storage**: Tiered retention with automatic archival
**Actionable Dashboards**: Role-specific views for different teams
**Compliance Ready**: Audit log retention meeting regulatory requirements
