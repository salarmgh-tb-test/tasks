# Task B2 - Fix AWS Infrastructure Issues

## Problem Statement

Solve five AWS infrastructure scenarios:

1. Internet access from private EC2
2. S3 AccessDenied on uploads
3. Lambda cannot reach RDS
4. App loses DB during ASG scale events
5. CloudWatch not collecting logs

---

## Scenario 1: Internet Access from Private EC2

### Problem

EC2 instances in private subnets cannot access the internet for package updates, API calls, etc.

### Troubleshooting Steps

```bash
# 1. Verify instance is in private subnet
aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[].Instances[].SubnetId'

# 2. Check subnet route table
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# 3. Verify NAT Gateway exists and is available
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxxxx"

# 4. Check Security Group outbound rules
aws ec2 describe-security-groups --group-ids sg-xxxxx \
  --query 'SecurityGroups[].IpPermissionsEgress'

# 5. Test connectivity from instance
ping 8.8.8.8
curl -v https://aws.amazon.com
```

### Root Cause Analysis

| Cause                        | Indicator                     | Fix                  |
| ---------------------------- | ----------------------------- | -------------------- |
| Missing NAT Gateway          | No NAT GW in VPC              | Create NAT Gateway   |
| Route table misconfigured    | No 0.0.0.0/0 → NAT GW route   | Add default route    |
| NAT GW not in route table    | Wrong route table association | Associate correct RT |
| Security Group blocks egress | No outbound rules             | Add outbound rules   |
| NACL blocks traffic          | Deny rules on subnet          | Update NACL rules    |

### Solution

**Option A: Create NAT Gateway (Recommended for Production)**

```bash
# 1. Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# 2. Create NAT Gateway in public subnet
aws ec2 create-nat-gateway \
  --subnet-id subnet-public-xxxxx \
  --allocation-id eipalloc-xxxxx

# 3. Wait for NAT Gateway to become available
aws ec2 wait nat-gateway-available --nat-gateway-ids nat-xxxxx

# 4. Add route to private subnet route table
aws ec2 create-route \
  --route-table-id rtb-private-xxxxx \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-xxxxx
```

**Option B: Terraform Configuration**

```hcl
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "nat-gateway-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "main-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}
```

**Security Group Fix (if needed):**

```bash
# Allow all outbound traffic (common default)
aws ec2 authorize-security-group-egress \
  --group-id sg-xxxxx \
  --protocol all \
  --cidr 0.0.0.0/0
```

---

## Scenario 2: S3 AccessDenied on Uploads

### Problem

Application receives "AccessDenied" when uploading files to S3.

### Troubleshooting Steps

```bash
# 1. Test with AWS CLI using same credentials
aws s3 cp test.txt s3://my-bucket/test.txt

# 2. Check bucket policy
aws s3api get-bucket-policy --bucket my-bucket

# 3. Check IAM policy attached to role/user
aws iam get-role-policy --role-name app-role --policy-name app-policy
aws iam list-attached-role-policies --role-name app-role

# 4. Check bucket ACL
aws s3api get-bucket-acl --bucket my-bucket

# 5. Check for S3 Block Public Access settings
aws s3api get-public-access-block --bucket my-bucket

# 6. Check if bucket encryption requires specific KMS key
aws s3api get-bucket-encryption --bucket my-bucket

# 7. Use policy simulator
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/app-role \
  --action-names s3:PutObject \
  --resource-arns arn:aws:s3:::my-bucket/*
```

### Root Cause Analysis

| Cause                           | Indicator                      | Fix                      |
| ------------------------------- | ------------------------------ | ------------------------ |
| IAM policy missing s3:PutObject | No permission in policy        | Add PutObject permission |
| Bucket policy denies            | Explicit deny in bucket policy | Update bucket policy     |
| Wrong bucket or path            | Resource ARN mismatch          | Correct ARN in policy    |
| KMS key access denied           | Encryption enabled             | Add kms:GenerateDataKey  |
| Object ownership/ACL            | ACL-related error              | Update object ownership  |
| VPC Endpoint policy             | Policy blocks access           | Update VPCe policy       |

### Solution

**Fix IAM Role Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Upload",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

**Fix with KMS Encryption:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Upload",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::my-bucket/*"
    },
    {
      "Sid": "AllowKMSForS3",
      "Effect": "Allow",
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "arn:aws:kms:us-east-1:123456789012:key/key-id",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.us-east-1.amazonaws.com"
        }
      }
    }
  ]
}
```

**Fix Bucket Policy (if bucket policy is blocking):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAppRoleAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/app-role"
      },
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

**Terraform:**

```hcl
resource "aws_iam_role_policy" "s3_access" {
  name = "s3-upload-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      }
    ]
  })
}
```

---

## Scenario 3: Lambda Cannot Reach RDS

### Problem

Lambda function times out or fails when connecting to RDS database.

### Troubleshooting Steps

```bash
# 1. Check Lambda VPC configuration
aws lambda get-function-configuration --function-name my-function \
  --query 'VpcConfig'

