[jenkins_masters]
jenkins_master-node           ansible_host=${jenkins_master_public_ip}

[k8s_masters]   
master-node           ansible_host=${k8s_master_public_ip}

[k8s_workers]
#loop for assigning nodes to theire ips dynamically using terrafrom outputs
%{ for i, ip in k8s_worker_private_ips }
worker-node-${i+1}    ansible_host=${ip}
%{ endfor }         

[k8s_cluster:children]
k8s_masters
k8s_workers

[all:vars]
backend_ecr=${backend_ecr_name}
frontend_ecr=${frontend_ecr_name}
products_bucket=${products_bucket_name}


