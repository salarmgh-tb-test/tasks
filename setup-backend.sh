#!/bin/bash
# Script to set up Terraform remote state backend
# This creates the S3 bucket and DynamoDB table needed for remote state
#
# Usage: ./setup-backend.sh [dev|staging|prod]

set -e

if [ $# -eq 0 ]; then
    echo "Error: Environment argument required"
    echo "Usage: $0 [dev|staging|prod]"
    exit 1
fi

ENVIRONMENT="$1"
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment '$ENVIRONMENT'"
    echo "Usage: $0 [dev|staging|prod]"
    exit 1
fi

PROJECT="tradebytes"
REGION="eu-north-1"
BUCKET_NAME="${PROJECT}-terraform-state-${ENVIRONMENT}"
DYNAMODB_TABLE="terraform-state-lock"

echo "Setting up Terraform remote state backend for ${ENVIRONMENT}..."
if [ "$ENVIRONMENT" = "prod" ]; then
    echo "WARNING: This is PRODUCTION - ensure proper security measures!"
fi
echo ""
echo "Project: $PROJECT"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""

if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket: $BUCKET_NAME"
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" || {
        echo "Bucket may already exist, continuing..."
    }
else
    echo "Bucket $BUCKET_NAME already exists"
fi

if [ "$ENVIRONMENT" = "prod" ]; then
    echo "Enabling versioning on bucket (CRITICAL for production)..."
else
    echo "Enabling versioning on bucket..."
fi
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

echo "Enabling encryption on bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

if [ "$ENVIRONMENT" = "prod" ]; then
    echo "Blocking public access (CRITICAL for production)..."
else
    echo "Blocking public access..."
fi
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

if [ "$ENVIRONMENT" = "prod" ]; then
    echo "Enabling access logging..."
    aws s3api put-bucket-logging \
        --bucket "$BUCKET_NAME" \
        --bucket-logging-status '{
            "LoggingEnabled": {
                "TargetBucket": "'"${BUCKET_NAME}"'-access-logs",
                "TargetPrefix": "s3-access/"
            }
        }' 2>/dev/null || echo "Note: Access log bucket may need to be created separately"
fi

echo "Checking DynamoDB table..."
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" 2>/dev/null; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --tags Key=Project,Value="$PROJECT" Key=Environment,Value="shared" Key=ManagedBy,Value=terraform
else
    echo "DynamoDB table already exists"
fi

echo ""
echo "[OK] Backend infrastructure created successfully!"
echo ""

echo "Next steps:"
echo "1. Run: terraform init -migrate-state"
echo "2. This will migrate your existing local state to S3"
echo ""

