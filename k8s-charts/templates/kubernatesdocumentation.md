# Kubernetes System Documentation

Kubernetes System Documentation
Project: DEPI Final Project – Kubernetes Cluster
Version: 1.0
Last Updated: 2025-11-29

---

## 1️⃣ System Overview

This document describes the Kubernetes infrastructure deployed on **AWS EC2** using **Kubeadm + Ansible automation**. It manages the full lifecycle of the Kubernetes cluster, including networking, configuration, monitoring, and ingress exposure.

The cluster supports deployment of containerized applications from the CI/CD pipeline (Jenkins + ECR), while enabling observability using **Prometheus + Grafana**.

---

## 1.1 High‑Level Architecture

The Kubernetes infrastructure consists of:

| Component                         | Instances  | Location        | Purpose                           |
| --------------------------------- | ---------- | --------------- | --------------------------------- |
| Kubernetes Master (Control Plane) | 1          | Public Subnet   | Cluster control + API Server      |
| Kubernetes Workers                | 2          | Private Subnets | Application workloads + NodePorts |
| Ingress Controller (NGINX)        | On Workers | Private Subnets | User access routing               |
| Prometheus + Grafana              | On Workers | Private Subnets | Monitoring + Observability        |

**Bastion SSH Access** is allowed through the K8s Master.
Workers access the Internet via NAT Gateway → for nodes package updates + image pulls.
--------------------------------------------------------------------------------------

## 1.2 Integration Diagram (Logical)

```
     Jenkins (EC2 Public)
             |
             | CI/CD Deploy (Kubectl via SSH)
             v
       K8s API Server (Master)
             |
   ---------------------------
   |            |            |
Worker 1     Worker 2     Monitoring Stack
 (Apps)       (Apps)     (Prometheus/Grafana)
```

---

## 2️⃣ Directory Structure (Ansible)

```
Ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── site.yml                      # Main orchestrator playbook
├── roles/
│   ├── prerequisites/            # Docker + Kernel + Swap off
│   ├── master/                   # Kubeadm init + Cluster config
│   ├── workers/                  # Join workers to cluster
│   ├── networking/               # Calico CNI
│   ├── ingress/                  # NGINX ingress controller
│   ├── monitoring/               # Prometheus + Grafana stack
│   └── deployment/               # Sample app deployment
└── group_vars/
    ├── master.yml
    ├── workers.yml
    └── global.yml
```

---

## 3️⃣ Cluster Deployment Breakdown

### 3.1 Prerequisites Role

* Disable Swap
* Enable Kernel modules (overlay + br_netfilter)
* Install Docker Engine + container runtime config
* Configure CRI‐Docker or containerd
* Add required sysctl:

```
net.bridge.bridge-nf-call-iptables=1
```

---

### 3.2 Kubernetes Master Role

Actions executed on Master Node:

* Install kubeadm, kubelet, kubectl
* Initialize Control Plane

```
kubeadm init --pod-network-cidr=192.168.0.0/16
```

* Save kubeconfig for admin nodes
* Generate **kubeadm join token** for workers
* Copy admin.conf to /home/ubuntu/.kube/

Outputs:

* API Server Public IP
* Kubernetes Dashboard token (optional)

---

### 3.3 Workers Role

Executed on each Worker Node:

* Install kubeadm & dependencies
* Join cluster

```
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

---

### 3.4 Networking Role (Calico CNI)

* Deploy Calico using official manifest
* Enables:

  * Pod networking
  * Network Policy

---

### 3.5 Ingress Role – NGINX

* Installed as DaemonSet on workers
* Exposes applications using:

  * NodePort Services
  * Ingress Resources

---

### 3.6 Monitoring Role – Prometheus + Grafana

* Installed using **Helm charts**
* Prometheus scrapes:

  * kubelet
  * API Server
  * cAdvisor
* Grafana displays visual dashboards

Default dashboards include:
✔️ Cluster usage
✔️ Node health
✔️ Pod resource usage

Grafana default credentials:

```
admin / admin
```

(Recommended to change)

---

## 4️⃣ Deployment SOP

### Requirements

* Ansible Installed
* SSH key for authentication (same as Terraform: `k8s-key`)
* Terraform outputs populated correctly

---

### Installation Steps

```
cd Ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

Total automation time: ~10–15 min

Final verification:

```
kubectl get nodes
kubectl get pods -A
```

---

## 5️⃣ Integration Notes

| Feature                      | Method                                                       |
| ---------------------------- | ------------------------------------------------------------ |
| Jenkins deploys applications | SSH → Master → kubectl apply                                 |
| Images stored                | AWS ECR repos (frontend & backend)                           |
| Observability                | Prometheus + Grafana dashboards                              |
| Public access                | NGINX Ingress + NodePort exposed only through Master/Bastion |

All credentials and kubeconfig managed centrally on Master.

---

## 6️⃣ Troubleshooting

| Issue                          | Cause                         | Fix                                                   |
| ------------------------------ | ----------------------------- | ----------------------------------------------------- |
| Nodes NotReady                 | CNI not installed or failed   | `kubectl get pods -n kube-system` & restart Calico    |
| Token expired                  | kubeadm token TTL             | Recreate: `kubeadm token create --print-join-command` |
| Pod stuck in ContainerCreating | Storage or cgroup error       | Restart container runtime on workers                  |
| Dashboards empty               | Prometheus not scraping nodes | Restart kube-prometheus-stack Helm release            |

---

## 7️⃣ Security Recommendations

* Use private communication between nodes only
* Limit SSH to known IPs
* Rotate tokens and kubeconfig regularly
* Enable RBAC authorization
* Enable automatic image scanning in ECR

---

## 8️⃣ Future Enhancements

✔️ Kubernetes Dashboard
✔️ Cluster Autoscaler
✔️ HPA (Horizontal Pod Autoscaler)
✔️ Loki + Grafana Logs
✔️ TLS Certificates via Cert‑Manager

---


