# hugo-personal-website

Step:

- Build website
- Create IAM user
- aws configure
- Create S3 bucket for state
- Create DynamoDB table for state
- Write Terraform script for s3 bucket, acm, cloudfront, route53
- Import Route53 if exists
- Write site deployment to config.toml
- GitHub Actions for site and terraform
- Lambda functions for redirect