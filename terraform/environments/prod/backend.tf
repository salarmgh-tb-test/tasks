#--------------------------------------------------------------
# Terraform Remote State Backend Configuration
#--------------------------------------------------------------
# This backend stores Terraform state in S3 with DynamoDB locking
#
# Before using this backend, run:
#   ./setup-backend.sh
#
# Then initialize Terraform with state migration:
#   terraform init -migrate-state
#
# IMPORTANT: Production state should be in a separate, highly secure bucket
# with additional access controls and monitoring.
#--------------------------------------------------------------

terraform {
  backend "s3" {
    # S3 bucket name for storing Terraform state
    bucket = "tradebytes-terraform-state-prod"

    # State file path (unique per environment)
    key = "environments/prod/terraform.tfstate"

    # AWS region (must match your infrastructure region)
    region = "eu-north-1"

    # Enable encryption at rest (AES256)
    encrypt = true

    # DynamoDB table for state locking (prevents concurrent modifications)
    dynamodb_table = "terraform-state-lock"

    # Optional: Use KMS key for encryption (recommended for prod)
    # kms_key_id = "arn:aws:kms:eu-north-1:ACCOUNT-ID:key/KEY-ID"
  }
}

