#
# --- modules/compute/main.tf ---
# This module creates the EC2 instances.

# Define the SSH key pair resource
resource "aws_key_pair" "k8s_key" {
  key_name   = var.ssh_key_name
  # Reads the public key from the specified file path
  public_key = file("~/.ssh/DEPI_Project_rsa.pub")
}

# Create the K8s Master EC2 Instance
resource "aws_instance" "k8s_master" {
  ami                    = "ami-0b0012dad04fbe3d7" # Note: This is a specific Debian AMI
  instance_type          = var.master_instance_type
  subnet_id              = var.public_subnet_id # Deploys in the public subnet
  vpc_security_group_ids = [var.master_sg_id]     # Attaches the master security group
  key_name               = aws_key_pair.k8s_key.key_name
  tags                   = { Name = "k8s-master" }
  
  # detremine ebs size
  root_block_device {
    volume_size = var.master_root_volume_size
  }
}

# Create the K8s Worker EC2 Instances
resource "aws_instance" "k8s_worker" {
  # 'count' creates multiple instances based on the var.worker_count variable
  count                  = var.worker_count
  ami                    = "ami-0b0012dad04fbe3d7"
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_app_subnet_id # Deploys in the private subnet
  vpc_security_group_ids = [var.worker_sg_id]      # Attaches the worker security group
  key_name               = aws_key_pair.k8s_key.key_name
  # 'count.index' is used to give each worker a unique name
  tags                   = { Name = "k8s-worker-${count.index + 1}" }

  # detremine ebs size
  root_block_device {
    volume_size = var.worker_root_volume_size
  }

}
