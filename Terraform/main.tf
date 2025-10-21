# main.tf

provider "aws" {
  region = var.aws_region
}

module "network" {
  source                = "./modules/network"
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_app_subnet_cidr = var.private_app_subnet_cidr
  aws_region            = var.aws_region
}

module "security_groups" {
  source             = "./modules/security_groups"
  vpc_id             = module.network.vpc_id
  public_subnet_cidr = var.public_subnet_cidr
}

module "compute" {
  source                 = "./modules/compute"
  master_instance_type   = var.master_instance_type
  worker_instance_type   = var.worker_instance_type
  worker_count           = var.worker_count
  ssh_key_name           = var.ssh_key_name
  public_subnet_id       = module.network.public_subnet_id
  private_app_subnet_id  = module.network.private_app_subnet_id
  master_sg_id           = module.security_groups.master_sg_id
  worker_sg_id           = module.security_groups.worker_sg_id
}

# Add the ECR module here
module "ecr_repos" {
  source                  = "./modules/ecr"
  ecr_repo_name_frontend  = var.ecr_repo_name_frontend
  ecr_repo_name_backend   = var.ecr_repo_name_backend
}
