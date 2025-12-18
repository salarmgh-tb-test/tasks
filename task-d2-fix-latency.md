# Task D2 - Fix Latency Issues

## Problem Statement

Given the following symptoms:

- API latency increased from 40ms → 800ms
- CPU/memory normal
- DB load high
- Cache hit ratio <10%
- 10% 5xx errors

Provide root cause analysis and remediation plan.

---

## Initial Assessment

### Symptom Analysis

| Symptom              | Observation       | Potential Cause                                 |
| -------------------- | ----------------- | ----------------------------------------------- |
| Latency 40ms → 800ms | 20x increase      | Query performance, external calls               |
| CPU/Memory normal    | Not compute-bound | I/O or waiting issue                            |
| DB load high         | High query volume | Missing indexes, unoptimized queries            |
| Cache hit ratio <10% | 90% cache misses  | Cache flush, expiration, eviction, invalidation |
| 10% 5xx errors       | Server errors     | Timeouts, connection exhaustion                 |

### Correlation

```
Low Cache Hit Ratio (<10%)
         ↓
More requests hit database (cache needs time to rebuild)
         ↓
DB becomes overloaded
         ↓
Slow queries + connection pool exhaustion
         ↓
Increased latency + 5xx errors
         ↓
Application goes down before cache can recover
```

**Critical Issue**: When cache hit ratio drops significantly (due to flush, expiration, eviction, or invalidation), the sudden increase in database load overwhelms the system before the cache can rebuild. This creates a cascading failure where:

1. Low cache hit ratio → High database load
2. High database load → Slow queries and connection exhaustion
3. Slow queries → Increased latency and 5xx errors
4. Application failure → Cache never gets a chance to rebuild

**Solution Strategy**: Start with throttling and circuit breakers to protect the system, allowing cache to rebuild gradually without overwhelming the database.

---

## Root Cause Analysis

### Step 1: Identify the Trigger

```bash
# Check when latency started increasing
# Query Prometheus/CloudWatch for the exact timeframe

# Prometheus query for latency spike
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# CloudWatch Logs Insights
fields @timestamp, @message
| filter @message like /slow query/
| sort @timestamp desc
| limit 100
```

### Step 2: Analyze Cache Performance

```bash
# Redis cache analysis
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"
# keyspace_hits:1000
# keyspace_misses:9000  → 10% hit ratio

# Check TTL settings
redis-cli DEBUG object mykey

# Check memory usage
redis-cli INFO memory
```

**Finding**: Cache miss ratio of 90% indicates:

1. Keys are expiring too quickly (TTL too short)
2. Cache was flushed (manual flush, restart, or memory pressure)
3. Keys are being evicted due to memory pressure
4. Cache keys changed (key format/version mismatch)
5. Cache invalidation (after deployment or data updates)

**Critical Recovery Issue**: When cache hit ratio drops to <10%, the system experiences a "thundering herd" effect where all requests hit the database simultaneously. The database becomes overloaded before the cache can rebuild, causing the application to fail. This is why throttling and circuit breakers must be implemented first to allow gradual cache recovery.

### Step 3: Analyze Database Performance

```sql
-- PostgreSQL: Find slow queries
SELECT
    query,
    calls,
    mean_time,
    total_time,
    rows
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 20;

-- Check for missing indexes
SELECT
    schemaname,
    tablename,
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE '%_pkey';

-- Check for sequential scans on large tables
SELECT
    relname,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC;

-- Check active connections
SELECT
    state,
    COUNT(*)
FROM pg_stat_activity
GROUP BY state;

-- Check for blocking queries
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

**Findings**:

1. Unoptimized queries - queries not using indexes, inefficient joins, or fetching unnecessary data
2. Missing indexes on frequently filtered columns
3. Connection pool exhaustion - all available database connections are in use

### Step 4: Trace Analysis

```bash
# Use Jaeger/Tempo to find slow traces
# Look for spans with high duration

