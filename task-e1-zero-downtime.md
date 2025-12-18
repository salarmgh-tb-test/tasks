# Task E1 - Design a Zero-Downtime Deployment Strategy

## Problem Statement

Document deployment options (Blue/Green, Canary, Rolling, A/B, traffic splitting via ALB/Route53) and select one with justification for a microservice architecture.

---

## Deployment Strategies Overview

### Comparison Matrix

| Strategy        | Downtime | Risk     | Resource Cost | Rollback Speed | Complexity |
| --------------- | -------- | -------- | ------------- | -------------- | ---------- |
| **Rolling**     | None     | Medium   | Low (1.25x)   | Medium         | Low        |
| **Blue/Green**  | None     | Low      | High (2x)     | Fast           | Medium     |
| **Canary**      | None     | Very Low | Medium (1.1x) | Fast           | High       |
| **A/B Testing** | None     | Low      | Medium        | Fast           | High       |
| **Shadow**      | None     | Very Low | High (2x)     | N/A            | Very High  |

---

## Strategy 1: Rolling Deployment

### How It Works

```
Time →
┌────────────────────────────────────────────────────────────────┐
│                     Rolling Deployment                          │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Phase 1:  [v1][v1][v1][v1]     ← All pods running v1           │
│                                                                 │
│ Phase 2:  [v2][v1][v1][v1]     ← First pod updated             │
│                                                                 │
│ Phase 3:  [v2][v2][v1][v1]     ← Second pod updated            │
│                                                                 │
│ Phase 4:  [v2][v2][v2][v1]     ← Third pod updated             │
│                                                                 │
│ Phase 5:  [v2][v2][v2][v2]     ← All pods running v2           │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Kubernetes Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1 # Can temporarily exceed desired replicas by 1
      maxUnavailable: 0 # Never reduce below desired replicas
  template:
    spec:
      containers:
        - name: backend
          image: myapp:v2
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            successThreshold: 1
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
```

### Pros & Cons

| Pros                      | Cons                              |
| ------------------------- | --------------------------------- |
| Simple to implement       | Both versions run simultaneously  |
| Low resource overhead     | Harder to rollback mid-deployment |
| Native Kubernetes support | No traffic control granularity    |
| Gradual transition        | Database schema changes complex   |

---

## Strategy 2: Blue/Green Deployment

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    Blue/Green Deployment                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                        ┌─────────────┐                          │
│                        │   Route53   │                          │
│                        │   / ALB     │                          │
│                        └──────┬──────┘                          │
│                               │                                  │
│              ┌────────────────┼────────────────┐                │
│              │                │                │                │
│              ▼                                 ▼                │
│   ┌─────────────────────┐         ┌─────────────────────┐      │
│   │    BLUE (v1)        │         │    GREEN (v2)       │      │
│   │    [Active]         │         │    [Standby]        │      │
│   │                     │         │                     │      │
│   │  ┌─────┐ ┌─────┐   │         │  ┌─────┐ ┌─────┐   │      │
│   │  │Pod 1│ │Pod 2│   │         │  │Pod 1│ │Pod 2│   │      │
│   │  └─────┘ └─────┘   │         │  └─────┘ └─────┘   │      │
│   │  ┌─────┐ ┌─────┐   │         │  ┌─────┐ ┌─────┐   │      │
│   │  │Pod 3│ │Pod 4│   │         │  │Pod 3│ │Pod 4│   │      │
│   │  └─────┘ └─────┘   │         │  └─────┘ └─────┘   │      │
│   └─────────────────────┘         └─────────────────────┘      │
│         100% Traffic ───────────────▶    0% Traffic            │
│                                                                  │
│   After Switch:                                                 │
│         0% Traffic    ◀───────────────  100% Traffic           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation with AWS ALB

```hcl
# Terraform: ALB Target Group Switching

resource "aws_lb_target_group" "blue" {
  name     = "myapp-blue"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}

resource "aws_lb_target_group" "green" {
  name     = "myapp-green"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}

# Switch traffic by updating listener rule
resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.active_color == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  }

  condition {
    host_header {
      values = ["app.example.com"]
    }
  }
}
```

