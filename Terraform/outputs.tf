# outputs.tf

output "master_public_ip" {
  description = "Public IP address of the Kubernetes Master Node."
  value       = module.compute.master_public_ip
}

output "worker_private_ips" {
  description = "Private IP addresses of the Kubernetes Worker Nodes."
  value       = module.compute.worker_private_ips
}

# Update these outputs to pull from the ECR module
output "frontend_ecr_repo_url" {
  description = "URL of the Frontend ECR Repository."
  value       = module.ecr_repos.frontend_repo_url
}

output "backend_ecr_repo_url" {
  description = "URL of the Backend ECR Repository."
  value       = module.ecr_repos.backend_repo_url
}

output "logs_s3_bucket_name" {
  description = "Name of the S3 bucket for logs."
  value       = aws_s3_bucket.logs_bucket.bucket
}
