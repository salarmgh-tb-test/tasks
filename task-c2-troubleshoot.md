# Task C2 - Troubleshoot a Broken Terraform Deployment

## Problem Statement

Given errors like:

- 'cycle detected'
- 'IAM role missing permissions'
- 'resource address has changed'

Explain causes and step-by-step fixes, including state inspection and addressing drift.

---

## Error 1: Cycle Detected

### Error Message

```
Error: Cycle: aws_security_group.app, aws_security_group.db
```

### Root Cause

Terraform detected a circular dependency where two or more resources reference each other, creating an infinite loop in the dependency graph.

**Example of Cyclic Dependency:**

```hcl
# BAD: Creates a cycle
resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]  # References db
  }
}

resource "aws_security_group" "db" {
  name   = "db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # References app (CYCLE!)
  }
}
```

### Step-by-Step Fix

**Step 1: Identify the Cycle**

```bash
# Visualize the dependency graph
terraform graph | dot -Tpng > graph.png

# Or output as text
terraform graph
```

**Step 2: Break the Cycle Using Separate Rules**

```hcl
# GOOD: Use separate security group rules to break cycle
resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = aws_vpc.main.id

  # Egress rule only (no ingress referencing db)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name   = "db-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Separate rule resources to avoid cycles
resource "aws_security_group_rule" "app_to_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.db.id
}

resource "aws_security_group_rule" "db_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
}
```

**Step 3: Use depends_on Carefully**

```hcl
# Only use depends_on for implicit dependencies
resource "aws_instance" "app" {
  # ...

  depends_on = [aws_db_instance.main]  # Wait for DB to be ready
}
```

### Prevention

1. Use separate `aws_security_group_rule` resources instead of inline rules
2. Avoid bidirectional references in resource definitions
3. Use `depends_on` sparingly and only for implicit dependencies
4. Review dependency graph before applying: `terraform graph`

---

## Error 2: IAM Role Missing Permissions

### Error Message

```
Error: error creating EKS Cluster: AccessDeniedException: User:
arn:aws:iam::123456789012:user/terraform is not authorized to perform:
eks:CreateCluster on resource: arn:aws:eks:us-east-1:123456789012:cluster/myapp
```

### Root Cause

The IAM role/user running Terraform lacks permissions to perform the requested AWS API actions.

### Step-by-Step Fix

**Step 1: Identify Missing Permissions**

```bash
# Check current caller identity
aws sts get-caller-identity

# List attached policies
aws iam list-attached-user-policies --user-name terraform
aws iam list-attached-role-policies --role-name terraform-role

# Get policy details
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/TerraformPolicy \
  --version-id v1
```

**Step 2: Enable CloudTrail for Detailed Errors**

```bash
# Query CloudTrail for access denied events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateCluster \
  --start-time $(date -d '1 hour ago' --iso-8601=seconds)
```

