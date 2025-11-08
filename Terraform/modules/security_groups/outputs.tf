# modules/security_groups/outputs.tf

output "master_sg_id" { value = aws_security_group.k8s_master_sg.id }
output "worker_sg_id" { value = aws_security_group.k8s_worker_sg.id }
