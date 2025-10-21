# modules/ecr/main.tf

resource "aws_ecr_repository" "frontend_repo" {
  name = var.ecr_repo_name_frontend
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "Frontend_ECR_Repo"
  }
}

resource "aws_ecr_repository" "backend_repo" {
  name = var.ecr_repo_name_backend
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "Backend_ECR_Repo"
  }
}
