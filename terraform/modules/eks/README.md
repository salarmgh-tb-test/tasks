# EKS Module

Creates an Amazon EKS cluster with OIDC provider for IRSA and core add-ons.

## Features

- EKS cluster with configurable Kubernetes version
- OIDC provider for IAM Roles for Service Accounts (IRSA)
- VPC CNI and kube-proxy add-ons
- EBS CSI driver IAM role (addon created at environment level)
- Configurable API endpoint access (public/private)
- Control plane logging to CloudWatch

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name            = "myproject-dev-eks"
  cluster_version         = "1.34"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"]
  enable_ebs_csi_driver   = true

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
| cluster_version | Kubernetes version for the cluster | `string` | `"1.34"` | no |
| vpc_id | ID of the VPC | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for the EKS cluster | `list(string)` | n/a | yes |
| endpoint_private_access | Enable private API server endpoint | `bool` | `true` | no |
| endpoint_public_access | Enable public API server endpoint | `bool` | `true` | no |
| public_access_cidrs | CIDR blocks allowed to access public endpoint | `list(string)` | `["0.0.0.0/0"]` | no |
| enabled_log_types | List of control plane log types to enable | `list(string)` | `["api", "audit", "authenticator", "controllerManager", "scheduler"]` | no |
| enable_ebs_csi_driver | Enable EBS CSI driver add-on | `bool` | `true` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_arn | EKS cluster ARN |
| cluster_name | EKS cluster name |
| cluster_endpoint | EKS cluster API endpoint |
| cluster_certificate_authority_data | Base64 encoded certificate data |
| cluster_security_group_id | Security group ID for the cluster |
| cluster_oidc_issuer_url | OIDC issuer URL |
| oidc_provider_arn | ARN of the OIDC provider |
| cluster_version | Kubernetes version |
| ebs_csi_role_arn | IAM role ARN for EBS CSI driver |