# Example slow trace breakdown:
# Total: 800ms
# ├── API Handler: 5ms
# ├── Cache Lookup: 2ms (MISS)
# ├── DB Query 1: 150ms (slow - missing index or unoptimized)
# ├── DB Query 2-11: 500ms (multiple inefficient queries, 10 × 50ms each)
# ├── External API: 100ms
# └── Serialization: 43ms
```

---

## Root Causes Identified

| #   | Root Cause                   | Impact             | Evidence                                                           |
| --- | ---------------------------- | ------------------ | ------------------------------------------------------------------ |
| 1   | Low cache hit ratio (<10%)   | 90% cache misses   | Cache flush/expiration/invalidation causes all requests to hit DB  |
| 2   | Unoptimized database queries | 500ms+ per request | Queries not using indexes, inefficient joins, multiple round trips |
| 3   | Missing database indexes     | 150ms+ query time  | Sequential scans on large tables                                   |
| 4   | Connection pool exhaustion   | 5xx errors         | All database connections in use, new requests cannot connect       |

---

## Remediation Plan

This remediation plan follows a systematic approach to reduce load, identify bottlenecks, scale appropriately, and optimize based on data-driven insights.

### Phase 1: Immediate Load Reduction

**Goal**: Protect the application from cascading failures by reducing incoming load and implementing protective mechanisms. This is critical when cache hit ratio is low, as it prevents the database from being overwhelmed while the cache rebuilds.

#### 1. Implement Throttling and Rate Limiting

Throttle incoming requests to prevent overwhelming the system while maintaining service availability. This allows the cache to rebuild gradually without causing database overload.

##### 1.1 Application-Level Throttling

Implement rate limiting at the application level to control request throughput. Configure limits based on:

- Endpoint type (read vs write)
- User/IP address
- Request complexity
- Current system load

Use rate limiting libraries appropriate for your application framework (e.g., express-rate-limit for Node.js, django-ratelimit for Python, etc.).

##### 1.2 AWS ALB Rate Limiting (WAF)

```hcl
# Terraform: AWS WAF rate-based rule
resource "aws_wafv2_web_acl" "api" {
  name  = "api-rate-limit"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 2000  # Requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "api-waf"
    sampled_requests_enabled   = true
  }
}

# Attach to ALB
resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_lb.api.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
```

##### 1.3 Kubernetes Ingress Rate Limiting (NGINX)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-api-ingress
  annotations:
    # NGINX rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-connections: "50"
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8" # Whitelist internal IPs

    # Per-endpoint rate limiting
    nginx.ingress.kubernetes.io/server-snippet: |
      location /api/products {
        limit_req zone=api burst=20 nodelay;
      }
```

#### 2. Implement Circuit Breaker

Implement circuit breakers at multiple layers to prevent cascading failures and protect downstream services.

##### 2.1 Application-Level Circuit Breaker

Implement circuit breakers at the application level for critical operations (database queries, external API calls). Configure:

- **Timeout**: Maximum time to wait for operation (e.g., 3 seconds)
- **Error threshold**: Percentage of failures before opening circuit (e.g., 50%)
- **Reset timeout**: Time before attempting to close circuit (e.g., 30 seconds)
- **Fallback**: Return cached data or default response when circuit is open

Use appropriate circuit breaker libraries for your application framework (e.g., opossum for Node.js, resilience4j for Java, etc.).

##### 2.2 AWS Load Balancer Circuit Breaker (ALB/NLB)

Configure AWS Application Load Balancer or Network Load Balancer with health checks and target group settings to act as a circuit breaker.

**Terraform Configuration:**

```hcl
# ALB Target Group with health checks
resource "aws_lb_target_group" "backend" {
  name     = "backend-api-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2   # 2 consecutive successes to mark healthy
    unhealthy_threshold = 3   # 3 consecutive failures to mark unhealthy
    timeout             = 5   # 5 second timeout
    interval            = 30  # Check every 30 seconds
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Deregistration delay - time to wait before removing unhealthy targets
  deregistration_delay = 30

  # Connection draining timeout
  connection_termination = true

  tags = {
    Name = "backend-api-target-group"
  }
}

# ALB Listener Rule with slow start (gradual traffic increase)
resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn

    # Slow start - gradually increase traffic to newly healthy targets
    forward {
      target_group {
        arn             = aws_lb_target_group.backend.arn
        weight          = 100
      }
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# CloudWatch Alarms for target group health
resource "aws_cloudwatch_metric_alarm" "target_group_unhealthy" {
  alarm_name          = "backend-tg-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "Alert when unhealthy targets exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
```

**ALB Annotations for Kubernetes Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-api-ingress
  annotations:
    # AWS Load Balancer Controller annotations
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-type: application

    # Health check configuration
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "3"
    alb.ingress.kubernetes.io/success-codes: "200"

    # Circuit breaker behavior
    alb.ingress.kubernetes.io/target-group-attributes: |
      deregistration_delay.timeout_seconds=30,
      slow_start.duration_seconds=60,
      stickiness.enabled=true,
      stickiness.lb_cookie.duration_seconds=86400

    # Connection draining
    alb.ingress.kubernetes.io/target-group-attributes: |
      deregistration_delay.connection_termination.enabled=true,
      deregistration_delay.timeout_seconds=30

    # Load balancing algorithm
    alb.ingress.kubernetes.io/load-balancer-algorithm: least_outstanding_requests

    # SSL/TLS
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
spec:
  ingressClassName: alb
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-api
                port:
                  number: 80
