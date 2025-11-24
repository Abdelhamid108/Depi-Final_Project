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
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidr1      = var.public_subnet_cidr1
  public_subnet_cidr2      = var.public_subnet_cidr2
  private_app_subnet_cidr1 = var.private_app_subnet_cidr1
  private_app_subnet_cidr2 = var.private_app_subnet_cidr2
  aws_region              = var.aws_region
}

# Calls the 'security_groups' module
module "security_groups" {
  source             = "./modules/security_groups"
  # Uses an output from the 'network' module as an input here
  vpc_id             = module.network.vpc_id
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr1 = var.public_subnet_cidr1
}

# Calls the 'compute' module to create EC2 instances
module "compute" {
  source                 = "./modules/compute"
  # Pass in instance types and counts
  master_instance_type   = var.master_instance_type
  worker_instance_type   = var.worker_instance_type
  worker_count           = var.worker_count
  ssh_key_name           = var.ssh_key_name
  # Pass in subnet and security group IDs from other modules
  public_subnet_id1       = module.network.public_subnet_id1
  master_sg_id           = module.security_groups.master_sg_id
  worker_sg_id           = module.security_groups.worker_sg_id
  master_root_volume_size = var.master_root_volume_size
  worker_root_volume_size = var.worker_root_volume_size
  private_app_subnet_ids = [
  module.network.private_app_subnet_id1,
  module.network.private_app_subnet_id2
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
