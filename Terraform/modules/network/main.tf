#
# --- modules/network/main.tf ---
# This module creates the core networking infrastructure.

# Create the Virtual Private Cloud (VPC)
resource "aws_vpc" "k8s_vpc" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "k8s-vpc" }
}

# Create an Internet Gateway (IGW) to allow internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags   = { Name = "k8s-igw" }
}

# Create the Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.public_subnet_cidr
  # Automatically assign public IPs to instances launched here
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "k8s-public-subnet" }
}

# Create the Private Application Subnet
resource "aws_subnet" "private_app_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.private_app_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "k8s-private-app-subnet" }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  # Add a route to the internet (0.0.0.0/0) via the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "k8s-public-rt" }
}

# Associate the Public Route Table with the Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create an Elastic IP (static IP) for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain   = "vpc"
  tags   = { Name = "k8s-nat-eip" }
}

# Create a NAT Gateway in the Public Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags          = { Name = "k8s-nat-gw" }
  # Ensure the IGW is created before the NAT Gateway
  depends_on    = [aws_internet_gateway.igw]
}

# Create a Route Table for the Private Subnet
resource "aws_route_table" "private_app_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  # Add a route to the internet (0.0.0.0/0) via the NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "k8s-private-app-rt" }
}

# Associate the Private Route Table with the Private Subnet
resource "aws_route_table_association" "private_app_assoc" {
  subnet_id      = aws_subnet.private_app_subnet.id
  route_table_id = aws_route_table.private_app_rt.id
}