# 2. Verify Lambda is in the same VPC as RDS
aws rds describe-db-instances --db-instance-identifier my-db \
  --query 'DBInstances[].VpcSecurityGroups'

# 3. Check Security Groups
# Lambda SG outbound → RDS SG inbound (port 5432/3306)

# 4. Check RDS endpoint and port
aws rds describe-db-instances --db-instance-identifier my-db \
  --query 'DBInstances[].[Endpoint.Address,Endpoint.Port]'

# 5. Check Lambda execution role has VPC permissions
aws iam list-attached-role-policies --role-name lambda-role

# 6. Check subnet routing
# Private subnets need NAT GW for external calls
```

### Root Cause Analysis

| Cause                   | Indicator                    | Fix                       |
| ----------------------- | ---------------------------- | ------------------------- |
| Lambda not in VPC       | VpcConfig empty              | Configure VPC             |
| Security group blocks   | Connection timeout           | Update SG rules           |
| Lambda in public subnet | No route to RDS              | Use private subnets       |
| Missing IAM permissions | CreateNetworkInterface error | Add VPC permissions       |
| Wrong subnet            | Different AZ/VPC             | Configure correct subnets |
| DNS resolution          | Cannot resolve endpoint      | Use VPC DNS               |

### Solution

**Configure Lambda VPC Access:**

```bash
aws lambda update-function-configuration \
  --function-name my-function \
  --vpc-config SubnetIds=subnet-private-a,subnet-private-b,SecurityGroupIds=sg-lambda
```

**Security Group Configuration:**

```bash
# Create Lambda security group
aws ec2 create-security-group \
  --group-name lambda-sg \
  --description "Lambda functions" \
  --vpc-id vpc-xxxxx

# Allow outbound to RDS (PostgreSQL)
aws ec2 authorize-security-group-egress \
  --group-id sg-lambda \
  --protocol tcp \
  --port 5432 \
  --source-group sg-rds

# Allow RDS inbound from Lambda
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 5432 \
  --source-group sg-lambda
```

**IAM Role Policy for VPC:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ],
      "Resource": "*"
    }
  ]
}
```

**Terraform:**

```hcl
resource "aws_lambda_function" "app" {
  function_name = "my-function"
  # ... other config ...

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }
}

resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "Lambda function security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.rds.id
}
```

**Additional Fix - RDS Proxy (Recommended for Lambda):**

```hcl
resource "aws_db_proxy" "main" {
  name                   = "my-db-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]
  vpc_subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }
}
```

---

## Scenario 4: App Loses DB During ASG Scale Events

### Problem

Application loses database connection during Auto Scaling Group scale-in events.

### Root Cause

When ASG terminates instances, active database connections are abruptly closed, causing application errors.

### Solution

**1. Implement Lifecycle Hooks:**

```bash
# Create lifecycle hook for termination
aws autoscaling put-lifecycle-hook \
  --auto-scaling-group-name my-asg \
  --lifecycle-hook-name drain-connections \
  --lifecycle-transition autoscaling:EC2_INSTANCE_TERMINATING \
  --heartbeat-timeout 300 \
  --default-result CONTINUE
```

**2. Lambda for Graceful Shutdown:**

```python
# Lambda function triggered by lifecycle hook
import boto3

def handler(event, context):
    asg = boto3.client('autoscaling')
    ssm = boto3.client('ssm')

    instance_id = event['detail']['EC2InstanceId']
    lifecycle_hook = event['detail']['LifecycleHookName']
    asg_name = event['detail']['AutoScalingGroupName']

    # Send command to drain connections
    ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName='AWS-RunShellScript',
        Parameters={
            'commands': [
                '#!/bin/bash',
                # Stop accepting new connections
                'sudo systemctl stop nginx',
                # Wait for existing connections to complete
                'sleep 60',
                # Stop application gracefully
                'sudo systemctl stop myapp'
            ]
        }
    )

    # Wait for drain to complete, then continue
    import time
    time.sleep(90)

    # Complete the lifecycle action
    asg.complete_lifecycle_action(
        LifecycleHookName=lifecycle_hook,
        AutoScalingGroupName=asg_name,
        InstanceId=instance_id,
        LifecycleActionResult='CONTINUE'
    )
```

