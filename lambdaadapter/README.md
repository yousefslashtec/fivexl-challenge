note to fivexl , the terraform was created by amazon Q with claude sonnet 4 , based on my article
 https://builder.aws.com/content/2rm0EJsJ08X3IUo906NUCETfTF7/run-a-docker-web-server-on-aws-lambda-with-web-adapter-and-cloudfront
dockerfile by google gemeni 


reasons : 
near zero deployment costs , as we are going to serve html we can skip having a normal server by running the server on lambda , however if we run it normally it will time out , the lambda adapter stops the fambda fuction once the page is served 
costs : 
lambda -free teir 
cloudfront - free teir 
s3 - minimal (less than 5 cents)
codebuild - free teir 
codepipeline -free teir
# Lambda Adapter Infrastructure

This Terraform configuration creates:

1. **S3 Bucket** - For storing Terraform remote state (bootstrap/)
2. **CodeCommit Repository** - Source code repository  
3. **CodePipeline** - Automated deployment pipeline
4. **Lambda Function** - Created after first pipeline run (lambda/)
5. **CloudFront Distribution** - Created after first pipeline run (lambda/)

## Deployment Steps

### Phase 1: Bootstrap (S3 State Bucket)
1. **Create the state bucket:**
   ```bash
   cd bootstrap
   terraform init
   terraform apply
   cd ..
   ```

### Phase 2: Infrastructure Setup
2. **Initialize main infrastructure:**
   ```bash
   terraform init -backend-config="bucket=<bucketname>" -backend-config="region=us-east-2"
   terraform apply
   ```

3. **Push code to CodeCommit:**
   - Clone the repository using the output URL
   - Add Dockerfile, index.html, and buildspec.yml
   - Push to trigger the first pipeline run

# you can use git-remote-codecommit to push to codecommit using iam credentials 
``` 
sudo apt update
sudo apt install pipx
pipx ensurepath
pipx install git-remote-codecommit
 git clone codecommit::<region>://lambda-adapter-repo
 cd lambda-adapter-repo
 cp ../buildspec.yml ../Dockerfile ../index.html .
git add ./*  
git commit -m "Add container files"
git push origin main
```
4. **Wait for pipeline to complete successfully**  (note that the build stage will fail -the first time you run-# due to the lambda update command , run it again after step 5, or move it to a different stage)

### Phase 3: Lambda and CloudFront Setup
5. **Apply Lambda configuration:**
   ```bash
   cd lambda
   terraform init -backend-config="bucket=<bucketname>" -backend-config="region=us-east-2"
   terraform apply
   ```
#  run the codebuild phase again 

## Important Notes

- The Lambda function uses nginx with Lambda Web Adapter to serve HTML files
- HTML files are served from `/usr/share/nginx/html/` in the container
- CloudFront is configured with CachingDisabled policy
- Function URL uses AWS_IAM authentication
- OAC is configured for secure CloudFront-to-Lambda communication
- **Must complete all phases in order**

## Outputs

After Phase 1:
- S3 state bucket name

After Phase 2:
- CodeCommit repository URL
- ECR repository URL
- CodePipeline name

After Phase 3:
- Lambda function URL
- CloudFront domain name and URL