# -----------------------------------------------------------------------------
# Terraform Variables
# -----------------------------------------------------------------------------
# Defines all input variables for the root module, allowing for customization
# of the infrastructure deployment (Regions, CIDRs, Instance Types, etc.).
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy resources in (e.g., us-east-1)."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Networking Variables
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "The CIDR block for the VPC (Virtual Private Cloud)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "k8s_public_subnet_cidr1" {
  description = "CIDR for the Public Subnet hosting the Kubernetes Master."
  type        = string
  default     = "10.0.1.0/24"
}

variable "jenkins_public_subnet_cidr2" {
  description = "CIDR for the Public Subnet hosting the Jenkins Master."
  type        = string
  default     = "10.0.2.0/24"
}

variable "k8s_private_app_subnet_cidr1" {
  description = "CIDR for the first Private Subnet hosting Worker Nodes."
  type        = string
  default     = "10.0.3.0/24"
}

variable "k8s_private_app_subnet_cidr2" {
  description = "CIDR for the second Private Subnet hosting Worker Nodes."
  type        = string
  default     = "10.0.4.0/24"
}

# -----------------------------------------------------------------------------
# Compute Variables
# -----------------------------------------------------------------------------

variable "k8s_master_instance_type" {
  description = "EC2 Instance type for the Kubernetes Control Plane."
  type        = string
  default     = "c7i-flex.large"
}

variable "k8s_worker_instance_type" {
  description = "EC2 Instance type for the Kubernetes Worker Nodes."
  type        = string
  default     = "t3.small"
}

variable "k8s_worker_count" {
  description = "Total number of Worker Nodes to provision."
  type        = number
  default     = 2
}

variable "jenkins_instance_type" {
  description = "EC2 Instance type for the Jenkins Server."
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "Name of the SSH Key Pair for instance access."
  type        = string
  default     = "k8s-key"
}

# -----------------------------------------------------------------------------
# Storage Variables (EBS Root Volumes)
# -----------------------------------------------------------------------------

variable "k8s_master_root_volume_size" {
  description = "Size (GB) of the root volume for the Master Node."
  type        = number
  default     = 15
}

variable "k8s_worker_root_volume_size" {
  description = "Size (GB) of the root volume for Worker Nodes."
  type        = number
  default     = 15
}

variable "jenkins_root_volume_size" {
  description = "Size (GB) of the root volume for the Jenkins Node."
  type        = number
  default     = 15
}

variable "products_bucket_name" {
  description = "Unique name for the S3 bucket storing product images."
  type        = string
  default     = "depi-products-bucket"
}

# -----------------------------------------------------------------------------
# ECR Variables
# -----------------------------------------------------------------------------

variable "ecr_repo_name_frontend" {
  description = "Name of the ECR repository for the Frontend image."
  type        = string
  default     = "depi-app-frontend"
}

variable "ecr_repo_name_backend" {
  description = "Name of the ECR repository for the Backend image."
  type        = string
  default     = "depi-app-backend"
}