**Step 3: Add Required Permissions**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSFullAccess",
      "Effect": "Allow",
      "Action": ["eks:*"],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:CreateServiceLinkedRole"
      ],
      "Resource": ["arn:aws:iam::*:role/eks-*", "arn:aws:iam::*:role/*-eks-*"]
    },
    {
      "Sid": "EC2ForEKS",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
```

**Step 4: Apply Policy**

```bash
# Update the IAM policy
aws iam put-user-policy \
  --user-name terraform \
  --policy-name TerraformEKSPolicy \
  --policy-document file://terraform-eks-policy.json

# Or attach to role
aws iam put-role-policy \
  --role-name terraform-role \
  --policy-name TerraformEKSPolicy \
  --policy-document file://terraform-eks-policy.json
```

**Step 5: Verify and Retry**

```bash
# Verify permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/terraform \
  --action-names eks:CreateCluster \
  --resource-arns "arn:aws:eks:us-east-1:123456789012:cluster/*"

# Retry Terraform
terraform apply
```

### Common Missing Permissions by Service

| Service | Common Missing Permissions                               |
| ------- | -------------------------------------------------------- |
| EKS     | `eks:*`, `iam:PassRole`, `iam:CreateServiceLinkedRole`   |
| RDS     | `rds:*`, `kms:CreateGrant`, `kms:Decrypt`                |
| VPC     | `ec2:*`, service-specific `ec2:` actions                 |
| IAM     | `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole` |
| S3      | `s3:*`, `kms:GenerateDataKey`                            |

---

## Error 3: Resource Address Has Changed

### Error Message

```
Error: Resource instance address has changed

The resource module.vpc.aws_subnet.private[0] was originally created at
module.vpc.aws_subnet.private["us-east-1a"]. Its address has changed to
module.vpc.aws_subnet.private[0]. Terraform cannot handle this change
automatically.
```

### Root Cause

The resource identifier changed (e.g., from `for_each` map key to `count` index, or vice versa), causing Terraform to see the existing resource as a different one.

### Step-by-Step Fix

**Step 1: Inspect Current State**

```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show 'module.vpc.aws_subnet.private["us-east-1a"]'

# View full state file (be careful with sensitive data)
terraform state pull > current-state.json
```

**Step 2: Option A - Move Resources in State**

```bash
# Move single resource
terraform state mv \
  'module.vpc.aws_subnet.private["us-east-1a"]' \
  'module.vpc.aws_subnet.private[0]'

# Move multiple resources (script example)
terraform state mv \
  'module.vpc.aws_subnet.private["us-east-1a"]' \
  'module.vpc.aws_subnet.private[0]'

terraform state mv \
  'module.vpc.aws_subnet.private["us-east-1b"]' \
  'module.vpc.aws_subnet.private[1]'

terraform state mv \
  'module.vpc.aws_subnet.private["us-east-1c"]' \
  'module.vpc.aws_subnet.private[2]'
```

**Step 3: Option B - Use moved Blocks (Terraform 1.1+)**

```hcl
# Add to configuration (declarative state move)
moved {
  from = module.vpc.aws_subnet.private["us-east-1a"]
  to   = module.vpc.aws_subnet.private[0]
}

moved {
  from = module.vpc.aws_subnet.private["us-east-1b"]
  to   = module.vpc.aws_subnet.private[1]
}

moved {
  from = module.vpc.aws_subnet.private["us-east-1c"]
  to   = module.vpc.aws_subnet.private[2]
}
```

**Step 4: Option C - Import Resources**

```bash
# If state is corrupted, remove and reimport
terraform state rm 'module.vpc.aws_subnet.private["us-east-1a"]'

# Import with new address
terraform import 'module.vpc.aws_subnet.private[0]' subnet-0abc123
```

**Step 5: Verify Plan**

```bash
# Run plan to verify no changes
terraform plan

# Should show "No changes" if state matches infrastructure
```

### Prevention

1. Use `for_each` with stable keys (not dynamic values that change)
2. Plan refactoring carefully with `moved` blocks
3. Use consistent indexing strategies
4. Document resource naming conventions

---

## Error 4: State Drift Detection and Resolution

### Detecting Drift

```bash
# Refresh state to detect drift
terraform refresh

# Plan will show drift as changes
terraform plan

# Example output showing drift:
# ~ resource "aws_instance" "app" {
#     ~ tags = {
#         - "ManualChange" = "true" -> null
#       }
#   }
```

### Resolving Drift

**Option 1: Accept Infrastructure State (Override Terraform)**

```bash
# Refresh and import current infrastructure state
terraform refresh

# Plan will now show Terraform trying to revert changes
# If you want to KEEP the manual changes, update your .tf files
```

**Option 2: Revert to Terraform State (Apply)**

```bash
# Apply to revert infrastructure to match Terraform state
terraform apply
```

**Option 3: Selective Import**

```bash
# If resource was modified outside Terraform
terraform import aws_instance.app i-1234567890abcdef0

# This updates state to match infrastructure
```

### Preventing Drift

```hcl
# Use lifecycle rules to prevent certain changes
resource "aws_instance" "app" {
  # ...

  lifecycle {
    ignore_changes = [
      tags["ManualChange"],  # Ignore specific tag changes
    ]
  }
}

# Prevent destroy
resource "aws_db_instance" "main" {
  # ...

  lifecycle {
    prevent_destroy = true
  }
}
```

---

## Error 5: State Lock Issues

### Error Message

```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        12345678-1234-1234-1234-123456789012
  Path:      s3://bucket/path/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.6.0
  Created:   2024-01-15 10:30:00.000000000 +0000 UTC
```

### Root Cause

Another Terraform process is holding the state lock, or a previous process crashed without releasing it.

### Step-by-Step Fix

**Step 1: Verify Lock Status**

```bash
# Check DynamoDB for lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "s3://bucket/path/terraform.tfstate"}}'
```

**Step 2: Wait or Force Unlock**

```bash
# Wait for other process to complete, OR

# Force unlock (DANGEROUS - only if you're sure no other process is running)
terraform force-unlock 12345678-1234-1234-1234-123456789012

# Confirm the unlock
terraform force-unlock -force 12345678-1234-1234-1234-123456789012
```

**Step 3: Manual DynamoDB Cleanup (Last Resort)**

```bash
# Delete lock from DynamoDB directly
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "s3://bucket/path/terraform.tfstate"}}'
```

### Prevention

1. Always let Terraform complete before interrupting
2. Use CI/CD pipelines with proper locking
3. Implement timeouts for long-running operations
4. Monitor state lock duration

---

## Error 6: Provider Version Conflicts

### Error Message

```
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider hashicorp/aws:
locked provider registry.terraform.io/hashicorp/aws 4.0.0 does not match
configured version constraint ~> 5.0
```

### Step-by-Step Fix

**Step 1: Check Version Constraints**

```bash
# View current lock file
cat .terraform.lock.hcl