```

##### 2.3 Ingress-Level Circuit Breaker (AWS Load Balancer Controller)

Use AWS Load Balancer Controller annotations to configure circuit breaker behavior at the ingress level.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-api-ingress
  namespace: tradebytes
  annotations:
    # Basic ALB configuration
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-type: application

    # Health check - acts as circuit breaker trigger
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "3"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "5"
    alb.ingress.kubernetes.io/success-codes: "200,204"

    # Target group attributes for circuit breaker behavior
    alb.ingress.kubernetes.io/target-group-attributes: |
      deregistration_delay.timeout_seconds=10,
      deregistration_delay.connection_termination.enabled=true,
      slow_start.duration_seconds=30,
      load_balancing.algorithm.type=least_outstanding_requests,
      stickiness.enabled=false

    # WAF integration for additional protection
    alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:region:account:webacl/name/id

    # Rate limiting (additional protection layer)
    alb.ingress.kubernetes.io/load-balancer-attributes: |
      idle_timeout.timeout_seconds=60,
      routing.http.drop_invalid_header_fields.enabled=true,
      routing.http.x_amzn_tls_version_and_cipher_suite.enabled=true,
      routing.http.xff_client_port.enabled=true

    # SSL redirect
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'

    # Certificate
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id

    # Tags for cost allocation
    alb.ingress.kubernetes.io/tags: Environment=staging,ManagedBy=terraform
spec:
  ingressClassName: alb
  rules:
    - host: api.staging.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-api
                port:
                  number: 8080
          - path: /health
            pathType: Exact
            backend:
              service:
                name: backend-api
                port:
                  number: 8080
---
# Service with proper readiness/liveness probes
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: tradebytes
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  selector:
    app: backend-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: backend
          image: backend:latest
          ports:
            - containerPort: 8080
          # Readiness probe - determines if pod can receive traffic
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 3 # Mark unhealthy after 3 failures

          # Liveness probe - determines if pod should be restarted
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 3
```

##### 2.4 Service Mesh Circuit Breaker (Istio)

Use Istio service mesh for advanced circuit breaking with fine-grained control.

**Install Istio:**

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*

# Install Istio with default profile
istioctl install --set values.defaultRevision=default

# Enable automatic sidecar injection
kubectl label namespace tradebytes istio-injection=enabled
```

**VirtualService with Circuit Breaker:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-api
  namespace: tradebytes
spec:
  hosts:
    - backend-api
  http:
    - match:
        - uri:
            prefix: "/api"
      route:
        - destination:
            host: backend-api
            subset: v1
          weight: 100
      # Circuit breaker configuration
      fault:
        # Simulate failures for testing
        abort:
          percentage:
            value: 0
          httpStatus: 503
      # Retry policy
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,gateway-error,connect-failure,refused-stream
      # Timeout
      timeout: 10s
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-api
  namespace: tradebytes
spec:
  host: backend-api
  subsets:
    - name: v1
      labels:
        version: v1
  # Circuit breaker configuration
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 30s
      http:
        http1MaxPendingRequests: 10
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
        maxRetries: 3
        idleTimeout: 90s
        h2UpgradePolicy: UPGRADE

    # Outlier detection (circuit breaker)
    outlierDetection:
      consecutive5xxErrors: 5 # Open circuit after 5 consecutive 5xx errors
      interval: 30s # Check every 30 seconds
      baseEjectionTime: 30s # Eject for 30 seconds initially
      maxEjectionPercent: 50 # Max 50% of hosts can be ejected
      minHealthPercent: 50 # Keep at least 50% healthy
      splitExternalLocalOriginErrors: true
      # Ejection time increases exponentially
      # 30s, 60s, 120s, 240s, etc.

    # Load balancing
    loadBalancer:
      simple: LEAST_CONN
      consistentHash:
        httpHeaderName: "x-user-id"

    # TLS
    tls:
      mode: ISTIO_MUTUAL
      sni: backend-api.tradebytes.svc.cluster.local
```

**Service Mesh Circuit Breaker Monitoring:**

```yaml
# Prometheus metrics exposed by Istio
# istio_requests_total - Total requests
# istio_request_duration_seconds - Request duration
# istio_request_bytes - Request size
# istio_response_bytes - Response size
# istio_tcp_sent_bytes_total - TCP bytes sent
# istio_tcp_received_bytes_total - TCP bytes received
# istio_tcp_connections_opened_total - TCP connections opened
# istio_tcp_connections_closed_total - TCP connections closed

# Grafana dashboard query for circuit breaker status
# Percentage of requests failing
sum(rate(istio_requests_total{
  destination_service_name="backend-api",
  response_code=~"5.."
}[5m])) / sum(rate(istio_requests_total{
  destination_service_name="backend-api"
}[5m])) * 100

# Active circuit breakers (outlier detection ejections)
sum(istio_cluster_outlier_detection_ejections_active{
  destination_service_name="backend-api"
})
```

**Comparison of Circuit Breaker Methods:**

| Method                       | Layer              | Granularity        | Configuration     | Best For                               |
| ---------------------------- | ------------------ | ------------------ | ----------------- | -------------------------------------- |
| **Application**              | Code               | Per function/query | Code/Config       | Fine-grained control, custom logic     |
| **AWS ALB/NLB**              | Load Balancer      | Per target group   | Terraform/Console | AWS-native, simple setup               |
| **Ingress (ALB Controller)** | Kubernetes Ingress | Per service        | Annotations       | Kubernetes-native, ALB integration     |
| **Service Mesh (Istio)**     | Service Mesh       | Per service/route  | CRDs              | Advanced features, mTLS, observability |
| **Service Mesh (Linkerd)**   | Service Mesh       | Per service        | CRDs              | Simpler than Istio, good defaults      |

