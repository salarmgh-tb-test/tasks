# Platform Stack Module

This is a shared infrastructure stack module that deploys a complete AWS platform including VPC, EKS, RDS, monitoring, and CI/CD integration.

## Features

- **VPC**: Multi-AZ VPC with public, private, and database subnets
- **EKS**: Managed Kubernetes cluster with node groups
- **RDS**: PostgreSQL database with encryption and monitoring
- **IAM**: IRSA roles for Kubernetes service accounts
- **Monitoring**: Prometheus, Grafana, Tempo, Loki, OpenTelemetry
- **CloudWatch**: Alarms, dashboards, and log groups
- **GitHub Actions**: Automated secrets management for CI/CD

## Usage

```hcl
module "platform" {
  source = "../../stacks/platform"

  # Core Configuration
  project     = "myproject"
  environment = "dev"
  region      = "eu-north-1"

  # Cost Allocation
  cost_center      = "engineering"
  application_name = "myapp"

  # Admin Access (usernames only - ARNs constructed dynamically)
  admin_usernames = ["admin-user"]

  # VPC
  vpc_cidr   = "10.0.0.0/16"
  az_count   = 2

  # EKS
  cluster_version     = "1.34"
  enable_public_access = true
  public_access_cidrs  = ["1.2.3.4/32"]  # Your IP/VPN CIDR

  # RDS
  db_engine    = "postgres"
  db_password  = var.db_password  # From env var or GitHub secret

  # GitHub Integration
  github_owner      = "my-org"
  github_repository = "backend"

  providers = {
    github          = github
    github.frontend = github.frontend
  }
}
```

## Dynamic Values

The following values are automatically generated:

| Value | Format | Example |
|-------|--------|---------|
| S3 bucket (Tempo) | `tempo-traces-{env}-{account_id}` | `tempo-traces-dev-123456789012` |
| S3 bucket (Loki chunks) | `loki-chunks-{env}-{account_id}` | `loki-chunks-dev-123456789012` |
| S3 bucket (Loki ruler) | `loki-ruler-{env}-{account_id}` | `loki-ruler-dev-123456789012` |
| Admin user ARNs | `arn:aws:iam::{account_id}:user/{username}` | Auto-constructed from usernames |
| IRSA policies | Dynamic resource ARNs | Uses account ID from data source |

## Sensitive Values

The following sensitive values should be provided via environment variables:

```bash
# Database password
export TF_VAR_db_password="your-secure-password"

# Grafana admin password
export TF_VAR_grafana_admin_password="your-grafana-password"

# GitHub tokens
export TF_VAR_github_backend_token="ghp_xxx"
export TF_VAR_github_frontend_token="ghp_xxx"
```

Or store them in GitHub Secrets and they will be read automatically.

## Security Features

- **No hardcoded account IDs**: All AWS account IDs are retrieved dynamically
- **No hardcoded passwords**: Passwords provided via env vars or GitHub secrets
- **S3 public access blocked**: All S3 buckets have public access blocked
- **IMDSv2 enforced**: Node groups require IMDSv2 tokens
- **EBS encryption**: All node volumes are encrypted
- **VPC Flow Logs**: Enabled by default for network auditing
- **Scoped IAM policies**: Least-privilege IAM policies with resource constraints

## Cost Allocation Tags

All resources are tagged with:

| Tag | Description |
|-----|-------------|
| `Project` | Project name |
| `Environment` | Environment (dev/staging/prod) |
| `ManagedBy` | Always "terraform" |
| `CostCenter` | Cost center for billing |
| `Application` | Application name |

## Outputs

The module exports all necessary values for connecting to and managing the infrastructure:

- VPC IDs and subnet IDs
- EKS cluster endpoint and credentials
- RDS connection details
- IAM role ARNs
- Monitoring endpoints
- GitHub secrets status

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0, < 2.0.0 |
| aws | ~> 5.0 |
| kubernetes | ~> 2.23 |
| helm | ~> 2.12 |
| github | ~> 6.0 |
| tls | ~> 4.0 |

