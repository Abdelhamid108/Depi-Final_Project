#
# --- modules/security_groups/main.tf ---
# This module creates the security groups for master and worker nodes.

# 1. Create the Master Security Group
resource "aws_security_group" "k8s_master_sg" {
  name        = "k8s-master-sg"
  description = "Allow traffic for K8s master node"
  vpc_id      = var.vpc_id

  # Allow SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Jenkins UI access from anywhere
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "k8s-master-sg" }
}

# 2. Create the Worker Security Group
resource "aws_security_group" "k8s_worker_sg" {
  name        = "k8s-worker-sg"
  description = "Allow traffic for K8s worker nodes"
  vpc_id      = var.vpc_id

  # Allow workers to talk to each other
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow HTTP traffic from the public subnet (e.g., from a load balancer)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "k8s-worker-sg" }
}

# 3. Create connecting rules separately
# Rule for Master to accept traffic from Workers on port 6443 (Kube API)
resource "aws_security_group_rule" "master_allow_worker_api" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k8s_master_sg.id
  source_security_group_id = aws_security_group.k8s_worker_sg.id
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  description              = "Allow workers to talk to Kube API"
}

# Rule for Workers to accept all traffic from Master
resource "aws_security_group_rule" "worker_allow_master_all" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k8s_worker_sg.id
  source_security_group_id = aws_security_group.k8s_master_sg.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "Allow master to send all traffic to workers"
}
