# Task C1 - Create Terraform for AWS

## Problem Statement

Deliver Terraform modules for AWS infrastructure:

- VPC with public, private, and database subnets
- EKS cluster with managed node groups
- IAM roles with IRSA support
- RDS PostgreSQL database
- Remote state configuration with S3 and DynamoDB

## Approach

1. **Modular Architecture**: Small, focused modules composed in stacks
2. **Input Validation**: Preconditions and validations for critical inputs
3. **Environment Isolation**: Separate workspaces per environment (dev, staging, prod)
4. **Remote State**: S3 backend with DynamoDB locking for team collaboration

## Solution

### Module Structure

```
terraform/
├── modules/
│   ├── vpc/              # VPC, subnets, NAT gateways
│   ├── eks/              # EKS cluster, OIDC, addons
│   ├── nodegroups/       # Managed node groups
│   ├── iam/              # IRSA roles for controllers
│   ├── rds/              # RDS PostgreSQL
│   ├── monitoring/       # Prometheus, Grafana, Loki, Tempo
│   ├── cloudwatch/       # Alarms and dashboards
│   └── github-actions-ecr/  # CI/CD IAM user
├── stacks/
│   └── platform/         # Composed infrastructure stack
└── environments/
    ├── dev/              # Development workspace
    ├── staging/          # Staging workspace
    └── prod/             # Production workspace
```

---

## Module 1: VPC (`terraform/modules/vpc/`)

### Purpose

Creates a VPC with multi-AZ subnets, NAT gateways, and VPC flow logs.

### Resources Created

- VPC with DNS support
- Public subnets (with IGW route)
- Private subnets (with NAT route)
- Database subnets (isolated)
- Internet Gateway
- NAT Gateways (single or per-AZ)
- Route tables and associations
- VPC Flow Logs (optional)

### Variables

```hcl
variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "AZ count must be between 1 and 6."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost savings for non-prod)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}
```

### Outputs

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = [for subnet in aws_subnet.database : subnet.id]
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}
```

### Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name               = "tradebytes-dev"
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 2
  region             = "eu-north-1"
  cluster_name       = "tradebytes-dev-eks"
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost optimization for dev

  tags = {
    Environment = "dev"
    Project     = "tradebytes"
  }
}
```

---

## Module 2: EKS (`terraform/modules/eks/`)

### Purpose

Creates an EKS cluster with OIDC provider for IRSA and core addons.

### Resources Created

- EKS Cluster
- Cluster IAM role
- Cluster security group
- OIDC provider for IRSA
- VPC CNI addon
- kube-proxy addon
- EBS CSI driver IAM role

### Variables

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "1.31"

  validation {
    condition     = can(regex("^1\\.(2[5-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.25 or higher."
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least 1 subnet is required (use 2+ for production)."
  }
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access public endpoint"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All public_access_cidrs must be valid CIDR blocks."
  }
}
```

### Outputs

```hcl
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID for the cluster"
  value       = aws_security_group.cluster.id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}
```

### Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name            = "tradebytes-dev-eks"
  cluster_version         = "1.31"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  enable_ebs_csi_driver   = true

  tags = {
    Environment = "dev"
    Project     = "tradebytes"
  }
}
```

---

## Module 3: Node Groups (`terraform/modules/nodegroups/`)

### Purpose

Creates managed node groups with launch templates and security groups.

### Resources Created

- Node IAM role with managed policies
- Node security group
- Launch templates (encrypted EBS, IMDSv2)
- EKS managed node groups

### Variables

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for node groups"
  type        = list(string)
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    ami_type       = string
    disk_size      = number
    desired_size   = number
    min_size       = number
    max_size       = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}
```

### Outputs

```hcl
output "node_group_arns" {
  description = "ARNs of the node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.arn }
}

output "node_security_group_id" {
  description = "Security group ID for the node groups"
  value       = aws_security_group.node.id
}

output "node_role_arn" {
  description = "IAM role ARN for the nodes"
  value       = aws_iam_role.node.arn
}
```

### Usage

```hcl
module "nodegroups" {
  source = "../../modules/nodegroups"

