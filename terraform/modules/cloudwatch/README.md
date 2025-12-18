# CloudWatch Module

Creates CloudWatch log groups, alarms, SNS topics, and dashboards for infrastructure monitoring.

## Features

- Application and EKS log groups with configurable retention
- SNS topics for standard and critical alerts
- EKS cluster alarms (CPU, memory, pod restarts)
- RDS alarms (CPU, connections, storage, latency)
- ALB alarms (5xx errors, response time, unhealthy targets)
- NAT Gateway connection alarms
- CloudWatch dashboard with infrastructure overview

## Usage

```hcl
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment  = "dev"
  cluster_name = module.eks.cluster_name
  region       = var.region

  log_retention_days = 7

  application_log_groups = {
    frontend = "Frontend application logs"
    backend  = "Backend application logs"
  }

  alert_email_endpoints = {
    "ops@example.com" = "critical"
    "dev@example.com" = "standard"
  }

  enable_eks_alarms = true
  enable_rds_alarms = true
  enable_alb_alarms = true

  rds_instance_id = module.rds.db_instance_identifier
  alb_arn_suffix  = module.ingress.alb_arn_suffix
  nat_gateway_ids = module.vpc.nat_gateway_ids

  create_dashboard = true

  tags = {
    Environment = "dev"
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | `string` | n/a | yes |
| cluster_name | EKS cluster name | `string` | `""` | no |
| region | AWS region | `string` | n/a | yes |
| log_retention_days | CloudWatch log retention in days | `number` | `7` | no |
| application_log_groups | Map of application log groups | `map(string)` | `{}` | no |
| eks_application_log_groups | Map of EKS application log groups | `map(string)` | `{}` | no |
| alert_email_endpoints | Map of email addresses for alerts | `map(string)` | `{}` | no |
| enable_eks_alarms | Enable EKS CloudWatch alarms | `bool` | `true` | no |
| enable_rds_alarms | Enable RDS CloudWatch alarms | `bool` | `true` | no |
| enable_alb_alarms | Enable ALB CloudWatch alarms | `bool` | `true` | no |
| enable_nat_gateway_alarms | Enable NAT Gateway alarms | `bool` | `false` | no |
| rds_instance_id | RDS instance identifier for alarms | `string` | `""` | no |
| alb_arn_suffix | ALB ARN suffix for metrics | `string` | `""` | no |
| nat_gateway_ids | Map of NAT Gateway IDs | `map(string)` | `{}` | no |
| create_dashboard | Create CloudWatch dashboard | `bool` | `true` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cloudwatch_alarms_topic_arn | SNS topic ARN for standard alarms |
| critical_alarms_topic_arn | SNS topic ARN for critical alarms |
| dashboard_name | CloudWatch dashboard name |
| app_log_group_names | Map of application log group names |
| eks_app_log_group_names | Map of EKS application log group names |

