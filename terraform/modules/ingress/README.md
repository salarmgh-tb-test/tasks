# Ingress Module

Deploys the AWS Load Balancer Controller using Helm for managing ALB/NLB resources.

## Features

- AWS Load Balancer Controller via Helm
- Automatic CRD installation
- IngressClass resource management
- IRSA integration for AWS API access
- Configurable replicas with PodDisruptionBudget
- Resource requests/limits configuration

## Usage

```hcl
module "ingress" {
  source = "../../modules/ingress"

  enabled      = true
  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id
  iam_role_arn = module.iam.load_balancer_controller_role_arn
  aws_region   = var.region

  ingress_class            = "alb"
  create_ingress_class     = true
  set_as_default_ingress_class = true
  replicas                 = 2

  depends_on = [module.nodegroups]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| enabled | Whether to enable the ingress controller | `bool` | `true` | no |
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| vpc_id | VPC ID where the EKS cluster is deployed | `string` | n/a | yes |
| iam_role_arn | IAM role ARN for the controller (IRSA) | `string` | n/a | yes |
| aws_region | AWS region | `string` | `"eu-north-1"` | no |
| namespace | Kubernetes namespace | `string` | `"kube-system"` | no |
| ingress_class | Ingress class name | `string` | `"alb"` | no |
| create_ingress_class | Whether to create the IngressClass resource | `bool` | `true` | no |
| set_as_default_ingress_class | Whether to set this as the default ingress class | `bool` | `false` | no |
| replicas | Number of controller replicas | `number` | `2` | no |
| helm_chart_version | Helm chart version | `string` | `"1.16.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where the controller is deployed |
| service_account_name | Name of the service account |
| release_name | Name of the Helm release |
| ingress_class | Ingress class name |
| alb_arn_suffix | ALB ARN suffix for CloudWatch metrics |

