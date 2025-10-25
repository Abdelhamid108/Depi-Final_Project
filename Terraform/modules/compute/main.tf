# modules/compute/main.tf

resource "aws_key_pair" "k8s_key" {
  key_name   = var.ssh_key_name
  public_key = file("~/.ssh/DEPI_Project_rsa.pub") # Assumes your public key is here
}

resource "aws_instance" "k8s_master" {
  ami                    = "ami-07860a2d7eb515d9a" 
  instance_type          = var.master_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.master_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name
  tags                   = { Name = "k8s-master" }
}

resource "aws_instance" "k8s_worker" {
  count                  = var.worker_count
  ami                    = "ami-07860a2d7eb515d9a"
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_app_subnet_id
  vpc_security_group_ids = [var.worker_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name
  tags                   = { Name = "k8s-worker-${count.index + 1}" }
}
