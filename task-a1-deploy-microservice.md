# Task A1 - Production-Ready Kubernetes Microservice Deployment

## Executive Summary

This document provides a comprehensive technical solution for deploying a three-tier microservice application (frontend, backend, and PostgreSQL database) to Kubernetes with production-grade configurations. The solution implements Helm charts for all components, ensuring maintainability, scalability, and security through industry best practices.

**Key Deliverables:**

- Production-ready Helm charts for frontend, backend, and PostgreSQL
- Complete Kubernetes manifests with all required resources
- Zero-trust network security model
- Automated horizontal scaling
- Zero-downtime deployment strategy
- Comprehensive security hardening

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Solution Design](#solution-design)
3. [Implementation Details](#implementation-details)
4. [Security Architecture](#security-architecture)
5. [Scalability & Performance](#scalability--performance)
6. [Deployment Strategy](#deployment-strategy)
7. [Trade-offs & Decisions](#trade-offs--decisions)
8. [Operational Considerations](#operational-considerations)

---

## Architecture Overview

The application follows a traditional three-tier architecture deployed within a Kubernetes cluster:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Ingress Controller (NGINX/ALB)                │  │
│  └───────────────────────┬───────────────────────────────────┘  │
│                          │                                       │
│  ┌───────────────────────▼───────────────────────────────────┐  │
│  │                    Ingress Resource                        │  │
│  │         /api/* → backend    /* → frontend                  │  │
│  └───────────────┬───────────────────────┬───────────────────┘  │
│                  │                         │                     │
│  ┌───────────────▼──────────┐  ┌──────────▼──────────────┐    │
│  │  Frontend Service         │  │  Backend Service         │    │
│  │  (ClusterIP:80)           │  │  (ClusterIP:80)          │    │
│  └───────────────┬──────────┘  └──────────┬───────────────┘    │
│                  │                         │                     │
│  ┌───────────────▼──────────┐  ┌──────────▼──────────────┐    │
│  │  Frontend Deployment     │  │  Backend Deployment       │    │
│  │  (HPA: 2-10 pods)        │  │  (HPA: 2-10 pods)         │    │
│  │  - Nginx Container       │  │  - PHP-FPM Container      │    │
│  │  - NetworkPolicy         │  │  - Nginx Container       │    │
│  │  - PodDisruptionBudget   │  │  - NetworkPolicy         │    │
│  └──────────────────────────┘  │  - PodDisruptionBudget   │    │
│                                 └──────────┬───────────────┘    │
│                                            │                     │
│                                 ┌──────────▼───────────────┐    │
│                                 │  PostgreSQL Service       │    │
│                                 │  (Headless ClusterIP)     │    │
│                                 └──────────┬───────────────┘    │
│                                            │                     │
│                                 ┌──────────▼───────────────┐    │
│                                 │  PostgreSQL StatefulSet   │    │
│                                 │  (Zalando Operator)       │    │
│                                 │  - Persistent Volume      │    │
│                                 │  - NetworkPolicy         │    │
│                                 └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component    | Technology                | Responsibility                                    |
| ------------ | ------------------------- | ------------------------------------------------- |
| **Frontend** | React + Nginx             | Serves static assets, handles client-side routing |
| **Backend**  | Laravel (PHP-FPM) + Nginx | Business logic, API endpoints, database access    |
| **Database** | PostgreSQL 17             | Persistent data storage, ACID transactions        |

---

## Solution Design

### Design Principles

1. **Security First**: Zero-trust network model, non-root containers, minimal capabilities
2. **High Availability**: Multi-replica deployments with PodDisruptionBudgets
3. **Scalability**: Horizontal Pod Autoscaling based on resource utilization
4. **Operational Excellence**: Comprehensive health checks, graceful shutdowns, observability
5. **Configuration Management**: Externalized configuration via ConfigMaps and Secrets
6. **Helm-Based Deployment**: All components, dependencies, and infrastructure are managed through Helm charts

### Helm-Based Architecture

**Decision**: Everything is packaged and deployed using Helm charts

**Rationale**:

- **Unified Deployment**: All Kubernetes resources (Deployments, Services, ConfigMaps, Secrets, NetworkPolicies, HPA, PDB) are defined and managed through Helm charts, ensuring consistency across environments
- **Dependency Management**: External dependencies like Prometheus Operator are managed as Helm chart dependencies, providing version control and automated installation
- **Environment-Specific Configuration**: Helm values files enable easy customization for different environments (dev, staging, production) without code duplication
- **Versioning & Rollback**: Helm tracks release versions, enabling easy rollback to previous configurations
- **Template Reusability**: Helm templates reduce duplication and ensure consistent resource definitions across components
- **CI/CD Integration**: Helm charts integrate seamlessly with CI/CD pipelines, enabling automated deployments
- **Infrastructure as Code**: All infrastructure configuration is version-controlled and declarative, following GitOps principles

### Key Design Decisions

#### 1. Deployment Strategy: Rolling Updates

**Decision**: Use `RollingUpdate` strategy with `maxSurge: 1` and `maxUnavailable: 0`

**Rationale**:

- **Zero-downtime deployments**: New pods are created before old ones are terminated
- **Gradual rollout**: One pod at a time ensures service stability
- **Automatic rollback**: Kubernetes can automatically rollback failed deployments

**Trade-off**: Slower deployment time compared to `Recreate` strategy, but essential for production availability. The configuration of `maxSurge: 1` and `maxUnavailable: 0` results in a conservative, one-pod-at-a-time rollout that provides better guarantees for handling load during updates. This approach ensures that the application maintains full capacity throughout the deployment process, which is critical for production workloads. The rollout speed can be adjusted based on application requirements, traffic patterns, and deployment risk tolerance—more aggressive settings (e.g., `maxSurge: 2`, `maxUnavailable: 1`) can be used for stateless services with lower risk tolerance, while the current conservative approach is optimal for high-availability requirements.

#### 2. Resource Management

**Decision**: Set both resource requests and limits for all containers

**Rationale**:

- **Requests**: Enable Kubernetes scheduler to make informed placement decisions
- **Limits**: Prevent resource exhaustion and "noisy neighbor" problems
- **Quality of Service**: Results in "Burstable" QoS class, which allows pods to burst beyond requested resources up to the limit when cluster capacity is available

**Resource Allocation**:

| Component         | CPU Request | CPU Limit | Memory Request | Memory Limit |
| ----------------- | ----------- | --------- | -------------- | ------------ |
| Frontend (Nginx)  | 100m        | 500m      | 128Mi          | 256Mi        |
| Backend (PHP-FPM) | 250m        | 1000m     | 256Mi          | 512Mi        |
| Backend (Nginx)   | 100m        | 500m      | 128Mi          | 256Mi        |
| PostgreSQL        | 500m        | 2000m     | 512Mi          | 2Gi          |

**Trade-off**: Based on application needs, the "Burstable" QoS configuration balances flexibility with resource protection. Unlike "Guaranteed" QoS or "BestEffort", "Burstable" ensures minimum resource guarantees while allowing pods to burst beyond requests when capacity is available. This may cause CPU throttling under extreme load, but prevents cluster resource exhaustion and enables efficient resource utilization.

#### 3. Health Checks: Dual Probes

**Decision**: Implement both liveness and readiness probes

- **Liveness Probe**: Detects deadlocked containers and triggers restart
- **Readiness Probe**: Ensures traffic only routes to healthy pods
- **Different Timings**: Readiness checks more frequently to respond quickly to health changes

**Trade-off**: Aggressive probe timing may cause false positives, but ensures rapid failure detection.

#### 4. Horizontal Pod Autoscaling

**Decision**: HPA based on CPU (70%) and memory (80%) utilization

**Rationale**:

- **Multi-metric scaling**: More accurate than single-metric scaling
- **Stabilization windows**: Prevent scaling thrashing
- **Behavior policies**: Control scale-up/down rates

**Trade-off**: Slower scale-down prevents premature pod termination but may result in over-provisioning during traffic drops.

#### 5. PodDisruptionBudget

**Decision**: `minAvailable: 1` for stateless services, `maxUnavailable: 0` for database

**Rationale**:

- **Voluntary disruptions**: Protects against node maintenance, cluster upgrades
- **Minimum availability**: Ensures at least one pod remains available
- **Database protection**: Zero unavailability for stateful database

**Trade-off**: May slow down cluster maintenance operations, but ensures service continuity.

#### 6. Network Security: Zero-Trust Model

**Decision**: Default-deny NetworkPolicy with explicit allow rules

**Rationale**:

- **Defense in depth**: Even if a pod is compromised, network access is restricted
- **Least privilege**: Pods can only communicate with explicitly allowed services
- **Compliance**: Meets security requirements for regulated industries

**Trade-off**: More complex configuration and potential connectivity issues during troubleshooting, but significantly improves security posture.

---

## Implementation Details

### 1. Namespace Isolation

**Implementation**: Application deployed in dedicated namespace with Pod Security Standards

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Benefits**:

- Resource isolation
- Security policy enforcement
- Simplified RBAC management

### 2. Configuration Management

#### ConfigMaps

Externalize all non-sensitive configuration in configmaps:
**Benefits**:

- Environment-specific configuration without image rebuilds
- Version control of configuration
- Easy rollback of configuration changes

#### Secrets

Store sensitive data like passwords separately in secrets

### 3. Frontend Deployment

**Architecture**: Single-container deployment with Nginx serving static React build. Since the application uses Client-Side Rendering (CSR) rather than Server-Side Rendering (SSR), all rendering occurs in the browser, allowing Nginx to serve pre-built static assets without requiring a Node.js runtime or server-side processing.

**Key Features**:

- Non-root execution (UID 101 - nginx user)
- Resource limits for predictable performance
- Health probes for automatic recovery

### 4. Backend Deployment

**Architecture**: Multi-container pod with PHP-FPM and Nginx

**Container Responsibilities**:

- **PHP-FPM**: Executes Laravel application logic
- **Nginx**: Reverse proxy, serves static assets, handles HTTP requests

**Key Features**:

- Termination grace period (60s) for in-flight requests
- Database connection pooling
- OpenTelemetry integration for observability
- Observability dependencies (Prometheus Operator) managed via Helm chart dependencies

**Dependencies & Observability**:

- **Prometheus Operator**: Backend monitoring and metrics collection dependencies are handled by the Helm chart through the Prometheus Operator dependency. ServiceMonitor resources are automatically created to expose application metrics to Prometheus, eliminating the need for manual configuration
- **Service Discovery**: The Helm chart integrates with Prometheus Operator to automatically configure metric scraping, ensuring observability is built into the deployment

**Container Image**:

- **Lightweight**: Dockerfile uses Alpine Linux base image, resulting in minimal image size and reduced attack surface
- **Cache-Friendly**: Multi-stage builds and layer ordering optimize Docker layer caching, reducing build times and bandwidth usage during deployments
- **Security**: Minimal base image reduces vulnerabilities, and security best practices (non-root user, minimal packages) are enforced at the image level

**User ID Rationale**:

- **UID 33 (www-data)**: Standard user for PHP-FPM in Alpine Linux containers
- **UID 101 (nginx)**: Standard user for Nginx in Alpine Linux containers
- Matching container user IDs ensures proper file permissions and security

### 5. PostgreSQL Deployment

**Decision**: For non-managed database deployments (development/staging), use Zalando PostgreSQL Operator instead of raw StatefulSet. For production environments, AWS RDS (managed database service) is used to leverage fully managed infrastructure with automatic backups, scaling, and high availability.

**Rationale**:

- **High Availability**: Automatic failover, replication management
- **Backup Management**: Integrated backup/restore capabilities
- **Connection Pooling**: Built-in PgBouncer support
- **Monitoring**: Integrated metrics and health checks

**Alternative**: Managed RDS can be used (configured via `rds` values).

### 6. Service Discovery

**Service Types**:

- **Frontend/Backend**: `ClusterIP` - Internal cluster access only
- **PostgreSQL**: Headless `ClusterIP` (clusterIP: None) - Direct pod access for StatefulSet

### 7. Ingress Configuration

**Implementation**: NGINX Ingress Controller or AWS ALB Ingress Controller

## Security Architecture

### Defense in Depth Strategy

The solution implements multiple security layers:

#### 1. Pod Security Standards

**Namespace-level enforcement**:

- `restricted` policy enforcement
- Prevents privileged containers
- Requires non-root execution
- Enforces read-only filesystems where possible

#### 2. Container Security Context

**Per-container hardening**:

- `runAsNonRoot: true` - Prevents privilege escalation
- `allowPrivilegeEscalation: false` - Blocks privilege escalation
- `capabilities.drop: ALL` - Removes all Linux capabilities
- `readOnlyRootFilesystem: true` - Prevents filesystem modifications (where applicable)

#### 3. Network Policies

**Zero-trust networking model**:

1. **Default Deny Policy**: Blocks all ingress/egress traffic
2. **Frontend Policy**: Allows ingress from ingress controller, egress for DNS
3. **Backend Policy**: Allows ingress from ingress controller, egress to PostgreSQL and DNS
4. **PostgreSQL Policy**: Allows ingress only from backend pods

**Benefits**:

- Limits lateral movement in case of compromise
- Reduces attack surface
- Enforces least-privilege network access

#### 4. Secrets Management

**Current Implementation**: Kubernetes Secrets with base64 encoding used in CI/CD

**Future Enhancement**: Integrate with AWS Secrets Manager or HashiCorp Vault

#### 5. Image Security

- Scan container images in CI/CD pipeline
- Use minimal base images (Alpine Linux)
- Implement image signing and verification

#### 6. Service Accounts

**Configuration**:

```yaml
automountServiceAccountToken: false # Disable automatic token mounting
```

**Benefits**:

- Reduces attack surface
- Prevents unauthorized API server access
- Follows least-privilege principle

---

## Scalability & Performance

### Horizontal Scaling

**Implementation**: Horizontal Pod Autoscaler (HPA) with multi-metric support

**Scaling Triggers**:

- CPU utilization > 70%
- Memory utilization > 80%

**Scaling Behavior**:

- **Scale Up**: Aggressive (2 pods per 60s) to handle traffic spikes
- **Scale Down**: Conservative (25% reduction per 60s) to prevent thrashing

**Scaling Range**:

- Frontend: 2-10 replicas
- Backend: 2-10 replicas
- PostgreSQL: Fixed (managed by operator for HA)

### Database Scaling

**Current Approach**: Zalando PostgreSQL Operator with 2 instances

---

## Deployment Strategy

### Standard Rolling Deployment

**Process**:

1. Update image tag in Helm values
2. Deploy using Helm: `helm upgrade --install backend ./helm -f values-prod.yaml`
3. Monitor rollout: `kubectl rollout status deployment/backend`
4. Verify health: Check pod logs and metrics
5. Rollback if needed: `kubectl rollout undo deployment/backend`

**Advantages**:

- Zero-downtime deployments
- Automatic rollback on failure
- Gradual traffic migration

### Advanced Deployment Strategies

#### Canary Deployments

**Implementation**: Use Argo Rollouts for traffic splitting

**Benefits**:

- Gradual rollout to subset of users
- Automatic rollback on error rate increase
- A/B testing capabilities

#### Blue-Green Deployments

**Implementation**: Deploy new version alongside old, switch traffic atomically

**Use Cases**:

- Major version upgrades
- Database schema migrations
- High-risk deployments

### Database Migration Strategy

**Implementation**: Kubernetes Jobs for migrations and seeding, configured as Helm post-install and post-upgrade hooks

**Process**:

1. Run migration job before deployment
2. Verify migration success
3. Deploy new application version
4. Monitor for issues

**Environment-Specific Usage**:

- **Development/Staging**: Migration and seed jobs are enabled via Helm hooks (post-install and post-upgrade) to automate database setup and updates
- **Production**: Migration and seed jobs should be disabled and run manually or through a separate CI/CD pipeline. This provides better control, auditability, and reduces the risk of automatic migrations affecting production data
- The `enabled` flag allows easy toggling of migration jobs per environment

## Trade-offs & Decisions

### Alternative Approaches Considered

#### 1. Service Mesh (Istio/Linkerd)

**Not Implemented**: Service mesh adds significant complexity

**Trade-off**:

- **Pros**: mTLS, advanced traffic management, observability
- **Cons**: Resource overhead, operational complexity, learning curve

**Decision**: Use NetworkPolicies for basic security, consider service mesh for future if needed

#### 2. GitOps (ArgoCD/Flux)

**Not Implemented**: GitOps not in initial scope

**Trade-off**:

- **Pros**: Declarative deployments, audit trail, automated sync
- **Cons**: Additional tooling, potential sync conflicts

**Decision**: Use Helm directly, migrate to GitOps in future

#### 3. Managed Database (RDS)

**Option Available**: Can use RDS instead of operator

**Trade-off**:

- **Pros**: Fully managed, automatic backups, scaling
- **Cons**: Cost, less control, network latency

**Decision**: Support both options via Helm values

## Operational Considerations

### Monitoring & Observability

- **Metrics**: Prometheus + Grafana
- **Logging**: ELK Stack or Loki
- **Tracing**: Jaeger (via OpenTelemetry)

**Key Metrics to Monitor**:

- Pod CPU/Memory utilization
- Request latency (p50, p95, p99)
- Error rates
- Database connection pool usage
- HPA scaling events

### Logging Strategy

**Implementation**: Structured logging to stdout/stderr

### Backup & Disaster Recovery

**Database Backups**:

- Zalando Operator: Automatic backups (if configured)
- RDS: Automated daily backups with point-in-time recovery
- Manual: Kubernetes CronJobs for custom backup scripts

**Application State**:

- Stateless application: No backup needed
- ConfigMaps/Secrets: Version controlled in Git

## Conclusion

This solution provides a production-ready Kubernetes deployment with:

**Complete Helm Charts** for all components
**Zero-downtime Deployments** with rolling update strategy
**Automatic Scaling** via HPA with multi-metric support
**High Availability** with PDB and multi-replica deployments
**Network Security** with zero-trust NetworkPolicies
**Resource Management** with proper requests and limits
**Health Monitoring** with comprehensive probes
**Security Hardening** with non-root containers and minimal capabilities

The implementation follows Kubernetes best practices and provides a solid foundation for production workloads while maintaining flexibility for future enhancements.
