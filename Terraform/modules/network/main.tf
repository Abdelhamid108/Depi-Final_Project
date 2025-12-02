# -----------------------------------------------------------------------------
# Module: Network
# -----------------------------------------------------------------------------
# Defines the core networking infrastructure for the Kubernetes cluster.
# # -----------------------------------------------------------------------------
# Module: Network
# -----------------------------------------------------------------------------
# Defines the core networking infrastructure for the Kubernetes cluster.
# - VPC: The isolated network environment.
# - Subnets: Public (for Master/Jenkins) and Private (for Workers).
# - Gateways: Internet Gateway (IGW) for public access, NAT Gateway for private outbound.
# - Route Tables: Routing rules for public and private subnets.
# -----------------------------------------------------------------------------

# ########################################
# VPC (Virtual Private Cloud)
# ########################################
resource "aws_vpc" "k8s_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "k8s-vpc"
  }
}

# ########################################
# Internet Gateway (for Public Subnet)
# ########################################
# Allows resources in the public subnet to access the internet directly.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-igw"
  }
}

# ########################################
# Public Subnets
# ########################################

# Public Subnet 1: Hosted in AZ-a
# Intended for: Kubernetes Master Node (Control Plane)
# Tags: 'kubernetes.io/role/elb' = '1' allows AWS Load Balancers to discover this subnet.
resource "aws_subnet" "k8s_public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.k8s_public_subnet_cidr1
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name                                   = "k8s-public-subnet-1"
    "kubernetes.io/cluster/kubernetes"     = "shared" # Required for K8s Cloud Provider
    "kubernetes.io/role/elb"               = "1"      # Identifies as public subnet for ELB
  }
}

# Public Subnet 2: Hosted in AZ-b
# Intended for: Jenkins Master Node
resource "aws_subnet" "jenkins_public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.jenkins_public_subnet_cidr2
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name                                   = "jenkins-public-subnet-2"
    "kubernetes.io/cluster/kubernetes"     = "shared"
    "kubernetes.io/role/elb"               = "1"
  }
}

# ########################################
# Private Subnets
# ########################################

# Private Subnet 1: Hosted in AZ-b
# Intended for: Kubernetes Worker Nodes
# Tags: 'kubernetes.io/role/internal-elb' = '1' allows Internal Load Balancers.
resource "aws_subnet" "k8s_private_app_subnet1" {
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = var.k8s_private_app_subnet_cidr1
  availability_zone = "${var.aws_region}b"

  tags = {
    Name                                   = "k8s-private-app-subnet1"
    "kubernetes.io/cluster/kubernetes"     = "shared"
    "kubernetes.io/role/internal-elb"      = "1" # Identifies as private subnet for Internal ELB
  }
}

# Private Subnet 2: Hosted in AZ-a
# Intended for: Kubernetes Worker Nodes (High Availability)
resource "aws_subnet" "k8s_private_app_subnet2" {
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = var.k8s_private_app_subnet_cidr2
  availability_zone = "${var.aws_region}a"

  tags = {
    Name                                   = "k8s-private-app-subnet2"
    "kubernetes.io/cluster/kubernetes"     = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}

# ########################################
# Public Route Table
# ########################################
# Routes traffic from public subnets to the Internet Gateway.
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "k8s-public-rt"
  }
}

# Associate Public Subnet 1 with Public Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.k8s_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_assoc2" {
  subnet_id      = aws_subnet.jenkins_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# ########################################
# NAT Gateway (Network Address Translation)
# ########################################
# Allows instances in private subnets to access the internet (e.g., for updates)
# without exposing them to inbound internet traffic.

# Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "k8s-nat-eip"
  }
}

# NAT Gateway Resource (Placed in a Public Subnet)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.k8s_public_subnet.id

  tags = {
    Name = "k8s-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ########################################
# Private Route Table
# ########################################
# Routes traffic from private subnets to the NAT Gateway.
resource "aws_route_table" "private_app_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "k8s-private-app-rt"
  }
}

# Associate Private Subnet 1 with Private Route Table
resource "aws_route_table_association" "private_app_assoc1" {
  subnet_id      = aws_subnet.k8s_private_app_subnet1.id
  route_table_id = aws_route_table.private_app_rt.id
}

# Associate Private Subnet 2 with Private Route Table
resource "aws_route_table_association" "private_app_assoc2" {
  subnet_id      = aws_subnet.k8s_private_app_subnet2.id
  route_table_id = aws_route_table.private_app_rt.id
}