### Kubernetes Implementation with Service Switching

```yaml
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-blue
  labels:
    app: backend
    version: blue
spec:
  replicas: 4
  selector:
    matchLabels:
      app: backend
      version: blue
  template:
    metadata:
      labels:
        app: backend
        version: blue
    spec:
      containers:
        - name: backend
          image: myapp:v1

---
# Green deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-green
  labels:
    app: backend
    version: green
spec:
  replicas: 4
  selector:
    matchLabels:
      app: backend
      version: green
  template:
    metadata:
      labels:
        app: backend
        version: green

---
# Service - switch by updating selector
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
    version: blue # Change to 'green' to switch
  ports:
    - port: 80
      targetPort: 8080
```

### Pros & Cons

| Pros                       | Cons                                   |
| -------------------------- | -------------------------------------- |
| Instant rollback           | 2x resource cost                       |
| Full testing before switch | Requires infrastructure duplication    |
| Clean separation           | Database changes need careful handling |
| Simple mental model        | Not gradual - all or nothing           |

---

## Strategy 3: Canary Deployment (RECOMMENDED)

### Why Canary for Microservices

For a microservice architecture, **Canary deployment** is the recommended strategy because:

1. **Risk Mitigation**: Only a small percentage of traffic sees new code initially
2. **Real User Testing**: Validates with actual production traffic
3. **Gradual Rollout**: Can detect issues before full deployment
4. **Metrics-Driven**: Automated promotion based on success criteria
5. **Cost-Effective**: Doesn't require full duplicate infrastructure

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      Canary Deployment                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                        ┌─────────────┐                          │
│                        │   Ingress   │                          │
│                        │  Controller │                          │
│                        └──────┬──────┘                          │
│                               │                                  │
│              ┌────────────────┴────────────────┐                │
│              │                                 │                │
│              ▼ 90%                        10% ▼                │
│   ┌─────────────────────┐         ┌─────────────────────┐      │
│   │    STABLE (v1)      │         │    CANARY (v2)      │      │
│   │                     │         │                     │      │
│   │  ┌─────┐ ┌─────┐   │         │  ┌─────┐           │      │
│   │  │Pod 1│ │Pod 2│   │         │  │Pod 1│           │      │
│   │  └─────┘ └─────┘   │         │  └─────┘           │      │
│   │  ┌─────┐ ┌─────┐   │         │                     │      │
│   │  │Pod 3│ │Pod 4│   │         │                     │      │
│   │  └─────┘ └─────┘   │         │                     │      │
│   └─────────────────────┘         └─────────────────────┘      │
│                                                                  │
│   Progression:                                                  │
│   Step 1: 10% canary  → Analyze metrics                        │
│   Step 2: 25% canary  → Analyze metrics                        │
│   Step 3: 50% canary  → Analyze metrics                        │
│   Step 4: 100% (promote canary to stable)                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation with Argo Rollouts

```yaml
# Argo Rollouts - Canary Strategy
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: backend
  namespace: production
spec:
  replicas: 5
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: myapp:v2
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
  strategy:
    canary:
      # Traffic routing
      canaryService: backend-canary
      stableService: backend-stable

      # Traffic management via ingress
      trafficRouting:
        nginx:
          stableIngress: backend-ingress
          annotationPrefix: nginx.ingress.kubernetes.io

      # Rollout steps
      steps:
        - setWeight: 5
        - pause: { duration: 2m }

        - setWeight: 10
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: success-rate
            args:
              - name: service-name
                value: backend-canary

        - setWeight: 25
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: success-rate

        - setWeight: 50
        - pause: { duration: 10m }
        - analysis:
            templates:
              - templateName: success-rate
              - templateName: latency-check

        - setWeight: 75
        - pause: { duration: 10m }

        - setWeight: 100

      # Anti-affinity for canary pods
      antiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          weight: 100

      # Maximum surge during rollout
      maxSurge: "25%"
      maxUnavailable: 0

---
# AnalysisTemplate for automated rollback
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      count: 5
      successCondition: result[0] >= 0.95
      failureCondition: result[0] < 0.90
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              status=~"2.."
            }[5m])) /
            sum(rate(http_requests_total{
              service="{{args.service-name}}"
            }[5m]))

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-check
spec:
  metrics:
    - name: latency-p99
      interval: 1m
      count: 5
      successCondition: result[0] < 0.5
      failureCondition: result[0] > 1.0
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{
                service="backend-canary"
              }[5m])) by (le)
            )
```