  cluster_name              = module.eks.cluster_name
  cluster_security_group_id = module.eks.cluster_security_group_id
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2_x86_64"
      disk_size      = 50
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      labels         = { workload = "general" }
      taints         = []
    }
  }

  tags = {
    Environment = "dev"
    Project     = "tradebytes"
  }
}
```

---

## Module 4: IAM (`terraform/modules/iam/`)

### Purpose

Creates IRSA roles for Kubernetes controllers and application pods.

### Resources Created

- Cluster Autoscaler IAM role
- AWS Load Balancer Controller IAM role
- External DNS IAM role (optional)
- Application IRSA roles

### Variables

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]+:oidc-provider/", var.oidc_provider_arn))
    error_message = "OIDC provider ARN must be a valid IAM OIDC provider ARN."
  }
}

variable "enable_cluster_autoscaler" {
  description = "Create IAM role for Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_load_balancer_controller" {
  description = "Create IAM role for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "service_accounts" {
  description = "Map of service accounts to create IRSA roles for"
  type = map(object({
    namespace       = string
    service_account = string
    policy_json     = string
  }))
  default = {}
}
```

### Outputs

```hcl
output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_load_balancer_controller ? aws_iam_role.load_balancer_controller[0].arn : null
}

output "app_role_arns" {
  description = "Map of application IRSA role ARNs"
  value       = { for k, v in aws_iam_role.app : k => v.arn }
}
```

### Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url

  enable_cluster_autoscaler       = true
  enable_load_balancer_controller = true
  enable_external_dns             = false

  service_accounts = {
    backend = {
      namespace       = "production"
      service_account = "backend-sa"
      policy_json     = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject"]
          Resource = "arn:aws:s3:::my-bucket/*"
        }]
      })
    }
  }

  tags = {
    Environment = "dev"
    Project     = "tradebytes"
  }
}
```

---

## Module 5: RDS (`terraform/modules/rds/`)

### Purpose

Creates an RDS PostgreSQL instance with security group and monitoring.

### Resources Created

- DB subnet group
- Security group (restricted to EKS nodes)
- RDS instance
- Enhanced monitoring IAM role (optional)

### Variables

```hcl
variable "identifier" {
  description = "Identifier for the RDS instance"
  type        = string
}

variable "engine" {
  description = "Database engine (postgres or mysql)"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "Engine must be 'postgres' or 'mysql'."
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "Instance class for the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GB."
  }
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to access RDS"
  type        = list(string)
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
}

variable "master_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}
```

### Outputs

```hcl
output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}
```

### Usage

```hcl
module "rds" {
  source = "../../modules/rds"

  identifier     = "tradebytes-dev-db"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  multi_az              = false  # Enable for production

  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  allowed_security_group_ids = [module.nodegroups.node_security_group_id]

  database_name   = "tradebytes"
  master_username = "postgres"
  master_password = var.db_password

  backup_retention_period      = 7
  performance_insights_enabled = true

  tags = {
    Environment = "dev"
    Project     = "tradebytes"
  }
}
```

---

## Remote State Configuration

### Backend Setup Script (`setup-backend.sh`)

```bash
#!/bin/bash
set -e

ENVIRONMENT="${1:-dev}"
REGION="eu-north-1"
BUCKET_NAME="tradebytes-terraform-state-${ENVIRONMENT}"
DYNAMODB_TABLE="terraform-state-lock"

echo "Creating S3 bucket: ${BUCKET_NAME}"
aws s3 mb "s3://${BUCKET_NAME}" --region "${REGION}" 2>/dev/null || true

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "Creating DynamoDB table: ${DYNAMODB_TABLE}"
aws dynamodb create-table \
  --table-name "${DYNAMODB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" 2>/dev/null || true

