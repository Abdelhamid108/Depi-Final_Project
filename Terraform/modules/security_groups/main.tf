# -----------------------------------------------------------------------------
# Module: Security Groups
# -----------------------------------------------------------------------------
# Defines network security boundaries (firewalls) for the infrastructure.
# - Master SG: Controls access to the Kubernetes Control Plane.
# - Worker SG: Controls access to Worker Nodes (NodePorts, Pod-to-Pod).
# - Jenkins SG: Controls access to the Jenkins Master.
# -----------------------------------------------------------------------------

# ==========================================
# 1. Security Group Definitions 
# ==========================================

# Security Group for Kubernetes Master Node
resource "aws_security_group" "k8s_master_sg" {
  name        = "k8s-master-sg"
  description = "Security Group for Kubernetes Master"
  vpc_id      = var.vpc_id

  tags = {
    Name = "k8s-master-sg"
    "kubernetes.io/cluster/kubernetes" = "shared" # Required for AWS Cloud Provider
  }
}

# Security Group for Kubernetes Worker Nodes
resource "aws_security_group" "k8s_worker_sg" {
  name        = "k8s-worker-sg"
  description = "Security Group for Kubernetes Workers"
  vpc_id      = var.vpc_id

  tags = {
    Name = "k8s-worker-sg"
    "kubernetes.io/cluster/kubernetes" = "shared"
  }
}

# Security Group for Jenkins Master
resource "aws_security_group" "jenkins_master_sg" {
  name        = "jenkins-master-sg"
  description = "security group for jenkins master"
  vpc_id      = var.vpc_id

  tags = {
    Name = "jenkins-master-sg"
  }
}

# ==========================================
# 2. Egress Rules (Outbound Traffic)
# ==========================================
# By default, allow all outbound traffic from all groups.
# This enables downloading packages, updates, and external API calls.

resource "aws_security_group_rule" "k8s_master_egress" {
  type              = "egress"
  security_group_id = aws_security_group.k8s_master_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "k8s_worker_egress" {
  type              = "egress"
  security_group_id = aws_security_group.k8s_worker_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "jenkins_master_egress" {
  type              = "egress"
  security_group_id = aws_security_group.jenkins_master_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ==========================================
# 3. Master Node Ingress Rules
# ==========================================

# Allow SSH access (Port 22) for administration
resource "aws_security_group_rule" "k8s_master_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.k8s_master_sg.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow Jenkins to access Master (Port 8080 - if Master runs Jenkins agent)
resource "aws_security_group_rule" "k8s_master_jenkins" {
  type              = "ingress"
  security_group_id = aws_security_group.k8s_master_sg.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow ALL traffic from Workers
# Required for:
# - API Server access (6443)
# - Etcd communication (2379-2380)
# - CNI/Overlay networking (VXLAN/BGP)
resource "aws_security_group_rule" "k8s_master_from_workers" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k8s_master_sg.id
  source_security_group_id = aws_security_group.k8s_worker_sg.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "Allow all traffic from workers"
}

# ==========================================
# 4. Worker Node Ingress Rules
# ==========================================

# Allow ALL traffic from Master
# Required for:
# - Kubelet API access
# - `kubectl logs/exec` commands
resource "aws_security_group_rule" "k8s_worker_from_master" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k8s_worker_sg.id
  source_security_group_id = aws_security_group.k8s_master_sg.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "Allow all traffic from master"
}

# Allow workers to communicate with each other
# Critical for Pod-to-Pod communication across nodes
resource "aws_security_group_rule" "k8s_worker_from_self" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k8s_worker_sg.id
  source_security_group_id = aws_security_group.k8s_worker_sg.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  description              = "Allow workers to talk to each other (Pod-to-Pod)"
}

# Allow external Load Balancers to access NodePorts (30000-32767)
# This enables the AWS Classic Load Balancer to route traffic to services
resource "aws_security_group_rule" "k8s_worker_nodeports" {
  type              = "ingress"
  security_group_id = aws_security_group.k8s_worker_sg.id
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow external Load Balancers to access NodePorts"
}

# Allow Jenkins Master to SSH into Workers (for Agent setup)
resource "aws_security_group_rule" "jenkins_worker_ssh" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k8s_worker_sg.id
  source_security_group_id = aws_security_group.jenkins_master_sg.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "Allow external Jenkins Master to connect to k8s_workers using ssh"
}

# ==========================================
# 5. Jenkins Master Ingress Rules
# ==========================================

# Allow SSH access
resource "aws_security_group_rule" "jenkins_master_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.jenkins_master_sg.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow HTTP access to Jenkins UI (Port 8080)
resource "aws_security_group_rule" "jenkins_master_jenkins" {
  type              = "ingress"
  security_group_id = aws_security_group.jenkins_master_sg.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
} 

# Allow JNLP Agent communication (Port 50000)
resource "aws_security_group_rule" "jenkins_master_jenkins_agents" {
  type              = "ingress"
  security_group_id = aws_security_group.jenkins_master_sg.id
  from_port         = 50000
  to_port           = 50000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow Jenkins to access Kubernetes API Server (6443)
# Note: This rule is on the Jenkins SG, but typically this should be an egress rule
# or an ingress rule on the K8s Master SG allowing Jenkins.
# Assuming this is intended to allow inbound return traffic or self-referencing.
resource "aws_security_group_rule" "jenkins_master_k8s_api" {
  type              = "ingress"
  security_group_id = aws_security_group.jenkins_master_sg.id
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

