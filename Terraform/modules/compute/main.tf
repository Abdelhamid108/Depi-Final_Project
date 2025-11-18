# --- modules/compute/main.tf ---
# This module creates the EC2 instances.

# ------------------------------------------------------------
# SSH Key Pair
# ------------------------------------------------------------
resource "aws_key_pair" "k8s_key" {
  key_name   = var.ssh_key_name
  public_key = file("~/.ssh/DEPI_Project_rsa.pub")
}

# ------------------------------------------------------------
# IAM Roles
# ------------------------------------------------------------

# Master Role
resource "aws_iam_role" "master_role" {
  name = "master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "k8s_master_role" }
}

# Worker Role
resource "aws_iam_role" "worker_role" {
  name = "worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "k8s_worker_role" }
}

# ------------------------------------------------------------
# POLICIES - MASTER
# ------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "matser_ebs_policy" {
  role       = aws_iam_role.master_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "http" "lbc_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.lbc_policy_json.response_body
}

resource "aws_iam_role_policy_attachment" "matser_lbc_policy" {
  role       = aws_iam_role.master_role.name
  policy_arn = aws_iam_policy.lbc_policy.arn
}

resource "aws_iam_role_policy_attachment" "master_ec2_read" {
  role       = aws_iam_role.master_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# ------------------------------------------------------------
# POLICIES - WORKER
# ------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "worker_ecr_policy" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "worker_lbc_policy" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.lbc_policy.arn
}

resource "aws_iam_role_policy_attachment" "worker_ebs_csi" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
resource "aws_iam_role_policy_attachment" "worker_ec2_full" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}


# ------------------------------------------------------------
# Instance Profiles
# ------------------------------------------------------------

resource "aws_iam_instance_profile" "master_profile" {
  name = "k8s-master-profile"
  role = aws_iam_role.master_role.name
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "k8s-worker-profile"
  role = aws_iam_role.worker_role.name
}

# ------------------------------------------------------------
# EC2 MASTER NODE
# ------------------------------------------------------------

resource "aws_instance" "k8s_master" {
  ami                    = "ami-0cae6d6fe6048ca2c"
  instance_type          = var.master_instance_type
  subnet_id              = var.public_subnet_id1          # Master is public
  vpc_security_group_ids = [var.master_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name

  # Root Volume
  root_block_device {
    volume_size = var.master_root_volume_size
  }
  
   metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "optional"
  http_put_response_hop_limit = 2
  }


  iam_instance_profile = aws_iam_instance_profile.master_profile.name

  tags = {
    Name                               = "k8s-master"
    "kubernetes.io/cluster/kubernetes" = "shared"
    "k8s.io/role/master"               = "1"
  }
}

# ------------------------------------------------------------
# EC2 WORKER NODES
# ------------------------------------------------------------

resource "aws_instance" "k8s_worker" {
  count                  = var.worker_count
  ami                    = "ami-0cae6d6fe6048ca2c"
  instance_type          = var.worker_instance_type
  subnet_id = var.private_app_subnet_ids[count.index % length(var.private_app_subnet_ids)]
  vpc_security_group_ids = [var.worker_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name

  root_block_device {
    volume_size = var.worker_root_volume_size
  }
  metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "optional"
  http_put_response_hop_limit = 2
  }
  iam_instance_profile = aws_iam_instance_profile.worker_profile.name

  tags = {
    Name                               = "k8s-worker-${count.index + 1}"
    "kubernetes.io/cluster/kubernetes" = "shared"
    "k8s.io/role/node"                 = "1"
  }
}

