# Tradebytes Platform

A production-ready microservices platform deployed on AWS EKS with comprehensive infrastructure-as-code, CI/CD pipelines, and observability stack.

## Documentation Index

### Deployment Guide

- **[DEPLOY.md](./DEPLOY.md)** - Complete deployment guide for setting up and deploying the Tradebytes platform to AWS EKS environments (dev, staging, production)

### Task Documentation

#### Phase A: Core Deployment

- **[Task A1 - Deploy Microservice](./task-a1-deploy-microservice.md)** - Production-ready Kubernetes microservice deployment with Helm charts
- **[Task A2 - Debug Cluster](./task-a2-debug-cluster.md)** - Cluster debugging and troubleshooting guide

#### Phase B: High Availability & CI/CD

- **[Task B1 - HA Architecture](./task-b1-ha-architecture.md)** - High availability architecture design and implementation
- **[Task B2 - Fix AWS Issues](./task-b2-fix-aws-issues.md)** - AWS infrastructure troubleshooting and fixes
- **[Task B3 - CI/CD Pipeline](./task-b3-cicd-pipeline.md)** - Complete CI/CD pipeline implementation with GitHub Actions

#### Phase C: Infrastructure as Code

- **[Task C1 - Terraform Modules](./task-c1-terraform-modules.md)** - Terraform module structure and implementation
- **[Task C2 - Troubleshoot](./task-c2-troubleshoot.md)** - Infrastructure troubleshooting guide

#### Phase D: Observability

- **[Task D1 - Monitoring Strategy](./task-d1-monitoring-strategy.md)** - Comprehensive monitoring and observability strategy
- **[Task D2 - Fix Latency](./task-d2-fix-latency.md)** - Performance optimization and latency reduction

#### Phase E: Reliability & Security

- **[Task E1 - Zero Downtime](./task-e1-zero-downtime.md)** - Zero-downtime deployment strategies
- **[Task E2 - Security](./task-e2-security.md)** - Security hardening and best practices

#### Phase F: Documentation

- **[Task F1 - Technical Document](./task-f1-technical-document.md)** - Complete technical documentation of the platform

### Presentation

- **[Tradebytes Presentation Deck](https://docs.google.com/presentation/d/1__Ti_i9CS11lOCcytAAOkFILvd1yOLWAR9ESb_KRX0I/edit?usp=sharing)** - Google Slides presentation covering the Tradebytes platform architecture, implementation, and key features

## Project Structure

```
tradebytes/
├── backend/              # Laravel backend service
│   ├── helm/            # Helm charts for backend
│   └── ...
├── frontend/            # React frontend service
│   ├── helm/            # Helm charts for frontend
│   └── ...
├── terraform/           # Infrastructure as Code
│   ├── environments/    # Environment-specific configs (dev, staging, prod)
│   ├── modules/         # Reusable Terraform modules
│   └── stacks/          # Platform stack definitions
├── setup-backend.sh     # Terraform backend initialization script
├── env-dev              # Development environment variables
├── env-staging          # Staging environment variables
├── env-prod             # Production environment variables
└── DEPLOY.md            # Deployment guide
```

## Quick Start

1. **Set up Terraform backend** (already done so do not run it):

   ```bash
   ./setup-backend.sh [dev|staging|prod]
   ```

2. **Source environment variables**:

   ```bash
   source env-dev  # or env-staging, env-prod
   ```

3. **Deploy infrastructure**:

   ```bash
   cd terraform/environments/[ENV]
   terraform init
   terraform apply
   ```

4. **Verify deployment**:
   ```bash
   aws eks update-kubeconfig --region eu-north-1 --name [CLUSTER_NAME]
   kubectl get nodes
   kubectl get pods -A
   ```

For detailed deployment instructions, see [DEPLOY.md](./DEPLOY.md).

## Technologies

- **Container Orchestration**: Kubernetes (EKS)
- **Infrastructure**: AWS (EKS, RDS, ElastiCache, VPC)
- **IaC**: Terraform
- **Package Management**: Helm
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus, Grafana, Loki, Tempo
- **Backend**: Laravel (PHP)
- **Frontend**: React
- **Database**: PostgreSQL (via postgres-operator)

## Notes

**AWS Free Tier Limitation**: Due to AWS free tier account limitations, we cannot deploy a third RDS instance. As a result, the platform uses the postgres-operator (CloudNativePG) deployed within Kubernetes to manage PostgreSQL databases instead of AWS RDS for all environments.

## Key Features

- Multi-environment deployment (dev, staging, production)
- Infrastructure as Code with Terraform modules
- Complete CI/CD pipeline with GitHub Actions
- High availability with multi-AZ deployments
- Comprehensive observability stack
- Zero-downtime deployments
- Security hardening and best practices
- Production-ready Helm charts

## License

This project is part of a technical assessment/demonstration.
