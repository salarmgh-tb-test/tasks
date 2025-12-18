# VPC Module

Creates a VPC with public, private, and database subnets across multiple availability zones.

## Features

- Multi-AZ VPC with configurable CIDR
- Public subnets with Internet Gateway
- Private subnets with NAT Gateway (optional single NAT for cost savings)
- Dedicated database subnets
- VPC Flow Logs to CloudWatch (optional)
- Kubernetes-aware subnet tagging for EKS

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name               = "myproject-dev"
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  region             = "eu-north-1"
  cluster_name       = "myproject-dev-eks"
  enable_nat_gateway = true
  single_nat_gateway = true  # Cost savings for dev

  enable_flow_logs         = true
  flow_logs_retention_days = 7

  tags = {
    Environment = "dev"
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for all VPC resources | `string` | n/a | yes |
| vpc_cidr | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| az_count | Number of availability zones to use | `number` | `3` | no |
| region | AWS region | `string` | n/a | yes |
| cluster_name | Name of the EKS cluster (for tagging) | `string` | `""` | no |
| enable_nat_gateway | Enable NAT Gateway for private subnets | `bool` | `true` | no |
| single_nat_gateway | Use a single NAT Gateway (cost savings) | `bool` | `false` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `false` | no |
| flow_logs_retention_days | VPC Flow Logs retention period in days | `number` | `7` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| vpc_cidr_block | CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| database_subnet_ids | List of database subnet IDs |
| nat_gateway_ids | Map of NAT Gateway IDs by AZ |
| availability_zones | List of availability zones used |

