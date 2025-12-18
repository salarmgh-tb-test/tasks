#--------------------------------------------------------------
# DB Subnet Group
#--------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

#--------------------------------------------------------------
# Security Group
#--------------------------------------------------------------
locals {
  db_port = var.engine == "postgres" ? 5432 : 3306
}

resource "aws_security_group" "rds" {
  name        = "${var.identifier}-sg"
  description = "Security group for RDS instance ${var.identifier}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "${var.engine} access from allowed security groups"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

#--------------------------------------------------------------
# RDS Instance
#--------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = var.identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted      = var.storage_encrypted

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible

  multi_az               = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # CloudWatch Logs Export
  enabled_cloudwatch_logs_exports = var.cloudwatch_log_exports

  # Enhanced Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 && var.monitoring_role_arn == null ? aws_iam_role.rds_monitoring[0].arn : var.monitoring_role_arn

  tags = merge(var.tags, {
    Name = var.identifier
  })

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) >= 2
      error_message = "RDS requires at least 2 subnets in different availability zones for the DB subnet group."
    }
    precondition {
      condition     = var.master_password != ""
      error_message = "Database master_password must be provided."
    }
    precondition {
      condition     = length(var.master_password) >= 8
      error_message = "Database master_password must be at least 8 characters."
    }
  }
}

#--------------------------------------------------------------
# IAM Role for Enhanced Monitoring
#--------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 && var.monitoring_role_arn == null ? 1 : 0

  name = "${var.identifier}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 && var.monitoring_role_arn == null ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