**Recommended Multi-Layer Approach:**

1. **Service Mesh (Istio/Linkerd)** - Primary circuit breaker for inter-service communication
2. **AWS ALB** - Secondary protection at load balancer level
3. **Application Level** - Fine-grained control for critical operations (DB queries, external APIs)

This provides defense in depth with circuit breakers at multiple layers.

---

### Phase 2: Identify Bottleneck (Application vs Database)

**Goal**: Determine whether the bottleneck is in the application layer or database layer to guide scaling and optimization efforts.

#### 1. Service-Level Metrics Analysis

Analyze metrics per service to identify where time is being spent.

##### 1.1 Application Metrics

```bash
# Prometheus queries for application performance
# Average request duration by service
sum(rate(http_request_duration_seconds_sum[5m])) by (service) /
sum(rate(http_request_duration_seconds_count[5m])) by (service)

# Request rate by service
sum(rate(http_requests_total[5m])) by (service)

# Error rate by service
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) /
sum(rate(http_requests_total[5m])) by (service) * 100

# CPU utilization by service
avg(container_cpu_usage_seconds_total{service=~".+"}) by (service)

# Memory utilization by service
avg(container_memory_working_set_bytes{service=~".+"}) by (service)
```

##### 1.2 Database Metrics

```bash
# Database connection pool utilization
sum(pg_stat_database_numbackends) by (datname)

# Active queries by database
sum(pg_stat_activity_count{state="active"}) by (datname)

# Database CPU utilization (from CloudWatch/RDS)
avg(aws_rds_cpu_utilization{dbinstance_identifier=~".+"}) by (dbinstance_identifier)

# Database I/O wait time
avg(aws_rds_read_latency{dbinstance_identifier=~".+"}) by (dbinstance_identifier)
avg(aws_rds_write_latency{dbinstance_identifier=~".+"}) by (dbinstance_identifier)

# Slow query count
sum(pg_stat_statements_calls{mean_exec_time > 1000}) by (query)
```

##### 1.3 Distributed Tracing Analysis

```bash
# Using Jaeger/Tempo to identify bottlenecks
# Find traces with high duration
# Filter by service and analyze span breakdown

# Example trace breakdown analysis:
# - If DB query time > 50% of total time → Database bottleneck
# - If Application processing time > 50% → Application bottleneck
# - If External API calls > 50% → External dependency bottleneck
```

#### 2. Bottleneck Identification Decision Tree

```
High Latency Detected
    │
    ├─→ Check Application CPU/Memory
    │   ├─→ High CPU (>80%) → Application bottleneck (compute-bound)
    │   └─→ Normal CPU → Check I/O wait
    │       ├─→ High I/O wait → Check database
    │       └─→ Low I/O wait → Check external dependencies
    │
    └─→ Check Database Metrics
        ├─→ High connection count → Connection pool exhaustion (may need to increase database max_connections)
        ├─→ High CPU (>80%) → Database bottleneck (compute-bound)
        ├─→ High I/O wait → Database bottleneck (I/O-bound)
        └─→ Slow queries → Query optimization needed
```

#### 3. Service-Specific Analysis

```bash
# Analyze each service independently
# Example: User service vs Product service vs Order service

# User Service Analysis
sum(rate(http_request_duration_seconds_sum{service="user-service"}[5m])) /
sum(rate(http_request_duration_seconds_count{service="user-service"}[5m]))

# Product Service Analysis
sum(rate(http_request_duration_seconds_sum{service="product-service"}[5m])) /
sum(rate(http_request_duration_seconds_count{service="product-service"}[5m]))

# Order Service Analysis
sum(rate(http_request_duration_seconds_sum{service="order-service"}[5m])) /
sum(rate(http_request_duration_seconds_count{service="order-service"}[5m]))
```

**Decision Criteria:**

- **Application Bottleneck**: High CPU/memory usage, slow processing logic, high request queue
- **Database Bottleneck**: High DB CPU, connection pool exhaustion, slow queries, high I/O wait
- **Mixed Bottleneck**: Both application and database showing stress

---

### Phase 3: Apply Auto-Scaling

**Goal**: Scale resources dynamically based on load, using different strategies for stateless (application) vs stateful (database) services.

#### 1. Application Auto-Scaling (Stateless Services)

Stateless services can scale horizontally by adding more replicas.

