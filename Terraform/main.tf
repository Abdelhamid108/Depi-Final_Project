# -----------------------------------------------------------------------------
# Terraform Main Configuration
# -----------------------------------------------------------------------------
# This file serves as the entry point for the Terraform project.
# It orchestrates the deployment of the entire AWS infrastructure stack.
#
# Architecture Overview:
# 1. Network: VPC, Subnets (Public/Private), Gateways, Route Tables.
# 2. Security: Security Groups for firewalling access.
# 3. Compute: EC2 Instances for Kubernetes (Master/Workers) and Jenkins.
# 4. Storage: S3 Buckets for application assets.
# 5. Registry: ECR Repositories for Docker images.
# -----------------------------------------------------------------------------

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Network Module
# -----------------------------------------------------------------------------
# Provisions the fundamental networking layer.
# - VPC: The isolated network container.
# - Subnets: Segregates resources (Public for access, Private for security).
module "network" {
  source                       = "./modules/network"
  vpc_cidr                     = var.vpc_cidr
  k8s_public_subnet_cidr1      = var.k8s_public_subnet_cidr1
  jenkins_public_subnet_cidr2  = var.jenkins_public_subnet_cidr2
  k8s_private_app_subnet_cidr1 = var.k8s_private_app_subnet_cidr1
  k8s_private_app_subnet_cidr2 = var.k8s_private_app_subnet_cidr2
  aws_region                   = var.aws_region
}

# -----------------------------------------------------------------------------
# Security Groups Module
# -----------------------------------------------------------------------------
# Defines the firewall rules (Security Groups) to control traffic flow.
# - Jenkins SG: Access to Jenkins UI and Agents.
# - K8s Master SG: Control Plane access.
# - K8s Worker SG: Data Plane and Pod-to-Pod communication.
module "security_groups" {
  source   = "./modules/security_groups"
  vpc_id   = module.network.vpc_id
  vpc_cidr = var.vpc_cidr
}

# -----------------------------------------------------------------------------
# Compute Module
# -----------------------------------------------------------------------------
# Provisions the actual servers (EC2 Instances) and their IAM roles.
# - K8s Master: The brain of the cluster.
# - K8s Workers: Where application pods run.
# - Jenkins Master: The CI/CD orchestration server.
module "compute" {
  source                          = "./modules/compute"
  jenkins_master_instance_type    = var.jenkins_instance_type
  k8s_master_instance_type        = var.k8s_master_instance_type
  k8s_worker_instance_type        = var.k8s_worker_instance_type
  k8s_worker_count                = var.k8s_worker_count
  ssh_key_name                    = var.ssh_key_name
  
  # Network & Security Associations
  k8s_public_subnet_id1           = module.network.k8s_public_subnet_id1
  jenkins_public_subnet_id2       = module.network.jenkins_public_subnet_id2
  jenkins_master_sg_id            = module.security_groups.jenkins_sg_id
  k8s_master_sg_id                = module.security_groups.k8s_master_sg_id
  k8s_worker_sg_id                = module.security_groups.k8s_worker_sg_id
  
  # Storage Configuration (Root Volumes)
  k8s_master_root_volume_size     = var.k8s_master_root_volume_size
  k8s_worker_root_volume_size     = var.k8s_worker_root_volume_size
  jenkins_master_root_volume_size = var.jenkins_root_volume_size

  # Subnet Distribution for Workers
  private_app_subnet_ids = [
    module.network.k8s_private_app_subnet_id1,
    module.network.k8s_private_app_subnet_id2
  ]
}

# -----------------------------------------------------------------------------
# S3 Module
# -----------------------------------------------------------------------------
# Creates S3 buckets for persistent object storage.
# - Used for: Storing product images and other static assets.
module "s3" {
  source               = "./modules/s3"
  products_bucket_name = var.products_bucket_name
}

# -----------------------------------------------------------------------------
# ECR Module
# -----------------------------------------------------------------------------
# Creates Elastic Container Registries (Docker Hub alternatives).
# - Frontend Repo: Stores React app images.
# - Backend Repo: Stores Node.js API images.
module "ecr_repos" {
  source                 = "./modules/ecr"
  ecr_repo_name_frontend = var.ecr_repo_name_frontend
  ecr_repo_name_backend  = var.ecr_repo_name_backend
}


