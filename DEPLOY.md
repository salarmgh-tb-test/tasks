# Deployment Guide

This guide walks you through deploying the Tradebytes infrastructure and applications to AWS EKS.

## Getting Started

### Clone the Repository

To get started, clone this repository with its submodules:

```bash
git clone --recurse-submodules git@github.com:salarmgh-tb-test/tasks.git
cd tasks
```

If you've already cloned the repository without submodules, initialize them with:

```bash
git submodule init
git submodule update
```

Or in one command:

```bash
git submodule update --init --recursive
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- kubectl installed
- Access to the AWS account and EKS cluster

**Note**: Due to AWS free tier account limitations, we cannot deploy a third RDS instance. As a result, the platform uses the postgres-operator (CloudNativePG) deployed within Kubernetes to manage PostgreSQL databases instead of AWS RDS for all environments.

## Initial Setup

### Terraform Remote State Backend

The Terraform remote state backend has already been set up. If you need to set it up again (for a new environment), you can run:

```bash
./setup-backend.sh [dev|staging|prod]
```

**Note:** The remote state backend has already been initialized, so you don't need to run this script.

## Deploying Environments

### Step 1: Source Environment Variables

Source the appropriate environment file based on which environment you want to deploy:

```bash
# For development
source env-dev

# For staging
source env-staging

# For production
source env-prod
```

### Step 2: Navigate to Terraform Environment Directory

Navigate to the terraform environment directory:

```bash
cd terraform/environments/[ENV]
```

Where `[ENV]` is one of:

- `dev` - Development environment
- `staging` - Staging environment
- `prod` - Production environment

### Step 3: Initialize and Apply Terraform

Initialize Terraform (if not already done):

```bash
terraform init
```

Apply the Terraform configuration:

```bash
terraform apply
```

Review the plan and confirm with `yes` when prompted.

## Validating Deployment

### Step 1: Update AWS Context

After successful Terraform deployment, update your kubectl context to connect to the EKS cluster:

```bash
aws eks update-kubeconfig --region eu-north-1 --name [CLUSTER_NAME]
```

Replace `[CLUSTER_NAME]` with your cluster name (typically `tradebytes-[env]-cluster`).

### Step 2: Verify Cluster Status

Check that nodes are running:

```bash
kubectl get nodes
```

Verify all pods are running across all namespaces:

```bash
kubectl get pods -A
```

### Step 3: Verify Application Deployment

Check the GitHub Actions workflows for both backend and frontend services to ensure they have successfully deployed:

- Backend service: Check the backend repository's Actions tab
- Frontend service: Check the frontend repository's Actions tab

## Accessing the Application

### Step 1: Get Ingress Information

After successful deployment, retrieve the ingress configuration:

```bash
kubectl get ingress -n tradebytes
```

This will show you:

- The hostname(s) configured for each service
- The load balancer address

### Step 2: Access the Services

You have several options to access the services:

#### Option 1: Using curl with Host Header

```bash
# Backend
curl -H "Host: backend.example.com" http://[LOAD_BALANCER_ADDRESS]

# Frontend
curl -H "Host: frontend.example.com" http://[LOAD_BALANCER_ADDRESS]
```

#### Option 2: Using /etc/hosts

Add entries to your `/etc/hosts` file:

```bash
sudo nano /etc/hosts
```

Add:

```
[LOAD_BALANCER_ADDRESS] backend.example.com
[LOAD_BALANCER_ADDRESS] frontend.example.com
[LOAD_BALANCER_ADDRESS] monitoring.example.com
```

Then access via:

```bash
curl http://backend.example.com
curl http://frontend.example.com
```

#### Option 3: Using Your Domain

If you have configured DNS records pointing to the load balancer, you can access services directly:

```bash
curl http://backend.yourdomain.com
curl http://frontend.yourdomain.com
curl http://monitoring.yourdomain.com
```

### Step 3: Verify Application Responses

#### Backend Service

The backend should respond with:

```json
{ "name": "Tradebytes" }
```

Test with:

```bash
curl http://backend.example.com
# or
curl -H "Host: backend.example.com" http://[LOAD_BALANCER_ADDRESS]
```

#### Frontend Service

The frontend should display:

```
Hello Tradebytes!
```

Test with:

```bash
curl http://frontend.example.com
# or
curl -H "Host: frontend.example.com" http://[LOAD_BALANCER_ADDRESS]
```

## Troubleshooting

If you encounter issues:

1. **Check pod status:**

   ```bash
   kubectl get pods -n tradebytes
   kubectl describe pod [POD_NAME] -n tradebytes
   kubectl logs [POD_NAME] -n tradebytes
   ```

2. **Check ingress status:**

   ```bash
   kubectl describe ingress -n tradebytes
   ```

3. **Verify services:**

   ```bash
   kubectl get svc -n tradebytes
   ```

4. **Check GitHub Actions:** Ensure both backend and frontend CI/CD pipelines completed successfully

5. **Verify AWS resources:** Check that all AWS resources (EKS cluster, load balancer, etc.) are running in the AWS Console

## Additional Services

The deployment also includes monitoring services (Grafana, Prometheus, Loki, Tempo) which can be accessed via their respective ingress hostnames. Check the ingress configuration to see the monitoring service endpoints.