##### 1.1 Kubernetes Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-api-hpa
  namespace: tradebytes
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
    # CPU-based scaling
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    # Memory-based scaling
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

    # Custom metric: Request rate
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"

    # Custom metric: Request latency
    - type: Pods
      pods:
        metric:
          name: http_request_duration_seconds
        target:
          type: AverageValue
          averageValue: "0.5" # 500ms
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300 # Wait 5 min before scaling down
      policies:
        - type: Percent
          value: 50 # Scale down by 50% at a time
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0 # Scale up immediately
      policies:
        - type: Percent
          value: 100 # Double replicas if needed
          periodSeconds: 30
        - type: Pods
          value: 4 # Or add 4 pods at a time
          periodSeconds: 30
      selectPolicy: Max # Use the policy that scales more
```

##### 1.2 Kubernetes Vertical Pod Autoscaler (VPA) - Optional

For fine-tuning resource requests/limits:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: backend-api-vpa
  namespace: tradebytes
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-api
  updatePolicy:
    updateMode: "Auto" # Or "Off" for recommendations only
  resourcePolicy:
    containerPolicies:
      - containerName: backend
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2
          memory: 4Gi
        controlledResources: ["cpu", "memory"]
```

##### 1.3 Cluster Autoscaler (EKS Node Scaling)

```yaml
# Cluster Autoscaler deployment (already configured in platform stack)
# Scales node groups based on pod scheduling needs

# Node group configuration in Terraform
# terraform/stacks/platform/variables.tf
variable "node_groups" {
description = "EKS node group configurations"
type = map(object({
instance_types = list(string)
min_size       = number
max_size       = number
desired_size   = number
disk_size      = number
}))
default = {
general = {
instance_types = ["t3.medium", "t3.large"]
min_size       = 2
max_size       = 10
desired_size   = 3
disk_size      = 50
}
}
}
```

#### 2. Stateful Service Load Distribution

For stateful services (databases, caches), use read replicas and connection pooling instead of horizontal scaling.

##### 2.1 Database Read Replicas

```hcl
# Terraform: RDS Read Replica
resource "aws_db_instance" "read_replica" {
  identifier              = "${var.project}-${var.environment}-rds-replica"
  replicate_source_db     = aws_db_instance.main.identifier
  instance_class          = var.db_instance_class
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7

  tags = {
    Name        = "${var.project}-${var.environment}-rds-replica"
    Environment = var.environment
  }
}
```

##### 2.2 Application-Level Read/Write Splitting

Implement read/write splitting at the application level:

- **Write pool**: Connect to primary database for all write operations (INSERT, UPDATE, DELETE)
- **Read pool**: Connect to read replicas for SELECT queries
- **Query router**: Route queries to appropriate pool based on operation type
- **Connection pool sizing**: Larger pool for reads (e.g., 50 connections) vs writes (e.g., 20 connections)

Configure connection pools with appropriate timeouts and connection limits based on database capacity.

##### 2.3 Redis Cluster Mode (for caching)

```yaml
# Redis Cluster for horizontal scaling
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-cluster-config
data:
  redis.conf: |
    cluster-enabled yes
    cluster-config-file nodes.conf
    cluster-node-timeout 5000
    appendonly yes
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
spec:
  serviceName: redis-cluster
  replicas: 6 # 3 masters + 3 replicas
  template:
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
            - containerPort: 16379 # Cluster bus port
          volumeMounts:
            - name: redis-data
              mountPath: /data
  volumeClaimTemplates:
    - metadata:
        name: redis-data
      spec:
        accessModes: ["ReadWriteOnce"]
          resources:
            requests:
            storage: 10Gi
```

#### 3. Service-Specific Scaling Strategy

Based on bottleneck analysis, apply different scaling strategies:

```yaml
# High-traffic stateless service (e.g., API gateway)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  minReplicas: 5
  maxReplicas: 50
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 60 # Scale earlier
---
# CPU-intensive stateless service (e.g., image processing)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: image-processor-hpa
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 80 # Higher threshold
---
# Memory-intensive stateless service
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: data-processor-hpa
spec:
  minReplicas: 2
  maxReplicas: 15
  metrics:
    - type: Resource
      resource:
        name: memory
        target:
          averageUtilization: 75
```

---

### Phase 4: Identify Most Hit APIs from Logs (1-2 hours)

**Goal**: Analyze access logs to identify the most frequently hit endpoints for targeted caching and optimization.

#### 1. Log Analysis Methods

##### 1.1 CloudWatch Logs Insights

```sql
-- Find most hit endpoints in last hour
fields @timestamp, @message
| parse @message /(?<method>\w+)\s+(?<path>\/[^\s]*)\s+HTTP/
| stats count() as request_count by path, method
| sort request_count desc
| limit 20

-- Find endpoints with highest latency
fields @timestamp, @message, @duration
| parse @message /(?<method>\w+)\s+(?<path>\/[^\s]*)\s+HTTP.*duration=(?<duration>\d+)/
| stats avg(duration) as avg_duration, count() as request_count by path
| sort avg_duration desc
| limit 20

-- Find endpoints with highest error rate
fields @timestamp, @message
| parse @message /(?<method>\w+)\s+(?<path>\/[^\s]*)\s+HTTP.*status=(?<status>\d+)/
| filter status >= 500
| stats count() as error_count by path
| sort error_count desc
| limit 20
```

