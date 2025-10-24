# modules/network/main.tf

resource "aws_vpc" "k8s_vpc" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "k8s-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags   = { Name = "k8s-igw" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "k8s-public-subnet" }
}

resource "aws_subnet" "private_app_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.private_app_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "k8s-private-app-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "k8s-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip" {
  domain   = "vpc"
  tags   = { Name = "k8s-nat-eip" }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags          = { Name = "k8s-nat-gw" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_app_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "k8s-private-app-rt" }
}

resource "aws_route_table_association" "private_app_assoc" {
  subnet_id      = aws_subnet.private_app_subnet.id
  route_table_id = aws_route_table.private_app_rt.id
}
