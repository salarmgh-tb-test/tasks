# Task B1 - Design a Highly Available Architecture in AWS

## Problem Statement

Design a comprehensive AWS architecture for a production application with high availability, disaster recovery, proper security, and cost optimization.

## Architecture Overview

## Detailed Architecture Diagram (Mermaid)

**Interactive Mermaid Chart**: [View Architecture Diagram](https://www.mermaidchart.com/app/projects/4ea3758a-322f-4b62-b493-9d00ec84ab21/diagrams/4535c529-b049-4457-8fd9-d553b6951d6b/share/invite/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb2N1bWVudElEIjoiNDUzNWM1MjktYjA0OS00NDU3LThmZDktZDU1M2I2OTUxZDZiIiwiYWNjZXNzIjoiVmlldyIsImlhdCI6MTc2NjAwMTY0MH0.2HsKnaPbljJp5rfFdDxGfj8MnvJzRzozXnhwv-5ysTQ)

**Architecture Diagram**:

![High Availability Architecture](./images/task-b1-ha-architecture.png)

## VPC Design

### CIDR Allocation

| Component           | CIDR         | Purpose          |
| ------------------- | ------------ | ---------------- |
| VPC                 | 10.0.0.0/16  | 65,536 IPs       |
| Public Subnet AZ-a  | 10.0.1.0/24  | ALB, NAT GW      |
| Public Subnet AZ-b  | 10.0.2.0/24  | ALB, NAT GW      |
| Public Subnet AZ-c  | 10.0.3.0/24  | ALB, NAT GW      |
| Private Subnet AZ-a | 10.0.10.0/24 | EKS Nodes        |
| Private Subnet AZ-b | 10.0.11.0/24 | EKS Nodes        |
| Private Subnet AZ-c | 10.0.12.0/24 | EKS Nodes        |
| Data Subnet AZ-a    | 10.0.20.0/24 | RDS, ElastiCache |
| Data Subnet AZ-b    | 10.0.21.0/24 | RDS, ElastiCache |
| Data Subnet AZ-c    | 10.0.22.0/24 | RDS, ElastiCache |

### Routing

**Public Subnets:**

- Default route (0.0.0.0/0) → Internet Gateway
- Local route (10.0.0.0/16) → Local

**Private Subnets:**

- Default route (0.0.0.0/0) → NAT Gateway (per AZ)
- Local route (10.0.0.0/16) → Local

**Data Subnets:**

- No internet access (isolated)
- Local route (10.0.0.0/16) → Local
- VPC Endpoints for AWS services

---

## High Availability Strategy

### Compute Layer (EKS)

| Component         | HA Mechanism           | Recovery               |
| ----------------- | ---------------------- | ---------------------- |
| EKS Control Plane | AWS Managed (Multi-AZ) | Automatic              |
| Node Groups       | ASG across 3 AZs       | 2-minute failover      |
| Pods              | HPA + PDB              | Immediate rescheduling |

**Configuration:**

- Minimum 2 nodes per AZ
- Cluster Autoscaler for dynamic scaling
- Pod anti-affinity for cross-AZ distribution

### Database Layer (RDS Aurora)

| Component         | HA Mechanism        | Recovery               |
| ----------------- | ------------------- | ---------------------- |
| Aurora PostgreSQL | Multi-AZ deployment | ~30 second failover    |
| Read Replicas     | Up to 15 replicas   | Read scaling           |
| Backups           | Continuous to S3    | Point-in-time recovery |

**Configuration:**

- Primary + 1 Read Replica (different AZ)
- Automated failover enabled
- Performance Insights enabled
- 35-day backup retention

### Cache Layer (ElastiCache)

| Component     | HA Mechanism                | Recovery            |
| ------------- | --------------------------- | ------------------- |
| Redis Cluster | Multi-AZ with auto-failover | ~10 second failover |
| Replication   | Synchronous replication     | Automatic           |

**Configuration:**

- 1 Primary + 1 Replica
- Cluster mode disabled (for simplicity)
- Automatic failover enabled
- r6g.large instance type

---

## Disaster Recovery Strategy

### DR Approach: Pilot Light / Warm Standby

**Interactive Mermaid Chart**: [View DR Architecture Diagram](https://www.mermaidchart.com/app/projects/4ea3758a-322f-4b62-b493-9d00ec84ab21/diagrams/7c220374-3d0e-406f-9b84-5de26bde06c4/share/invite/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb2N1bWVudElEIjoiN2MyMjAzNzQtM2QwZS00MDZmLTliODQtNWRlMjZiZGUwNmM0IiwiYWNjZXNzIjoiVmlldyIsImlhdCI6MTc2NjAwMjI2N30.tjTgC9eDZyS7ptiSCbPSuj3qbrcTPtVun3fkrk6CWNM)

**DR Architecture Diagram**:

![Disaster Recovery Architecture](./images/task-b1-ha-architecture-dr.png)

### RTO/RPO Targets

| Metric                         | Target       | Implementation               |
| ------------------------------ | ------------ | ---------------------------- |
| RTO (Recovery Time Objective)  | < 30 minutes | Warm standby with automation |
| RPO (Recovery Point Objective) | < 1 minute   | Aurora Global Database       |

### DR Components

1. **Aurora Global Database**: Cross-region replication with <1 second lag
2. **S3 Cross-Region Replication**: Static assets and logs
3. **Route 53 Health Checks**: Automatic DNS failover
4. **Infrastructure as Code**: Terraform for rapid DR environment spinup

## Security Design

### Network Security

**Security Groups:**

| SG Name        | Inbound               | Outbound            | Purpose         |
| -------------- | --------------------- | ------------------- | --------------- |
| alb-sg         | 443 from 0.0.0.0/0    | eks-node-sg:80,443  | ALB access      |
| eks-node-sg    | 80,443 from alb-sg    | 0.0.0.0/0 (via NAT) | EKS nodes       |
| rds-sg         | 5432 from eks-node-sg | None                | Database access |
| elasticache-sg | 6379 from eks-node-sg | None                | Cache access    |

**NACLs:**

| NACL    | Rule        | Source/Dest          | Action |
| ------- | ----------- | -------------------- | ------ |
| Public  | 100 Inbound | 0.0.0.0/0:443        | Allow  |
| Public  | 200 Inbound | 0.0.0.0/0:1024-65535 | Allow  |
| Private | 100 Inbound | 10.0.0.0/16          | Allow  |
| Data    | 100 Inbound | 10.0.10.0/22         | Allow  |

### IAM Least Privilege

**EKS Node Role:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/eks/*"
    },
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:*:*:secret:myapp/*"
    }
  ]
}
```

**Application Pod Role (IRSA):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::myapp-uploads/*"
    },
    {
      "Effect": "Allow",
      "Action": ["sqs:SendMessage", "sqs:ReceiveMessage"],
      "Resource": "arn:aws:sqs:us-east-1:123456789012:myapp-queue"
    }
  ]
}
```

---

## Logging & Monitoring

### Log Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Log Sources                               │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│ ALB Logs     │ EKS Pods     │ Aurora Logs  │ CloudTrail        │
└──────┬───────┴──────┬───────┴──────┬───────┴───────┬───────────┘
       │              │              │               │
       ▼              ▼              ▼               ▼
┌──────────────────────────────────────────────────────────────────┐
│                      CloudWatch Logs                              │
│  /aws/alb/myapp  /aws/eks/myapp  /aws/rds/myapp  /aws/cloudtrail │
└────────────────────────────┬─────────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │ S3 Archive   │  │ CloudWatch   │  │ OpenSearch   │
    │ (Long-term)  │  │ Insights     │  │ (Analysis)   │
    └──────────────┘  └──────────────┘  └──────────────┘
```

### CloudWatch Alarms

| Alarm               | Metric              | Threshold          | Action            |
| ------------------- | ------------------- | ------------------ | ----------------- |
| High ALB 5xx        | ALB_5XX_Count       | > 10/min for 5 min | SNS → PagerDuty   |
| High CPU (EKS)      | CPUUtilization      | > 80% for 10 min   | Scale out + Alert |
| High DB Connections | DatabaseConnections | > 80% of max       | Alert             |
| High Cache Memory   | BytesUsedForCache   | > 80%              | Alert             |
| Low Disk (EBS)      | VolumeWriteBytes    | < 10% free         | Alert             |

---

## Cost Optimization

### Right-Sizing Recommendations

| Component   | Instance Type | Notes                          |
| ----------- | ------------- | ------------------------------ |
| EKS Nodes   | m5.large      | General purpose, good balance  |
| RDS Aurora  | db.r6g.large  | Memory optimized for DB        |
| ElastiCache | r6g.large     | Memory optimized for caching   |
| NAT Gateway | N/A           | Consider NAT instances for dev |

### Cost-Saving Strategies

1. **Reserved Instances / Savings Plans**

   - 1-year commitment for RDS: ~35% savings
   - 3-year Compute Savings Plan: ~50% savings

2. **Spot Instances for EKS**

   - Use for non-critical workloads
   - Mixed instance types for reliability
   - Save up to 70% on compute

3. **S3 Lifecycle Policies**

   ```json
   {
     "Rules": [
       {
         "ID": "ArchiveLogs",
         "Status": "Enabled",
         "Transitions": [
           { "Days": 30, "StorageClass": "STANDARD_IA" },
           { "Days": 90, "StorageClass": "GLACIER" }
         ],
         "Expiration": { "Days": 365 }
       }
     ]
   }
   ```

4. **Auto Scaling Optimization**
   - Scale to zero in dev environments
   - Scheduled scaling for known patterns
   - Target tracking with conservative thresholds

### Estimated Monthly Costs

| Component         | Specification            | Est. Cost/Month   |
| ----------------- | ------------------------ | ----------------- |
| EKS Control Plane | 1 cluster                | $73               |
| EKS Nodes         | 6 x m5.large (on-demand) | $500              |
| RDS Aurora        | db.r6g.large (Multi-AZ)  | $450              |
| ElastiCache       | r6g.large (Multi-AZ)     | $250              |
| NAT Gateway       | 3 x (data processing)    | $150              |
| ALB               | 1 + data transfer        | $50               |
| S3 + CloudFront   | Storage + CDN            | $100              |
| CloudWatch        | Logs + Metrics           | $50               |
| **Total**         |                          | **~$1,623/month** |

_Note: Costs vary by region and usage patterns. Consider Reserved Instances for production workloads._

## Summary

This architecture provides:

**High Availability**: Multi-AZ deployment across all tiers
**Disaster Recovery**: Cross-region replication with automated failover
**Security**: Defense in depth with WAF, SGs, NACLs, and IAM least privilege
**Scalability**: Auto-scaling at compute, database, and cache layers
**Observability**: Comprehensive logging, metrics, and alerting
**Cost Optimization**: Right-sized resources with cost-saving strategies