##### 1.2 Application Log Analysis (Structured Logs)

```bash
# Using jq to parse JSON logs
cat app.log | jq -r '[.path, .method, .status_code, .duration_ms] | @csv' | \
  awk -F',' '{print $1","$2","$3","$4}' | \
  sort | uniq -c | sort -rn | head -20

# Using fluentd/fluent-bit to aggregate
# Example fluentd config
<source>
  @type tail
  path /var/log/app/access.log
  pos_file /var/log/fluentd-access.log.pos
  tag app.access
  format json
</source>

<filter app.access>
  @type record_transformer
  <record>
    endpoint "${record['path']}"
    method "${record['method']}"
  </record>
</filter>

<match app.access>
  @type prometheus
  <metric>
    name http_requests_total
    type counter
    desc Total HTTP requests
    <labels>
      endpoint ${endpoint}
      method ${method}
      status ${status_code}
    </labels>
  </metric>
</match>
```

##### 1.3 Prometheus Metrics Analysis

```promql
# Top 10 endpoints by request rate
topk(10, sum(rate(http_requests_total[5m])) by (endpoint))

# Top 10 endpoints by total requests (last hour)
topk(10, sum(increase(http_requests_total[1h])) by (endpoint))

# Top 10 endpoints by average latency
topk(10,
  sum(rate(http_request_duration_seconds_sum[5m])) by (endpoint) /
  sum(rate(http_request_duration_seconds_count[5m])) by (endpoint)
)

# Endpoints with highest error rate
topk(10,
  sum(rate(http_requests_total{status=~"5.."}[5m])) by (endpoint) /
  sum(rate(http_requests_total[5m])) by (endpoint) * 100
)
```

##### 1.4 Access Log Aggregation Script

```bash
#!/bin/bash
# analyze_top_endpoints.sh

# Analyze NGINX/ALB access logs
LOG_FILE="${1:-/var/log/nginx/access.log}"

echo "=== Top 20 Most Hit Endpoints ==="
awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -20

echo -e "\n=== Top 20 Endpoints by Total Response Time ==="
awk '{total[$7] += $10; count[$7]++} END {
  for (endpoint in total) {
    avg = total[endpoint] / count[endpoint]
    print avg, count[endpoint], endpoint
  }
}' "$LOG_FILE" | sort -rn | head -20

echo -e "\n=== Top 20 Endpoints by Error Rate ==="
awk '$9 >= 500 {errors[$7]++} {total[$7]++} END {
  for (endpoint in total) {
    rate = (errors[endpoint] / total[endpoint]) * 100
    print rate"%", errors[endpoint], total[endpoint], endpoint
  }
}' "$LOG_FILE" | sort -rn | head -20
```

#### 2. Create API Hit Rate Dashboard

```yaml
# Grafana dashboard JSON snippet
{
  "panels":
    [
      {
        "title": "Top 10 Endpoints by Request Rate",
        "targets":
          [
            {
              "expr": "topk(10, sum(rate(http_requests_total[5m])) by (endpoint))",
              "legendFormat": "{{endpoint}}",
            },
          ],
      },
      {
        "title": "Top 10 Endpoints by Average Latency",
        "targets":
          [
            {
              "expr": "topk(10, sum(rate(http_request_duration_seconds_sum[5m])) by (endpoint) / sum(rate(http_request_duration_seconds_count[5m])) by (endpoint))",
              "legendFormat": "{{endpoint}}",
            },
          ],
      },
    ],
}
```

#### 3. Generate API Hit Report

Create a script or automated process to generate API hit reports from collected metrics:

- Query metrics storage (Redis, Prometheus, CloudWatch) for endpoint hit counts
- Aggregate and sort endpoints by request count
- Generate reports showing top N endpoints by:
  - Total request count
  - Average latency
  - Error rate
  - Cache hit/miss ratio

Use this data to prioritize which endpoints to cache and optimize.

---

### Phase 5: Cache Top Endpoints

**Goal**: Implement caching for the most frequently hit endpoints to reduce database load and improve response times.

#### 1. Identify Cacheable Endpoints

Based on Phase 4 analysis, categorize endpoints:

- **Highly cacheable**: GET /api/products, GET /api/categories (public data, rarely changes)
- **Moderately cacheable**: GET /api/user/profile (user-specific, changes occasionally)
- **Not cacheable**: POST /api/orders, PUT /api/user (mutations, user-specific writes)

#### 2. Implement Multi-Layer Caching Strategy

##### 2.1 Application-Level Cache (Redis)

Implement application-level caching using Redis or similar cache store:

**Cache Key Strategy:**

- Include endpoint path, query parameters, and user ID (for user-specific endpoints)
- Hash query parameters to create consistent cache keys
- Use hierarchical key structure: `cache:{endpoint}:{user_id}:{param_hash}`

**TTL Configuration:**

