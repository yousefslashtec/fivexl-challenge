# Lambda Adapter Infrastructure

note to fivexl , the terraform was created by amazon Q with claude sonnet 4 and 4.5 , based on my article
 https://builder.aws.com/content/2rm0EJsJ08X3IUo906NUCETfTF7/run-a-docker-web-server-on-aws-lambda-with-web-adapter-and-cloudfront
dockerfile by google gemeni 

updated on feb 13 and 14 to simplify the deployment into one file 

reasons : 
near zero deployment costs , as we are going to serve html we can skip having a normal server by running the server on lambda , however if we run it normally it will time out , the lambda adapter stops the fambda fuction once the page is served

This Terraform configuration creates a complete CI/CD pipeline for deploying containerized web applications to AWS Lambda with CloudFront distribution.

## Architecture

- **CodeCommit Repository** - Source code repository
- **CodePipeline** - 3-stage automated deployment pipeline:
  - Source: Gets code from CodeCommit
  - Build: Builds and pushes Docker image to ECR
  - Deploy: Uses CodeDeploy for all-at-once deployments
- **Lambda Function** - Container-based function with Web Adapter
- **CloudFront Distribution** - Global CDN with Origin Access Control
- **CodeDeploy** - Handles all-at-once deployments

## Cost Benefits

- **Lambda**: Free tier eligible
- **CloudFront**: Free tier eligible  
- **S3**: Minimal costs (< $0.05)
- **CodeBuild**: Free tier eligible
- **CodePipeline**: Free tier eligible
- **CodeDeploy**: No additional charges

## Deployment

### 1. Bootstrap (S3 State Bucket)
```bash
cd bootstrap
terraform init
terraform apply
cd ..
```

### 2. Deploy Infrastructure (Automated)
make sure that your environment can run sudo without a password or run "sudo apt update" and enter the password before running the terraform , part of the terraform is script that installes the codecommit helper and pushes files to codecommit , note that the pipeline will give a false positive fail the first time it runs 

```bash
terraform init -backend-config="bucket=<bucketname>" -backend-config="region=us-east-2"
terraform apply
```

This will automatically:
- Create all infrastructure resources
- Push code files to CodeCommit repository
- Trigger the pipeline to build and deploy

## Pipeline Stages

1. **Source**: Triggers on CodeCommit push
2. **Build**: Builds Docker image and pushes to ECR
3. **Deploy**: Uses CodeDeploy for all-at-once deployments

## Key Features

- **Fully Automated**: Single `terraform apply` creates everything and pushes code
- **All-at-Once Deployments**: Immediate deployment with auto-rollback
- **Container Support**: Uses Lambda Web Adapter for web applications
- **Global Distribution**: CloudFront with Origin Access Control
- **Cost Optimized**: Serverless architecture with minimal costs

## Files Required

- `Dockerfile`: Container definition
- `index.html`: Web application files
- `buildspec.yml`: Build instructions

## Outputs

- CodeCommit repository URL
- ECR repository URL
- Lambda function URL
- CloudFront distribution URL
- CodePipeline name

## changes done on feb 13 and 14 : 
- added codedeploy stage 
- changed buildspec to create an appspec file
- changed dockerfile to use public ecr instead of dockerhub, to avoid rate limits
- changed some iam permissions 
- added a terraform null resource to push files to codecommit 