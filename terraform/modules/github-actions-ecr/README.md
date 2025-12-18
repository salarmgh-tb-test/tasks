# GitHub Actions ECR Module

Creates an IAM user with minimal permissions for GitHub Actions CI/CD to push/pull Docker images to Amazon ECR.

## Features

- IAM user with least-privilege ECR access
- Optional EKS access for kubectl/helm deployments
- Optional RDS access for database information
- Automatic access key generation
- Scoped permissions to specific ECR repositories

## Usage

```hcl
module "github_actions_ecr" {
  source = "../../modules/github-actions-ecr"

  user_name         = "github-actions-ecr-dev"
  aws_region        = var.region
  ecr_repositories  = ["backend", "frontend"]
  create_access_key = true

  enable_eks_access = true
  eks_cluster_arns  = [module.eks.cluster_arn]

  enable_rds_access = true
  rds_instance_arns = [module.rds.db_instance_arn]

  tags = {
    Environment = "dev"
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| user_name | IAM user name | `string` | n/a | yes |
| user_path | IAM user path | `string` | `"/"` | no |
| aws_region | AWS region | `string` | n/a | yes |
| ecr_repositories | List of ECR repository names | `list(string)` | n/a | yes |
| create_access_key | Create access key for the user | `bool` | `true` | no |
| enable_eks_access | Enable EKS describe cluster access | `bool` | `false` | no |
| eks_cluster_arns | List of EKS cluster ARNs | `list(string)` | `[]` | no |
| enable_rds_access | Enable RDS describe access | `bool` | `false` | no |
| rds_instance_arns | List of RDS instance ARNs | `list(string)` | `[]` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| user_name | IAM user name |
| user_arn | IAM user ARN |
| access_key_id | Access key ID (if created) |
| secret_access_key | Secret access key (sensitive, if created) |
| ecr_registry_url | ECR registry URL |

## GitHub Actions Usage

Add the outputs as GitHub Secrets:

```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: eu-north-1
```

Then in your workflow:

```yaml
- name: Login to Amazon ECR
  uses: aws-actions/amazon-ecr-login@v2

- name: Build and push
  run: |
    docker build -t $ECR_REGISTRY/backend:$IMAGE_TAG .
    docker push $ECR_REGISTRY/backend:$IMAGE_TAG
```

