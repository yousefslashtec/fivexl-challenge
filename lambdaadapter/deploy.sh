#!/bin/bash

# Phase 1: Bootstrap
echo "Phase 1: Creating S3 bucket for remote state..."
cd bootstrap
terraform init
terraform apply -auto-approve

# Get the bucket name
BUCKET_NAME=$(terraform output -raw s3_state_bucket)
echo "Created bucket: $BUCKET_NAME"

# Phase 2: Main infrastructure
echo "Phase 2: Deploying main infrastructure..."
cd ..
terraform init -backend-config="bucket=$BUCKET_NAME" -backend-config="key=main/terraform.tfstate" -backend-config="region=us-east-2"
terraform apply -auto-approve

echo "Deployment complete. Push code to CodeCommit to trigger pipeline."
echo "After pipeline completes, run Phase 3:"
echo "cd lambda && terraform init -backend-config=\"bucket=$BUCKET_NAME\" -backend-config=\"key=lambda/terraform.tfstate\" -backend-config=\"region=us-east-2\" && terraform apply"