- Configure TTL per endpoint type:
  - Public data (products, categories): 1-2 hours
  - User-specific data: 5-10 minutes
  - Search results: 10-30 minutes
  - Default: 5 minutes

**Cache Middleware:**

- Intercept GET requests for cacheable endpoints
- Check cache before executing handler
- Store response in cache after successful handler execution
- Add cache headers (X-Cache: HIT/MISS) for monitoring
- Track cache hit/miss metrics per endpoint

**Cache Patterns:**

- Cache-aside: Application checks cache, fetches from DB on miss, stores in cache
- Stale-while-revalidate: Return stale data immediately, refresh in background

##### 2.2 HTTP Reverse Proxy Cache (CloudFront/Varnish/Nginx)

Add a caching layer in front of the application to cache HTTP responses and reduce load on backend services.

**Option A: AWS CloudFront (Recommended for AWS)**

```hcl
# Terraform: CloudFront distribution
resource "aws_cloudfront_distribution" "api" {
  origin {
    domain_name = aws_lb.api.dns_name
    origin_id   = "api-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "API CloudFront Distribution"
  default_root_object = ""

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "api-alb"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "X-User-ID"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600  # 1 hour
    max_ttl                = 86400 # 24 hours
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache API responses with appropriate TTLs for top endpoints
  ordered_cache_behavior {
    path_pattern     = "/api/products/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "api-alb"

    forwarded_values {
      query_string = true
      headers      = ["Authorization"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 300   # 5 minutes
    default_ttl = 600   # 10 minutes
    max_ttl     = 3600  # 1 hour
    compress    = true
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate.api.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}
```

**Option B: NGINX Cache (Kubernetes Ingress)**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-cache-config
data:
  nginx.conf: |
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m use_temp_path=off;

    server {
      location /api/products {
        proxy_cache api_cache;
        proxy_cache_valid 200 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_background_update on;
        add_header X-Cache-Status $upstream_cache_status;
      }
    }
