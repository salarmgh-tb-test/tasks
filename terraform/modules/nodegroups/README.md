# Node Groups Module

Creates EKS managed node groups with IAM roles and security groups.

## Features

- Multiple node group configurations via map
- Configurable instance types and capacity type (ON_DEMAND/SPOT)
- Custom AMI type support (AL2023, Bottlerocket, etc.)
- Launch template with encrypted EBS volumes
- IMDSv2 enforced for security
- Node labels and taints support
- Auto-scaling configuration
- SSM access for debugging

## Usage

```hcl
module "nodegroups" {
  source = "../../modules/nodegroups"

  cluster_name              = module.eks.cluster_name
  cluster_security_group_id = module.eks.cluster_security_group_id
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids

  node_groups = {
    general = {
      instance_types = ["m7i-flex.large"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 50
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      labels = {
        role = "general"
      }
      taints = []
    }
    spot = {
      instance_types = ["m7i-flex.large", "m6i.large"]
      capacity_type  = "SPOT"
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 50
      desired_size   = 2
      min_size       = 0
      max_size       = 10
      labels = {
        role = "spot"
      }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Environment = "dev"
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| cluster_security_group_id | Security group ID of the EKS cluster | `string` | n/a | yes |
| vpc_id | ID of the VPC | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for node groups | `list(string)` | n/a | yes |
| node_groups | Map of node group configurations | `map(object)` | See variables.tf | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| node_security_group_id | Security group ID for the node groups |
| node_role_arn | IAM role ARN for the node groups |
| node_group_arns | ARNs of the EKS node groups |
| node_group_statuses | Status of the EKS node groups |

