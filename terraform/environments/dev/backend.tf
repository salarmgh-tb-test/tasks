#--------------------------------------------------------------
# Terraform Remote State Backend Configuration
#--------------------------------------------------------------
#
# This backend configuration stores Terraform state in S3 with
# DynamoDB for state locking to enable team collaboration.
#
# SETUP INSTRUCTIONS:
# 1. Create an S3 bucket for storing Terraform state:
#    aws s3 mb s3://YOUR-BUCKET-NAME --region eu-north-1
#
# 2. Enable versioning on the bucket:
#    aws s3api put-bucket-versioning \
#      --bucket YOUR-BUCKET-NAME \
#      --versioning-configuration Status=Enabled
#
# 3. Enable encryption:
#    aws s3api put-bucket-encryption \
#      --bucket YOUR-BUCKET-NAME \
#      --server-side-encryption-configuration '{
#        "Rules": [{
#          "ApplyServerSideEncryptionByDefault": {
#            "SSEAlgorithm": "AES256"
#          }
#        }]
#      }'
#
# 4. Create DynamoDB table for state locking:
#    aws dynamodb create-table \
#      --table-name terraform-state-lock \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST \
#      --region eu-north-1
#
# 5. Uncomment the backend block below and update with your values
# 6. Run: terraform init -migrate-state (to migrate existing state)
#
#--------------------------------------------------------------

#--------------------------------------------------------------
# Remote State Backend Configuration (ACTIVE)
#--------------------------------------------------------------
# This backend stores Terraform state in S3 with DynamoDB locking
#
# Before using this backend, run:
#   ./setup-backend.sh
#
# Then initialize Terraform with state migration:
#   terraform init -migrate-state
#--------------------------------------------------------------

terraform {
  backend "s3" {
    # S3 bucket name for storing Terraform state
    # Created by setup-backend.sh script
    bucket = "tradebytes-terraform-state-dev"

    # State file path (unique per environment)
    key = "environments/dev/terraform.tfstate"

    # AWS region (must match your infrastructure region)
    region = "eu-north-1"

    # Enable encryption at rest (AES256)
    encrypt = true

    # DynamoDB table for state locking (prevents concurrent modifications)
    # Created by setup-backend.sh script
    dynamodb_table = "terraform-state-lock"

    # Optional: Use KMS key for encryption (uncomment if you have one)
    # kms_key_id = "arn:aws:kms:eu-north-1:ACCOUNT-ID:key/KEY-ID"

    # Optional: Use IAM role for cross-account access
    # role_arn = "arn:aws:iam::ACCOUNT-ID:role/terraform-backend-role"
  }
}

#--------------------------------------------------------------
# Alternative: Local Backend (Default - Currently Active)
#--------------------------------------------------------------
# When no backend block is specified, Terraform uses local state.
# State is stored in terraform.tfstate in the current directory.
# This is fine for development but NOT recommended for production.
#--------------------------------------------------------------

