# -----------------------------------------------------------------------------
# AWS SSM Parameter Store Configuration
# -----------------------------------------------------------------------------
# Stores dynamic infrastructure values (ECR URLs, S3 Bucket Names) in AWS SSM.
# These parameters are retrieved by Jenkins during the build/deploy pipeline.
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "backend_ecr" {
  name        = "/depi-project/amazona/backend-ecr"
  description = "URL for the Backend ECR repository"
  type        = "String"
  value       = module.ecr_repos.backend_repo_url
}

resource "aws_ssm_parameter" "frontend_ecr" {
  name        = "/depi-project/amazona/frontend-ecr"
  description = "URL for the Frontend ECR repository"
  type        = "String"
  value       = module.ecr_repos.frontend_repo_url
}

resource "aws_ssm_parameter" "s3_bucket_name" {
  name        = "/depi-project/amazona/products-bucket"
  description = "Name of the S3 bucket used for product data"
  type        = "String"
  value       = module.s3.app_s3_bucket_name
}

