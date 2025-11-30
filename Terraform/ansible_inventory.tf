# This resource generates the Ansible inventory file dynamically
# after 'terraform apply' completes, using the outputs from the compute module and ecr module.

resource "local_file" "ansible_inventory" {
  # This path goes up one level and into the Ansible inventory directory
  filename = "../Ansible/inventory/hosts.ini"

  content = templatefile("${path.module}/ansible_inventory.tpl", {
    k8s_master_public_ip     = module.compute.k8s_master_public_ip
    k8s_worker_private_ips   = module.compute.k8s_worker_private_ips
    jenkins_master_public_ip = module.compute.jenkins_master_public_ip
    aws_access_key           = module.s3.s3_user_acess_key
    aws_secret_key           = module.s3.s3_user_secret_key
    
  })
}
