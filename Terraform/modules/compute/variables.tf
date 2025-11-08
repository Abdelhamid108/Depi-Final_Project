# modules/compute/variables.tf

variable "master_instance_type" {}
variable "worker_instance_type" {}
variable "worker_count" {}
variable "ssh_key_name" {}
variable "public_subnet_id" {}
variable "private_app_subnet_id" {}
variable "master_sg_id" {}
variable "worker_sg_id" {}
variable "master_root_volume_size" {}
variable "worker_root_volume_size" {}