### Services Configuration

```yaml
# Stable service (receives majority traffic)
apiVersion: v1
kind: Service
metadata:
  name: backend-stable
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 8080

---
# Canary service (receives canary traffic)
apiVersion: v1
kind: Service
metadata:
  name: backend-canary
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 8080

---
# Ingress with canary annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "0" # Managed by Argo
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-stable
                port:
                  number: 80
```

### AWS ALB Traffic Splitting

```hcl
# ALB weighted target groups for canary
resource "aws_lb_listener_rule" "canary" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.stable.arn
        weight = 90
      }
      target_group {
        arn    = aws_lb_target_group.canary.arn
        weight = 10
      }
      stickiness {
        enabled  = true
        duration = 600
      }
    }
  }

  condition {
    host_header {
      values = ["api.example.com"]
    }
  }
}
```

---

## Strategy 4: A/B Testing Deployment

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                       A/B Testing                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   User Request                                                  │
│        │                                                        │
│        ▼                                                        │
│   ┌─────────────────┐                                          │
│   │  Header/Cookie  │                                          │
│   │   Check         │                                          │
│   └────────┬────────┘                                          │
│            │                                                    │
│   ┌────────┴─────────────────┐                                 │
│   │                          │                                 │
│   │ header: x-feature=new    │ header: x-feature=old           │
│   │ cookie: beta=true        │ (or no header)                  │
│   │                          │                                 │
│   ▼                          ▼                                 │
│ ┌──────────────┐      ┌──────────────┐                        │
│ │   Version B  │      │   Version A  │                        │
│ │   (New UI)   │      │   (Current)  │                        │
│ └──────────────┘      └──────────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### NGINX Ingress Configuration

```yaml
# A/B testing with header-based routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ab
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "x-feature"
    nginx.ingress.kubernetes.io/canary-by-header-value: "new"
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-new
                port:
                  number: 80

---
# Cookie-based routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ab-cookie
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-cookie: "beta"
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-new
                port:
                  number: 80
```

---

## Recommended Strategy: Canary with Automated Analysis

### Justification for Microservices

| Requirement           | How Canary Addresses It                             |
| --------------------- | --------------------------------------------------- |
| Zero downtime         | Gradual traffic shift, never takes all pods offline |
| Risk mitigation       | Only 5-10% of users see new version initially       |
| Fast feedback         | Real production metrics, not synthetic tests        |
| Automated rollback    | Analysis templates trigger automatic rollback       |
| Cost effective        | Only needs ~10% extra resources during rollout      |
| Microservice friendly | Per-service deployment with service mesh            |

### Rollback Procedure

```bash
# Manual rollback with Argo Rollouts
kubectl argo rollouts abort backend -n production

# Undo to previous version
kubectl argo rollouts undo backend -n production

# Promote manually (skip remaining steps)
kubectl argo rollouts promote backend -n production

# Check status
kubectl argo rollouts status backend -n production
kubectl argo rollouts get rollout backend -n production --watch
```

---

## Summary

| Strategy        | Best For                         | Not Ideal For                         |
| --------------- | -------------------------------- | ------------------------------------- |
| **Rolling**     | Simple apps, low risk            | Large changes, strict rollback needs  |
| **Blue/Green**  | Critical apps, instant rollback  | Cost-sensitive, large infrastructures |
| **Canary**      | Microservices, risk-averse teams | Small teams, simple apps              |
| **A/B Testing** | Feature experimentation          | Pure infrastructure changes           |

**For microservice architectures, Canary deployment with automated analysis provides the best balance of:**

- Zero downtime
- Risk mitigation through gradual rollout
- Automated rollback based on metrics
- Cost efficiency
- Production validation
