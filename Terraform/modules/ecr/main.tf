# -----------------------------------------------------------------------------
# Module: ECR (Elastic Container Registry)
# -----------------------------------------------------------------------------
# Provisions private Docker container registries for the application.
# - Frontend Repo: Stores the React application images.
# - Backend Repo: Stores the Node.js API images.
# -----------------------------------------------------------------------------

# Create the Frontend ECR Repository
resource "aws_ecr_repository" "frontend_repo" {
  name                 = var.ecr_repo_name_frontend
  image_tag_mutability = "MUTABLE" # Allows image tags to be overwritten (useful for 'latest')
  image_scanning_configuration {
    scan_on_push = true # Automatically scan images for vulnerabilities on push
  }
  tags = { Name = "Frontend_ECR_Repo" }
}

# Create the Backend ECR Repository
resource "aws_ecr_repository" "backend_repo" {
  name                 = var.ecr_repo_name_backend
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "Backend_ECR_Repo" }
}

