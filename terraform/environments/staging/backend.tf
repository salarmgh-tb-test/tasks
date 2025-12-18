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
#--------------------------------------------------------------

terraform {
  backend "s3" {
    # S3 bucket name for storing Terraform state
    bucket = "tradebytes-terraform-state-staging"

    # State file path (unique per environment)
    key = "environments/staging/terraform.tfstate"

    # AWS region (must match your infrastructure region)
    region = "eu-north-1"

    # Enable encryption at rest (AES256)
    encrypt = true

    # DynamoDB table for state locking (prevents concurrent modifications)
    dynamodb_table = "terraform-state-lock"
  }
}