# View required versions
grep -r "required_providers" *.tf
```

**Step 2: Update Lock File**

```bash
# Remove lock file and reinitialize
rm .terraform.lock.hcl
terraform init -upgrade

# Or update specific provider
terraform init -upgrade=hashicorp/aws
```

**Step 3: Pin Specific Version**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow 5.x but not 6.x
    }
  }
}
```

---

## Terraform State Management Commands Reference

```bash
# List all resources
terraform state list

# Show resource details
terraform state show aws_instance.example

# Move resource address
terraform state mv aws_instance.old aws_instance.new

# Remove resource from state (keeps infrastructure)
terraform state rm aws_instance.example

# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0

# Pull remote state
terraform state pull > state.json

# Push state (dangerous!)
terraform state push state.json

# Replace provider
terraform state replace-provider registry.terraform.io/-/aws registry.terraform.io/hashicorp/aws

# Taint resource for recreation
terraform taint aws_instance.example
# Or (Terraform 1.5+)
terraform apply -replace="aws_instance.example"

# Untaint resource
terraform untaint aws_instance.example
```

---

## Troubleshooting Checklist

| Issue             | Diagnostic Command            | Common Fix                         |
| ----------------- | ----------------------------- | ---------------------------------- |
| Cycle detected    | `terraform graph`             | Use separate resource rules        |
| Permission denied | `aws sts get-caller-identity` | Update IAM policy                  |
| Address changed   | `terraform state list`        | Use `moved` blocks or `state mv`   |
| State drift       | `terraform plan`              | Refresh and apply or update config |
| State locked      | DynamoDB query                | `terraform force-unlock`           |
| Provider conflict | Check `.terraform.lock.hcl`   | `terraform init -upgrade`          |

---

## Summary

Effective Terraform troubleshooting requires:

**Understanding Dependencies**: Use `terraform graph` to visualize
**State Management**: Master `state` subcommands
**IAM Debugging**: Use CloudTrail and policy simulator
**Drift Management**: Regular `terraform plan` to detect changes
**Version Control**: Lock provider versions and test upgrades
**Documentation**: Comment complex dependencies and workarounds