echo "Backend setup complete!"
```

### Backend Configuration (`backend.tf`)

```hcl
terraform {
  backend "s3" {
    bucket         = "tradebytes-terraform-state-dev"
    key            = "environments/dev/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

---

## Environment Workspaces

### Development (`terraform/environments/dev/`)

```hcl
# main.tf
module "platform" {
  source = "../../stacks/platform"

  project     = "tradebytes"
  environment = "dev"
  region      = "eu-north-1"

  # VPC Configuration
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 2
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost savings

  # EKS Configuration
  cluster_version    = "1.31"
  enable_public_access = true

  # Node Groups
  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      desired_size   = 2
      min_size       = 1
      max_size       = 5
    }
  }

  # RDS Configuration
  db_instance_class = "db.t3.micro"
  db_multi_az       = false
  db_password       = var.db_password
}
```

### Production (`terraform/environments/prod/`)

```hcl
# main.tf
module "platform" {
  source = "../../stacks/platform"

  project     = "tradebytes"
  environment = "prod"
  region      = "eu-north-1"

  # VPC Configuration
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 2
  enable_nat_gateway = true
  single_nat_gateway = false  # HA: NAT per AZ

  # EKS Configuration
  cluster_version      = "1.31"
  enable_public_access = false  # Private only

  # Node Groups
  node_groups = {
    general = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 3
      min_size       = 2
      max_size       = 10
    }
  }

  # RDS Configuration
  db_instance_class = "db.t3.medium"
  db_multi_az       = true  # High availability
  db_password       = var.db_password
}
```

---

## Deployment Instructions

### Prerequisites

```bash
# Install Terraform 1.5+
brew install terraform

# Configure AWS credentials
aws configure --profile tradebytes-dev
export AWS_PROFILE=tradebytes-dev
```

### Initial Setup

```bash
# Navigate to environment
cd terraform/environments/dev

# Setup remote state backend
./setup-backend.sh dev

# Initialize Terraform
terraform init

# Review plan
terraform plan -var="db_password=YOUR_PASSWORD"

# Apply infrastructure
terraform apply -var="db_password=YOUR_PASSWORD"
```

### Environment Variables

```bash
# Required variables (use environment variables for secrets)
export TF_VAR_db_password="secure-password-here"
export TF_VAR_grafana_admin_password="admin-password"

# Optional: GitHub integration
export TF_VAR_github_owner="your-org"
export TF_VAR_github_repository="backend"
export TF_VAR_github_token="ghp_xxxx"
```

---

## Result

### Modules Delivered

| Module        | Resources                     | Lines of Code |
| ------------- | ----------------------------- | ------------- |
| `vpc/`        | VPC, subnets, NAT, flow logs  | ~300          |
| `eks/`        | Cluster, OIDC, addons         | ~180          |
| `nodegroups/` | Node groups, launch templates | ~210          |
| `iam/`        | IRSA roles for controllers    | ~460          |
| `rds/`        | RDS instance, security groups | ~140          |

### Validation Features

- Input validation on all critical variables
- Preconditions for resource dependencies
- Type constraints for complex objects
- Sensitive variable marking

### Outputs Provided

- VPC IDs and subnet lists
- EKS cluster endpoint and credentials
- Node group ARNs and security groups
- IAM role ARNs for IRSA
- RDS endpoint and connection details

---

## Risks & Mitigations

| Risk             | Mitigation                                                   |
| ---------------- | ------------------------------------------------------------ |
| State corruption | Remote state with S3 versioning, DynamoDB locking            |
| Secret exposure  | Use `TF_VAR_*` env vars, never commit `.tfvars` with secrets |
| Breaking changes | Pin module versions, test in dev first                       |
| Cost overrun     | Single NAT Gateway in dev, reserved instances in prod        |

---

## Future Improvements

- [ ] Add Terratest for automated module testing
- [ ] Implement `moved` blocks for safe refactoring
- [ ] Create module registry for organization sharing
- [ ] Add drift detection with scheduled plans
- [ ] Enable AWS Backup for centralized backup management

---

## File Reference

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf          # VPC resources
│   │   ├── variables.tf     # Input variables with validation
│   │   ├── outputs.tf       # Module outputs
│   │   └── README.md        # Module documentation
│   ├── eks/
│   │   ├── main.tf          # EKS cluster, OIDC, addons
│   │   ├── variables.tf     # Input variables
│   │   ├── outputs.tf       # Cluster outputs
│   │   └── README.md
│   ├── nodegroups/
│   │   ├── main.tf          # Node groups, launch templates
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── iam/
│   │   ├── main.tf          # IRSA roles
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── rds/
│       ├── main.tf          # RDS instance
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── stacks/
│   └── platform/
│       ├── main.tf          # Composed stack
│       ├── variables.tf     # Stack variables
│       ├── outputs.tf       # Stack outputs
│       └── README.md
└── environments/
    ├── dev/
    │   ├── main.tf          # Dev configuration
    │   ├── backend.tf       # Remote state config
    │   ├── variables.tf     # Environment variables
    │   ├── outputs.tf       # Environment outputs
    │   ├── terraform.tfvars # Non-sensitive defaults
    │   └── setup-backend.sh # Backend setup script
    ├── staging/
    │   └── ...              # Similar structure
    └── prod/
        └── ...              # Similar structure
```
