#
# --- Root main.tf ---
# This file is the main entry point for the Terraform project.

# Configures the AWS provider, specifying the region.
# The region is passed in from a variable.
provider "aws" {
  region = var.aws_region
}

# --- Modules ---
# This block calls the 'network' module located in ./modules/network
module "network" {
  source                  = "./modules/network"
  # Pass variables to the module
  vpc_cidr                         = var.vpc_cidr
  k8s_public_subnet_cidr1          = var.k8s_public_subnet_cidr1
  jenkins_public_subnet_cidr2      = var.jenkins_public_subnet_cidr2
  k8s_private_app_subnet_cidr1     = var.k8s_private_app_subnet_cidr1
  k8s_private_app_subnet_cidr2     = var.k8s_private_app_subnet_cidr2
  aws_region                       = var.aws_region
}

# Calls the 'security_groups' module
module "security_groups" {
  source             = "./modules/security_groups"
  # Uses an output from the 'network' module as an input here
  vpc_id             = module.network.vpc_id
  vpc_cidr           = var.vpc_cidr
}

# Calls the 'compute' module to create EC2 instances
module "compute" {
  source                 = "./modules/compute"
  # Pass in instance types and counts
  jenkins_master_instance_type     = var.jenkins_instance_type
  k8s_master_instance_type         = var.k8s_master_instance_type
  k8s_worker_instance_type         = var.k8s_worker_instance_type
  k8s_worker_count                 = var.k8s_worker_count
  ssh_key_name                     = var.ssh_key_name
  # Pass in subnet and security group IDs from other modules
  k8s_public_subnet_id1            = module.network.k8s_public_subnet_id1
  jenkins_public_subnet_id2        = module.network.jenkins_public_subnet_id2
  jenkins_master_sg_id             = module.security_groups.jenkins_sg_id
  k8s_master_sg_id                 = module.security_groups.k8s_master_sg_id
  k8s_worker_sg_id                = module.security_groups.k8s_worker_sg_id
  k8s_master_root_volume_size      = var.k8s_master_root_volume_size
  k8s_worker_root_volume_size      = var.k8s_worker_root_volume_size
  jenkins_master_root_volume_size  = var.jenkins_root_volume_size

  private_app_subnet_ids = [
  module.network.k8s_private_app_subnet_id1,
  module.network.k8s_private_app_subnet_id2
  ]

}

# Calls the 's3' module
module "s3" {
  source                  = "./modules/s3"
  # Pass in the desired names for the s3 buckets
  products_bucket_name   = var.products_bucket_name
}

# Calls the 'ecr_repos' module
module "ecr_repos" {
  source                  = "./modules/ecr"
  # Pass in the desired names for the ECR repositories
  ecr_repo_name_frontend  = var.ecr_repo_name_frontend
  ecr_repo_name_backend   = var.ecr_repo_name_backend
}