```

##### 2.3 Cache Warming for Top Endpoints

Implement cache warming for top endpoints identified in Phase 4:

**Warming Strategy:**

- Create a script or scheduled job to pre-populate cache
- Fetch data for top N endpoints and their common parameter combinations
- Store responses in cache with appropriate TTLs
- Run warming:
  - After deployments (to rebuild cache quickly)
  - Periodically (e.g., every 6 hours via CronJob)
  - Before expected traffic spikes

**Top Endpoints to Warm:**

- Most frequently hit endpoints (from Phase 4 analysis)
- Common query parameter combinations
- Public data endpoints (products, categories)
- Search endpoints with popular queries

#### 3. Cache Invalidation Strategy

Implement cache invalidation at the application level when data is updated:

**Invalidation Patterns:**

- **Product updates**: Invalidate product-specific cache keys and related category/product list caches
- **User updates**: Invalidate user-specific cache keys (profile, preferences, etc.)
- **Category updates**: Invalidate category cache and related product listing caches

**Invalidation Methods:**

- Pattern-based deletion: Delete all cache keys matching a pattern (e.g., `cache:/api/products/*`)
- Tag-based invalidation: Use cache tags to group related cache entries for efficient invalidation
- TTL-based expiration: Let cache expire naturally for less critical data

**Implementation:**

- Trigger invalidation in update handlers (PUT, POST, DELETE operations)
- Use background jobs for bulk invalidations to avoid blocking requests
- Monitor invalidation performance to ensure it doesn't impact response times

---

### Phase 6: Database Analysis and Optimization (1-4 weeks)

**Goal**: Optimize database performance through query analysis, indexing, and architectural improvements.

#### 1. Connection Pool Optimization

##### 1.1 Analyze Connection Usage

```sql
-- Check active connections by state
SELECT
    state,
    COUNT(*) as connection_count,
    MAX(now() - state_change) as max_idle_time
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state;

-- Find long-running queries
SELECT
    pid,
    now() - query_start as duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
AND now() - query_start > interval '5 minutes'
ORDER BY duration DESC;

-- Check for connection pool exhaustion
SELECT
    setting as max_connections,
    (SELECT count(*) FROM pg_stat_activity) as current_connections,
    setting::int - (SELECT count(*) FROM pg_stat_activity) as available_connections
FROM pg_settings
WHERE name = 'max_connections';
```

##### 1.2 Optimize Connection Pool Settings

**Application-Level Configuration:**

- **Pool size calculation**: `(max_connections - 10) / num_app_instances`
  - Reserve 10 connections for admin/maintenance operations
  - Distribute remaining connections across application instances
- **Connection timeouts**: Configure appropriate timeouts for connection acquisition and query execution
- **Idle timeout**: Close idle connections after a period of inactivity
- **Connection retry**: Implement retry logic for failed connections

**Database-Level Configuration:**

- **Increase max_connections**: If connection pool exhaustion is due to insufficient database connections, increase `max_connections` parameter
- **Monitor connection usage**: Track active vs idle connections to determine optimal pool size
- **Connection limits per user**: Set appropriate connection limits per database user

**Monitoring:**

- Track pool metrics: total connections, idle connections, waiting requests
- Alert on connection pool exhaustion
- Monitor connection wait times

#### 2. Query Performance Analysis

##### 2.1 Identify Slow Queries

```sql
-- PostgreSQL: Find slow queries using pg_stat_statements
SELECT
    query,
    calls,
    mean_exec_time,
    total_exec_time,
    (total_exec_time / calls) as avg_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
WHERE mean_exec_time > 100  -- Queries taking more than 100ms on average
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Find queries with high execution count (potential N+1)
SELECT
    query,
    calls,
    mean_exec_time,
    total_exec_time
FROM pg_stat_statements
WHERE calls > 1000
ORDER BY calls DESC
LIMIT 20;

-- Find queries with low cache hit ratio
SELECT
    query,
    calls,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_statements
WHERE shared_blks_read > 1000
ORDER BY shared_blks_read DESC
LIMIT 20;
```

##### 2.2 Analyze Query Execution Plans

```sql
-- Enable query plan logging for slow queries
ALTER DATABASE mydb SET log_min_duration_statement = 1000; -- Log queries > 1s

-- Analyze specific query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM orders
WHERE user_id = 123
AND created_at > '2024-01-01'
ORDER BY created_at DESC
LIMIT 20;

-- Check for sequential scans on large tables
SELECT
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    seq_tup_read / seq_scan AS avg_seq_read
FROM pg_stat_user_tables
WHERE seq_scan > 0
AND seq_tup_read > 10000
ORDER BY seq_tup_read DESC;
```

#### 3. Index Optimization

##### 3.1 Identify Missing Indexes

```sql
-- Find tables with high sequential scans but low index usage
SELECT
    schemaname,
    tablename,
    seq_scan,
    idx_scan,
    CASE
        WHEN seq_scan = 0 THEN 0
        ELSE (idx_scan::float / (seq_scan + idx_scan)) * 100
    END AS index_usage_ratio
FROM pg_stat_user_tables
WHERE seq_scan + idx_scan > 0
ORDER BY seq_scan DESC
LIMIT 20;

-- Find unused indexes (waste space and slow writes)
SELECT
    schemaname,
    tablename,
    indexrelname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;
```

##### 3.2 Create Optimized Indexes

```sql
-- Add composite indexes for common query patterns
CREATE INDEX CONCURRENTLY idx_orders_user_created
ON orders(user_id, created_at DESC);

-- Add partial index for frequently filtered data
CREATE INDEX CONCURRENTLY idx_orders_active
ON orders(user_id, created_at DESC)
WHERE status = 'active';

-- Add covering index (includes frequently selected columns)
CREATE INDEX CONCURRENTLY idx_products_category_covering
ON products(category_id)
INCLUDE (name, price, image_url);

-- Add GIN index for full-text search
CREATE INDEX CONCURRENTLY idx_products_search
ON products USING GIN(to_tsvector('english', name || ' ' || description));

-- Add BRIN index for large tables with sequential data
CREATE INDEX CONCURRENTLY idx_orders_created_brin
ON orders USING BRIN(created_at);
```

#### 4. Fix N+1 Query Problems

##### 4.1 Identify N+1 Patterns

```sql
-- Find queries executed many times with similar patterns
SELECT
    LEFT(query, 100) as query_pattern,
    COUNT(*) as execution_count,
    AVG(mean_exec_time) as avg_time
FROM pg_stat_statements
WHERE query LIKE '%WHERE id =%'
GROUP BY LEFT(query, 100)
HAVING COUNT(*) > 100
ORDER BY execution_count DESC;
```

##### 4.2 Optimize with JOINs and Batch Loading

**Optimization Strategies:**

1. **Use JOINs**: Combine multiple queries into a single query using JOINs to fetch related data in one round trip
2. **Batch Loading**: Instead of fetching related data one record at a time, batch multiple IDs and fetch them together
3. **Eager Loading**: Load all required data upfront rather than lazy loading on demand
4. **Query Batching**: Group multiple queries and execute them together

**Example Pattern:**

- **Before**: Execute one query per order to fetch user data (N queries for N orders)
- **After**: Use JOIN to fetch orders with user data in a single query, or batch load all user IDs and fetch users in one query

Implement these patterns at the application level using your ORM or database query builder.

#### 5. Database Schema Optimization

##### Vacuum and Analyze Optimization

```sql
-- Configure automatic vacuum for high-update tables
ALTER TABLE orders SET (
    autovacuum_vacuum_threshold = 100,
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_threshold = 50,
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_vacuum_cost_delay = 10,
    autovacuum_vacuum_cost_limit = 200
);

-- Manual vacuum for critical tables
VACUUM ANALYZE orders;

-- Check table bloat
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_dead_tup,
    n_live_tup,
    CASE
        WHEN n_live_tup > 0
        THEN round(100.0 * n_dead_tup / n_live_tup, 2)
        ELSE 0
    END AS dead_tuple_percent
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```
