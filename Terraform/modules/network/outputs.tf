# modules/network/outputs.tf
output "vpc_id" {
  value = aws_vpc.k8s_vpc.id
}

output "public_subnet_id1" {
  value = aws_subnet.public_subnet.id
}

output "public_subnet_id2" {
  value = aws_subnet.public_subnet2.id
}

output "private_app_subnet_id1" {
  value = aws_subnet.private_app_subnet1.id
}

output "private_app_subnet_id2" {
  value = aws_subnet.private_app_subnet2.id
}