**3. Target Group Deregistration Delay:**

```hcl
resource "aws_lb_target_group" "app" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Allow time for in-flight requests to complete
  deregistration_delay = 120

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
}
```

**4. Application-Level Connection Pooling:**

```yaml
# Application configuration
database:
  pool:
    min_connections: 5
    max_connections: 20
    idle_timeout: 300
    connection_timeout: 5
    validation_query: "SELECT 1"
    test_on_borrow: true
```

**5. Terraform - Complete ASG Configuration:**

```hcl
resource "aws_autoscaling_group" "app" {
  name                = "app-asg"
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  target_group_arns   = [aws_lb_target_group.app.arn]

  min_size         = 2
  max_size         = 10
  desired_capacity = 2

  # Warm pool for faster scaling
  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = 1
    max_group_prepared_capacity = 5
  }

  # Default cooldowns
  default_cooldown = 300

  # Instance refresh for deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "drain" {
  name                   = "drain-connections"
  autoscaling_group_name = aws_autoscaling_group.app.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 300
  default_result         = "CONTINUE"
}
```

---

## Scenario 5: CloudWatch Not Collecting Logs

### Problem

CloudWatch Logs are not appearing from EC2 instances or containers.

### Troubleshooting Steps

```bash
# 1. Check CloudWatch agent status (EC2)
sudo systemctl status amazon-cloudwatch-agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status

# 2. Check agent logs
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

# 3. Verify IAM instance profile
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# 4. Check IAM policy permissions
aws iam get-instance-profile --instance-profile-name my-instance-profile

# 5. Verify log group exists
aws logs describe-log-groups --log-group-name-prefix /myapp

# 6. Check network connectivity to CloudWatch endpoint
nc -zv logs.us-east-1.amazonaws.com 443

# 7. Check VPC endpoint (if using)
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=com.amazonaws.us-east-1.logs"
```

### Root Cause Analysis

| Cause                   | Indicator               | Fix                        |
| ----------------------- | ----------------------- | -------------------------- |
| Agent not installed     | No agent process        | Install CloudWatch agent   |
| Agent not running       | Service stopped         | Start/enable service       |
| IAM permissions missing | AccessDenied in logs    | Update IAM policy          |
| Network blocked         | Connection timeout      | Check SG/NACL/VPC endpoint |
| Wrong log group         | Logs in different group | Update config              |
| Agent misconfigured     | Config parsing errors   | Fix config file            |

### Solution

**1. Install CloudWatch Agent:**

```bash
# Amazon Linux 2 / RHEL
sudo yum install amazon-cloudwatch-agent -y

# Ubuntu
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

**2. IAM Policy for CloudWatch:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:/myapp/*",
        "arn:aws:logs:*:*:log-group:/myapp/*:log-stream:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["cloudwatch:PutMetricData"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
    }
  ]
}
```

**3. CloudWatch Agent Configuration:**

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/myapp/*.log",
            "log_group_name": "/myapp/application",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S",
            "multi_line_start_pattern": "^\\d{4}-\\d{2}-\\d{2}"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/myapp/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "MyApp",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

**4. Start Agent:**

```bash
# Store config in SSM Parameter Store
aws ssm put-parameter \
  --name "AmazonCloudWatch-myapp-config" \
  --type "String" \
  --value file://cloudwatch-config.json

# Start agent with config from SSM
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:AmazonCloudWatch-myapp-config

# Enable on boot
sudo systemctl enable amazon-cloudwatch-agent
```

**5. VPC Endpoint (for private subnets):**

```hcl
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "cloudwatch-logs-endpoint"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Allow HTTPS to VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}
```

**6. EKS Container Logs (using Fluent Bit):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Merge_Log           On

    [OUTPUT]
        Name                cloudwatch_logs
        Match               kube.*
        region              ${AWS_REGION}
        log_group_name      /aws/eks/myapp-cluster/containers
        log_stream_prefix   ${HOST_NAME}-
        auto_create_group   true
```

---

## Summary

| Scenario             | Root Cause          | Key Fix                            |
| -------------------- | ------------------- | ---------------------------------- |
| Private EC2 Internet | Missing NAT Gateway | Create NAT GW + update routes      |
| S3 AccessDenied      | IAM policy missing  | Add s3:PutObject permission        |
| Lambda → RDS         | Network isolation   | Configure VPC + Security Groups    |
| ASG DB loss          | Abrupt termination  | Lifecycle hooks + drain delay      |
| CloudWatch logs      | Agent/IAM issues    | Install agent + correct IAM policy |
