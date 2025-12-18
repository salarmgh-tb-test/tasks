# RDS Module

Creates an Amazon RDS database instance with security group and subnet group.

## Features

- PostgreSQL or MySQL database engine
- Configurable instance class and storage
- Multi-AZ deployment support
- Automated backups with configurable retention
- Performance Insights and Enhanced Monitoring
- CloudWatch log exports
- Storage encryption enabled by default
- Security group with allowed source security groups

## Usage

```hcl
module "rds" {
  source = "../../modules/rds"

  identifier                 = "myproject-dev-db"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.database_subnet_ids
  allowed_security_group_ids = [module.nodegroups.node_security_group_id]

  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  database_name           = "appdb"
  master_username         = "dbadmin"
  master_password         = var.db_password
  multi_az                = false
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  performance_insights_enabled = true
  monitoring_interval          = 60

  tags = {
    Environment = "dev"
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| identifier | Identifier for the RDS instance | `string` | n/a | yes |
| vpc_id | ID of the VPC | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for the DB subnet group | `list(string)` | n/a | yes |
| allowed_security_group_ids | List of security group IDs allowed to access RDS | `list(string)` | n/a | yes |
| engine | Database engine (postgres or mysql) | `string` | `"postgres"` | no |
| engine_version | Database engine version | `string` | `"15.4"` | no |
| instance_class | RDS instance class | `string` | `"db.t3.micro"` | no |
| allocated_storage | Allocated storage in GB | `number` | `20` | no |
| max_allocated_storage | Maximum allocated storage for autoscaling | `number` | `100` | no |
| database_name | Name of the database | `string` | n/a | yes |
| master_username | Master username | `string` | n/a | yes |
| master_password | Master password | `string` | n/a | yes |
| multi_az | Enable Multi-AZ deployment | `bool` | `false` | no |
| backup_retention_period | Backup retention period in days | `number` | `7` | no |
| deletion_protection | Enable deletion protection | `bool` | `false` | no |
| skip_final_snapshot | Skip final snapshot on deletion | `bool` | `false` | no |
| storage_encrypted | Enable storage encryption | `bool` | `true` | no |
| performance_insights_enabled | Enable Performance Insights | `bool` | `false` | no |
| monitoring_interval | Enhanced Monitoring interval in seconds | `number` | `0` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| db_instance_id | RDS instance ID |
| db_instance_identifier | RDS instance identifier |
| db_instance_endpoint | RDS instance endpoint |
| db_instance_address | RDS instance address |
| db_instance_port | RDS instance port |
| db_instance_arn | RDS instance ARN |
| db_instance_name | RDS database name |
| security_group_id | RDS security group ID |

