[masters]
master-node           ansible_host=${master_public_ip}

[workers]
#loop for assigning nodes to theire ips dynamically using terrafrom outputs
%{ for i, ip in worker_private_ips }
worker-node-${i+1}    ansible_host=${ip}
%{ endfor }         

[k8s_cluster:children]
masters
workers

[all:vars]
backend_ecr=${backend_ecr_name}
frontend_ecr=${frontend_ecr_name}


