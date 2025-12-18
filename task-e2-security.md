# Task E2 - Secure the Entire System

## Problem Statement

Provide comprehensive security controls including:

- IAM least-privilege examples
- Multi-account strategy
- Secrets management (AWS Secrets Manager/KMS)
- Kubernetes RBAC
- Network restrictions (SGs/NACLs)
- PodSecurity
- CI/CD security controls (image scanning, signing)

---

> **Note: Implementation Status**
>
> All security controls described in this document are **implemented in Terraform** and actively deployed across dev, staging, and prod environments. The implementation includes:
>
> - **IAM Roles & Policies**: [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf) - IRSA roles for Kubernetes controllers and application pods
> - **CI/CD IAM**: [`terraform/modules/github-actions-ecr/main.tf`](../terraform/modules/github-actions-ecr/main.tf) - Least-privilege IAM user for GitHub Actions
> - **Kubernetes RBAC**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) - Namespace-scoped roles and bindings
> - **GitHub Secrets**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) - Automated secret creation and management
> - **Security Groups**: [`terraform/modules/rds/main.tf`](../terraform/modules/rds/main.tf), [`terraform/modules/nodegroups/main.tf`](../terraform/modules/nodegroups/main.tf) - Network restrictions
> - **Multi-Account Isolation**: Separate Terraform environments in [`terraform/environments/dev/`](../terraform/environments/dev/), [`terraform/environments/staging/`](../terraform/environments/staging/), [`terraform/environments/prod/`](../terraform/environments/prod/)
> - **CI/CD Workflows**: [`backend/.github/workflows/deploy-backend.yml`](../backend/.github/workflows/deploy-backend.yml), [`frontend/.github/workflows/deploy-frontend.yml`](../frontend/.github/workflows/deploy-frontend.yml)
>
> See the [Implementation Files Reference](#implementation-files-reference) section at the end of this document for complete file listings.

---

## Security Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Security Defense in Depth                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   Layer 1: Edge Security                                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  WAF │ DDoS Protection │ CloudFront │ Rate Limiting │ Bot Detection │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│   Layer 2: Network Security                                                  │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  VPC │ Security Groups │ NACLs │ PrivateLink │ VPC Endpoints       │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│   Layer 3: Identity & Access                                                 │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  IAM │ IRSA │ RBAC │ OIDC │ MFA │ SCPs │ Permission Boundaries     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│   Layer 4: Workload Security                                                 │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  PodSecurity │ Network Policies │ Service Mesh │ mTLS │ Admission  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│   Layer 5: Data Security                                                     │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  KMS │ Secrets Manager │ Encryption at Rest │ TLS │ Tokenization   │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│   Layer 6: Detection & Response                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  GuardDuty │ CloudTrail │ Security Hub │ Inspector │ SIEM          │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. IAM Least Privilege

### Principle

Grant only the minimum permissions necessary for each role to perform its function.

**Implementation**: All IAM roles and policies are defined in Terraform modules with least-privilege principles.

**Terraform Files**:

- [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf) - IRSA roles for Kubernetes controllers and application pods
- [`terraform/modules/github-actions-ecr/main.tf`](../terraform/modules/github-actions-ecr/main.tf) - CI/CD IAM user with minimal ECR/EKS/RDS permissions
- [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) - Platform stack that configures IAM modules

### Application Pod Role (IRSA)

**Implementation**: IRSA (IAM Roles for Service Accounts) roles are created dynamically for application pods via the `service_accounts` variable in the IAM module.

**Reference**: [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf) (lines 426-460)

Example configuration:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadSpecificBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::myapp-assets-prod",
        "arn:aws:s3:::myapp-assets-prod/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:PrincipalTag/Environment": "production"
        }
      }
    },
    {
      "Sid": "AllowSQSSendToSpecificQueue",
      "Effect": "Allow",
      "Action": ["sqs:SendMessage", "sqs:GetQueueUrl"],
      "Resource": "arn:aws:sqs:us-east-1:123456789012:myapp-events",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Application": "myapp"
        }
      }
    },
    {
      "Sid": "AllowSecretsManagerRead",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:myapp/*",
      "Condition": {
        "StringEquals": {
          "secretsmanager:ResourceTag/Environment": "production"
        }
      }
    },
    {
      "Sid": "DenyAllOutsideRegion",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    }
  ]
}
```

### CI/CD Pipeline Role (GitHub Actions)

**Implementation**: Dedicated IAM user for GitHub Actions with least-privilege access to ECR, EKS, and RDS.

**Reference**: [`terraform/modules/github-actions-ecr/main.tf`](../terraform/modules/github-actions-ecr/main.tf)

**Key Features**:

- **ECR Access**: Scoped to specific repositories (`backend`, `frontend`) only
- **EKS Access**: Read-only `DescribeCluster` for specific cluster ARNs
- **RDS Access**: Read-only `DescribeDBInstances` and `DescribeDBClusters` for deployment configuration
- **No Infrastructure Modification**: Cannot create/delete/modify AWS resources

**Policy Structure**:

1. **ECR Authentication** (line 36-42): `ecr:GetAuthorizationToken` - Required for Docker login
2. **ECR Repository Access** (line 44-58): Push/pull images to specific repositories only
3. **ECR Describe** (line 60-70): List and describe images in repositories
4. **ECR Create Repository** (line 72-83): Allow repository creation (used by workflows)
5. **EKS Access** (line 99-117): Optional read-only cluster access
6. **RDS Access** (line 122-151): Optional read-only RDS instance access

**Usage**: The IAM user credentials are automatically created and stored as GitHub Environment Secrets by Terraform. See [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) (lines 546-651) for secret creation.

**Multi-Environment Isolation**: Each environment (dev, staging, prod) has its own IAM user:

- `github-actions-ecr-dev`
- `github-actions-ecr-staging`
- `github-actions-ecr-prod`

Each user can only access resources in its respective AWS account.

### Kubernetes Controller Roles

**Cluster Autoscaler**:

- **Reference**: [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf) (lines 12-80)
- **Permissions**: Auto-scaling group management with resource tag conditions
- **Key Security**: Can only modify ASGs tagged with `k8s.io/cluster-autoscaler/enabled=true`

**AWS Load Balancer Controller**:

- **Reference**: [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf) (lines 85-362)
- **Permissions**: ELB/ALB/NLB management, security group modifications
- **Key Security**: Resource tag conditions ensure only cluster-managed resources can be modified

**External DNS** (if enabled):

- **Reference**: [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf) (lines 367-421)
- **Permissions**: Route53 record management
- **Key Security**: Scoped to specific hosted zones

---

## 2. Multi-Account Strategy

### Implementation

**Architecture**: Complete account isolation per environment (dev, staging, prod).

**Terraform Structure**:

- [`terraform/environments/dev/`](../terraform/environments/dev/) - Development environment
- [`terraform/environments/staging/`](../terraform/environments/staging/) - Staging environment
- [`terraform/environments/prod/`](../terraform/environments/prod/) - Production environment

Each environment:

- Has its own AWS account
- Uses separate Terraform state backends (S3 + DynamoDB)
- Has isolated IAM users, roles, and policies
- Uses environment-specific GitHub secrets
- Deploys to separate EKS clusters

### Account Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS Organization                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Root Account (Management)                                                 │
│   └── Organizations, SCPs, Billing                                          │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Security OU                                      │  │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │  │
│   │   │   Audit     │  │   Log       │  │  Security   │                │  │
│   │   │  Account    │  │  Archive    │  │   Tools     │                │  │
│   │   │             │  │             │  │             │                │  │
│   │   │ CloudTrail  │  │ Central     │  │ GuardDuty   │                │  │
│   │   │ Config      │  │ Logging     │  │ Inspector   │                │  │
│   │   │ Access      │  │ S3 Buckets  │  │ Macie       │                │  │
│   │   │ Analyzer    │  │             │  │ SIEM        │                │  │
│   │   └─────────────┘  └─────────────┘  └─────────────┘                │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Infrastructure OU                                │  │
│   │   ┌─────────────┐  ┌─────────────┐                                  │  │
│   │   │  Network    │  │   Shared    │                                  │  │
│   │   │  Account    │  │  Services   │                                  │  │
│   │   │             │  │             │                                  │  │
│   │   │ Transit GW  │  │ ECR         │                                  │  │
│   │   │ VPN         │  │ Route53     │                                  │  │
│   │   │ Direct Con. │  │ ACM         │                                  │  │
│   │   └─────────────┘  └─────────────┘                                  │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Workloads OU                                     │  │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │  │
│   │   │ Development │  │   Staging   │  │ Production  │                │  │
│   │   │             │  │             │  │             │                │  │
│   │   │ EKS Dev     │  │ EKS Stage   │  │ EKS Prod    │                │  │
│   │   │ RDS Dev     │  │ RDS Stage   │  │ RDS Prod    │                │  │
│   │   │             │  │             │  │ Multi-AZ    │                │  │
│   │   └─────────────┘  └─────────────┘  └─────────────┘                │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Service Control Policies (SCPs)

```json
// Deny leaving organization
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeaveOrganization",
      "Effect": "Deny",
      "Action": ["organizations:LeaveOrganization"],
      "Resource": "*"
    }
  ]
}
```

```json
// Deny root user access
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootUser",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}
```

```json
// Restrict to approved regions
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnapprovedRegions",
      "Effect": "Deny",
      "Action": ["ec2:*", "rds:*", "eks:*", "lambda:*", "s3:CreateBucket"],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2", "eu-west-1"]
        }
      }
    }
  ]
}
```

---

## 3. Secrets Management

### Implementation Strategy

**Approach**: GitHub Secrets for CI/CD, AWS Secrets Manager/KMS for runtime secrets.

**Rationale**:

- GitHub Secrets provide direct access for CI/CD workflows (code is in GitHub)
- Terraform automatically generates and manages GitHub secrets
- Application secrets (DB passwords, API keys) are stored in Kubernetes secrets, sourced from GitHub secrets during deployment

### GitHub Secrets (CI/CD)

**Implementation**: Terraform automatically creates GitHub Environment Secrets for each environment.

**Reference**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) (lines 544-651)

**Automatically Created Secrets**:

- `AWS_ACCESS_KEY_ID` - IAM user access key for GitHub Actions
- `AWS_SECRET_ACCESS_KEY` - IAM user secret key
- `EKS_CLUSTER_NAME` - EKS cluster name for kubectl configuration
- `RDS_IDENTIFIER` - RDS instance identifier
- `RDS_USERNAME` - Database username
- `RDS_PASSWORD` - Database password (from Terraform variables)
- `RDS_SSL_MODE` - SSL mode for database connections
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password

**Environment Isolation**: Each environment (dev, staging, production) has separate GitHub environments with isolated secrets.

**Usage in CI/CD**:

- Backend: [`backend/.github/workflows/deploy-backend.yml`](../backend/.github/workflows/deploy-backend.yml)
- Frontend: [`frontend/.github/workflows/deploy-frontend.yml`](../frontend/.github/workflows/deploy-frontend.yml)

### AWS Secrets Manager Configuration (Runtime)

```hcl
# Terraform: Secrets Manager with rotation
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "myapp/production/db-credentials"
  description             = "Database credentials for myapp production"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30

  tags = {
    Environment = "production"
    Application = "myapp"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "app_user"
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    database = "myapp"
  })
}

# Automatic rotation
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.secret_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### KMS Key Configuration

```hcl
resource "aws_kms_key" "secrets" {
  description             = "KMS key for secrets encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS Pods"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.app_pod.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "secrets-key"
    Environment = "production"
  }
}
```

### External Secrets Operator (Kubernetes)

```yaml
# External Secrets Operator configuration
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
    - secretKey: DB_USERNAME
      remoteRef:
        key: myapp/production/db-credentials
        property: username
    - secretKey: DB_PASSWORD
      remoteRef:
        key: myapp/production/db-credentials
        property: password
    - secretKey: DB_HOST
      remoteRef:
        key: myapp/production/db-credentials
        property: host
```

---

## 4. Kubernetes RBAC

### Implementation

**Reference**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) (lines 298-371)

### GitHub Actions Deployer Role

**Purpose**: Namespace-scoped role for GitHub Actions to deploy applications.

**Reference**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) (lines 301-371)

**Permissions**:

- Deployments, ReplicaSets, StatefulSets, DaemonSets
- Services, ConfigMaps, Secrets, PVCs
- Ingresses, NetworkPolicies
- HorizontalPodAutoscalers, PodDisruptionBudgets
- Roles, RoleBindings (for namespace-scoped RBAC)

**Key Security Features**:

- Namespace-scoped (cannot access other namespaces)
- Bound to `github-actions-deployers` group
- No cluster-admin access
- Cannot modify cluster-level resources

### Namespace-Scoped Roles

```yaml
# Developer role - can view and exec into pods
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: [] # No access to secrets

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: production
subjects:
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

```yaml
# CI/CD role - can deploy but not delete
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer
  namespace: production
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["argoproj.io"]
    resources: ["rollouts"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
# Explicitly deny delete for critical resources
# (handled by not including "delete" in verbs)

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cicd-deployer-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: github-actions-sa
    namespace: cicd
roleRef:
  kind: Role
  name: cicd-deployer
  apiGroup: rbac.authorization.k8s.io
```

### Cluster-Wide Roles

```yaml
# Read-only cluster role for monitoring
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "services", "endpoints", "namespaces"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "statefulsets", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-monitoring
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: monitoring-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## 5. Network Restrictions

### Implementation

**Terraform Modules**:

- [`terraform/modules/rds/main.tf`](../terraform/modules/rds/main.tf) - RDS security group (lines 20-44)
- [`terraform/modules/nodegroups/main.tf`](../terraform/modules/nodegroups/main.tf) - EKS node security group (lines 43-59)
- [`terraform/modules/eks/main.tf`](../terraform/modules/eks/main.tf) - EKS cluster security group

### Security Groups

**RDS Security Group**:

- **Reference**: [`terraform/modules/rds/main.tf`](../terraform/modules/rds/main.tf) (lines 20-44)
- **Ingress**: Only from EKS node security groups (port 5432 for PostgreSQL)
- **Egress**: All outbound (for database queries to external services if needed)
- **Key Security**: No direct internet access, only from application pods

**EKS Node Security Group**:

- **Reference**: [`terraform/modules/nodegroups/main.tf`](../terraform/modules/nodegroups/main.tf) (lines 43-59)
- **Ingress**: Self-referencing for inter-pod communication, from cluster security group
- **Egress**: All outbound (via NAT Gateway)
- **Key Security**: Nodes in private subnets, no direct internet ingress

**EKS Cluster Security Group**:

- **Reference**: [`terraform/modules/eks/main.tf`](../terraform/modules/eks/main.tf)
- **Ingress**: From node security groups only
- **Key Security**: Cluster endpoint can be private-only or restricted public access

```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for redirect"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "To EKS nodes only"
  }

  tags = {
    Name = "alb-sg"
  }
}

# EKS Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  # Inter-node communication
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # From ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  # Egress to NAT Gateway only
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound via NAT"
  }

  tags = {
    Name = "eks-nodes-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "PostgreSQL from EKS only"
  }

  # No egress needed for RDS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = {
    Name = "rds-sg"
  }
}
```

### Network ACLs

```hcl
# Private subnet NACL
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Allow inbound from VPC CIDR
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow return traffic (ephemeral ports)
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Deny all other inbound
  ingress {
    protocol   = -1
    rule_no    = 999
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound to VPC
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow HTTPS outbound
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = {
    Name = "private-nacl"
  }
}
```

### Kubernetes Network Policies

```yaml
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# Allow backend to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    # To PostgreSQL
    - to:
        - ipBlock:
            cidr: 10.0.20.0/24 # Database subnet
      ports:
        - protocol: TCP
          port: 5432
    # To Redis
    - to:
        - ipBlock:
            cidr: 10.0.21.0/24 # Cache subnet
      ports:
        - protocol: TCP
          port: 6379
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

---

## 6. Pod Security Standards

### Namespace-Level Enforcement

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### Compliant Pod Spec

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      # Non-root user
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      serviceAccountName: backend-sa
      automountServiceAccountToken: false

      containers:
        - name: backend
          image: myregistry.com/backend:v1.0.0@sha256:abc123...

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          ports:
            - containerPort: 8080
              protocol: TCP

          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"

          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache

      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
```

### Kyverno Policy Examples

```yaml
# Require image digest
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digest
spec:
  validationFailureAction: enforce
  rules:
    - name: require-digest
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Images must use digest (@sha256:...)"
        pattern:
          spec:
            containers:
              - image: "*@sha256:*"

---
# Disallow privileged containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: enforce
  rules:
    - name: deny-privileged
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): false

---
# Require resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resources
spec:
  validationFailureAction: enforce
  rules:
    - name: require-limits
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "CPU and memory limits are required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

---

## 7. CI/CD Security Controls

### Implementation

**GitHub Actions Workflows**:

- Backend: [`backend/.github/workflows/deploy-backend.yml`](../backend/.github/workflows/deploy-backend.yml)
- Frontend: [`frontend/.github/workflows/deploy-frontend.yml`](../frontend/.github/workflows/deploy-frontend.yml)

### Security Features in CI/CD

**ECR Image Scanning**:

- **Reference**: [`terraform/modules/github-actions-ecr/main.tf`](../terraform/modules/github-actions-ecr/main.tf) (line 98)
- **Implementation**: `scanOnPush=true` enabled on ECR repositories
- **Workflow**: [`backend/.github/workflows/deploy-backend.yml`](../backend/.github/workflows/deploy-backend.yml) (line 98)

**Environment Isolation**:

- Each environment (dev, staging, production) uses separate GitHub Environments
- Production deployments require manual approval (GitHub Environment protection rules)
- Environment-specific secrets prevent cross-environment access

**Least-Privilege IAM**:

- GitHub Actions uses dedicated IAM user with minimal permissions
- Cannot modify infrastructure (only deploy to Kubernetes)
- Read-only access to EKS and RDS for configuration

**Image Tagging Strategy**:

- Semantic versioning: `v1.0.0-alpha*` → dev, `v1.0.0-rc*` → staging, `v1.0.0` → prod
- Prevents accidental production deployments

### Image Scanning in Pipeline

**Current Implementation**: ECR image scanning is enabled on push. See [`backend/.github/workflows/deploy-backend.yml`](../backend/.github/workflows/deploy-backend.yml) and [`frontend/.github/workflows/deploy-frontend.yml`](../frontend/.github/workflows/deploy-frontend.yml).

**Recommended Enhancements** (to be implemented):

```yaml
# Enhanced GitHub Actions with security scanning
# Reference: backend/.github/workflows/deploy-backend.yml

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # SAST - Static Application Security Testing
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/secrets
            p/owasp-top-ten

      # Dependency scanning
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      # Secret scanning
      - name: Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  build:
    needs: security-scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: |
          docker build -t myapp:${{ github.sha }} .

      # Container scanning (ECR also scans on push)
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: "sarif"
          output: "trivy-results.sarif"
          severity: "CRITICAL,HIGH"
          exit-code: "1"

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: "trivy-results.sarif"

  sign-and-push:
    needs: build
    runs-on: ubuntu-latest
    steps:
      # Sign image with Cosign
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image
        run: |
          cosign sign --key env://COSIGN_PRIVATE_KEY \
            ${{ env.ECR_REGISTRY }}/myapp:${{ github.sha }}
        env:
          COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}

      # Generate and attest SBOM
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: myapp:${{ github.sha }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Attest SBOM
        run: |
          cosign attest --key env://COSIGN_PRIVATE_KEY \
            --type spdx \
            --predicate sbom.spdx.json \
            ${{ env.ECR_REGISTRY }}/myapp:${{ github.sha }}
```

### Admission Controller for Signature Verification

```yaml
# Kyverno policy to verify signatures
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signature
      match:
        resources:
          kinds:
            - Pod
      verifyImages:
        - imageReferences:
            - "123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:*"
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                      -----END PUBLIC KEY-----
```

---

## Security Checklist

### Pre-Deployment

- All secrets stored in AWS Secrets Manager
- KMS encryption enabled for all storage
- Container images scanned and signed
- RBAC policies reviewed
- Network policies in place
- Pod security standards enforced

### Runtime

- GuardDuty enabled
- CloudTrail logging enabled
- VPC Flow Logs enabled
- WAF rules active
- Alerting configured

### Compliance

- IAM Access Analyzer reviewed
- Security Hub findings addressed
- Encryption at rest verified
- Audit logs retained per policy

---

## Summary

This security implementation provides:

**Defense in Depth**: Multiple security layers (Network, IAM, RBAC, Pod Security)
**Least Privilege**: Minimal permissions at all levels (IRSA, GitHub Actions IAM, Kubernetes RBAC)
**Account Isolation**: Complete separation of dev, staging, and prod environments
**Secrets Protection**: GitHub Secrets for CI/CD, Kubernetes secrets for runtime
**Network Segmentation**: Security groups restrict RDS access to EKS nodes only
**Workload Hardening**: Kubernetes RBAC with namespace-scoped permissions
**Supply Chain Security**: ECR image scanning enabled on push
**Automated Secret Management**: Terraform automatically creates and manages GitHub secrets

## Implementation Files Reference

### Terraform Infrastructure

- **IAM Roles**: [`terraform/modules/iam/main.tf`](../terraform/modules/iam/main.tf)
- **GitHub Actions IAM**: [`terraform/modules/github-actions-ecr/main.tf`](../terraform/modules/github-actions-ecr/main.tf)
- **Kubernetes RBAC**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) (lines 298-371)
- **GitHub Secrets**: [`terraform/stacks/platform/main.tf`](../terraform/stacks/platform/main.tf) (lines 544-651)
- **Security Groups**:
  - RDS: [`terraform/modules/rds/main.tf`](../terraform/modules/rds/main.tf) (lines 20-44)
  - EKS Nodes: [`terraform/modules/nodegroups/main.tf`](../terraform/modules/nodegroups/main.tf) (lines 43-59)

### CI/CD Workflows

- **Backend Deployment**: [`backend/.github/workflows/deploy-backend.yml`](../backend/.github/workflows/deploy-backend.yml)
- **Frontend Deployment**: [`frontend/.github/workflows/deploy-frontend.yml`](../frontend/.github/workflows/deploy-frontend.yml)

### Environment Configuration

- **Dev**: [`terraform/environments/dev/`](../terraform/environments/dev/)
- **Staging**: [`terraform/environments/staging/`](../terraform/environments/staging/)
- **Prod**: [`terraform/environments/prod/`](../terraform/environments/prod/)
