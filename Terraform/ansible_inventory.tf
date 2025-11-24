# This resource generates the Ansible inventory file dynamically
# after 'terraform apply' completes, using the outputs from the compute module and ecr module.

resource "local_file" "ansible_inventory" {
  # This path goes up one level and into the Ansible inventory directory
  filename = "../Ansible/inventory/hosts.ini"

  content = templatefile("${path.module}/ansible_inventory.tpl", {
    master_public_ip   = module.compute.master_public_ip
    worker_private_ips = module.compute.worker_private_ips
    backend_ecr_name = module.ecr.backend_repo_url
    frontend_ecr_name = module.ecr.frontend_repo_url
    
  })
}
