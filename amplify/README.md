# Amplify with S3 Integration

This Terraform configuration creates an AWS Amplify application integrated with an S3 bucket for hosting HTML files with automatic deployment triggers.

all resources are covered under the free teir 

## Architecture

- **S3 Bucket**: Stores HTML files with restricted access (only Amplify can read)
- **Amplify App**: Static web hosting platform that deploys from S3
- **Lambda Function**: Automatically triggers Amplify deployments when S3 files change
- **CloudWatch Logs**: Monitors Lambda function execution
- **S3 Notifications**: Detects file changes and invokes Lambda

## Remote State Storage

The S3 bucket created in the `bootstrap/` folder is used to store the Terraform remote state for this configuration. This ensures:

- State file is stored remotely and securely
- Multiple team members can collaborate
- State locking prevents concurrent modifications
- Versioning is enabled for state file history

## Deployment Steps

### 1. Bootstrap (First Time Setup)

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Note the S3 bucket name from the output.

### 2. Deploy Amplify App

```bash
cd ../amplify-s3
terraform init -backend-config="bucket=<bootstrap-bucket-name>" -backend-config="key=amplify-s3/terraform.tfstate" -backend-config="region=us-east-2"
terraform plan
terraform apply
```

## Outputs

After deployment, you'll get:

- `amplify_app_url`: The URL of your Amplify application
- `s3_bucket_name`: Name of the S3 bucket storing HTML files
- `s3_website_url`: Direct S3 website endpoint

## Usage

1. Upload HTML files to the S3 bucket
2. Lambda function automatically detects changes
3. Amplify deployment is triggered automatically
4. Updated content is served through the Amplify URL

## Auto-Deployment

The system includes automatic redeployment:
- S3 file changes trigger Lambda via S3 notifications
- Lambda calls Amplify API to start new deployment
- No manual intervention required for updates