# modules/network/outputs.tf

output "vpc_id" { value = aws_vpc.k8s_vpc.id }
output "public_subnet_id" { value = aws_subnet.public_subnet.id }
output "private_app_subnet_id" { value = aws_subnet.private_app_subnet.id }
