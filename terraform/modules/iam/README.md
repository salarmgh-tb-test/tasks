# IAM Module

Creates IAM roles for Kubernetes service accounts using IRSA (IAM Roles for Service Accounts).

## Features

- Cluster Autoscaler IAM role
- AWS Load Balancer Controller IAM role
- External DNS IAM role
- Generic IRSA roles for application pods
- Least-privilege policies with resource scoping

## Usage

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
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| oidc_provider_arn | ARN of the OIDC provider | `string` | n/a | yes |
| oidc_provider_url | URL of the OIDC provider | `string` | n/a | yes |
| enable_cluster_autoscaler | Create IAM role for Cluster Autoscaler | `bool` | `true` | no |
| enable_load_balancer_controller | Create IAM role for AWS Load Balancer Controller | `bool` | `true` | no |
| enable_external_dns | Create IAM role for External DNS | `bool` | `false` | no |
| service_accounts | Map of service accounts to create IRSA roles for | `map(object)` | `{}` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_autoscaler_role_arn | IAM role ARN for Cluster Autoscaler |
| load_balancer_controller_role_arn | IAM role ARN for AWS Load Balancer Controller |
| external_dns_role_arn | IAM role ARN for External DNS |
| app_role_arns | Map of application service account role ARNs |

