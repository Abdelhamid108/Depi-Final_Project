# modules/compute/main.tf

resource "aws_key_pair" "k8s_key" {
  key_name   = var.ssh_key_name
  public_key = file("~/.ssh/DEPI_Project_rsa.pub") # Assumes your public key is here
}

resource "aws_instance" "k8s_master" {
  ami                    = "ami-0b0012dad04fbe3d7" 
  instance_type          = var.master_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.master_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name
  tags                   = { Name = "k8s-master" }
  
  # detremine ebs size
  root_block_device {
    volume_size = var.master_root_volume_size
  }
}

resource "aws_instance" "k8s_worker" {
  count                  = var.worker_count
  ami                    = "ami-0b0012dad04fbe3d7"
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_app_subnet_id
  vpc_security_group_ids = [var.worker_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name
  tags                   = { Name = "k8s-worker-${count.index + 1}" }

  # detremine ebs size
  root_block_device {
    volume_size = var.worker_root_volume_size
  }

}
