

# Terraform AWS Infrastructure Documentation


## 1. Project Overview

This Terraform project provisions the AWS infrastructure for a **Kubernetes (K8s) cluster** hosting the **Amazona e-commerce application**.

It creates:

* A **custom VPC** with public and private subnets
* **Security Groups** for network isolation
* **EC2 instances** for master and worker nodes
* **ECR repositories** for frontend & backend Docker images
* An **S3 bucket** for application and infrastructure logs

The infrastructure is modular and maintainable, separating **networking**, **security**, and **compute** resources for flexibility.

---

## 2. Infrastructure Structure

![Project Infrastructure](https://drive.google.com/uc?id=103VBAeZGVW4RrXHvCI4p2cOpu6au7-V2)

###  VPC

* **CIDR Block:** `10.0.0.0/16`
* Provides isolated networking for all resources.

---

###  Subnets

* **Public Subnet (`10.0.1.0/24`)**

  * Hosts public resources like the K8s Master and NAT Gateway.
  * Connected to an Internet Gateway for external access.

* **Private App Subnet (`10.0.2.0/24`)**

  * Hosts worker nodes that should remain private.
  * Accesses the internet via the NAT Gateway.

---

###  Networking Components

* **Internet Gateway (IGW):** Provides internet access to public subnet.
* **NAT Gateway:** Allows private subnet instances to access the internet.
* **Elastic IP (EIP):** Assigned to the NAT Gateway for consistent outbound IP.

---

###  Security Groups

* **Master Security Group**

  * Allows SSH (`22`) and Jenkins (`8080`) access.
  * Allows traffic on Kube API port (`6443`) from worker nodes.

* **Worker Security Group**

  * Allows full traffic from master node and intra-worker communication.
  * Allows HTTP (`80`) traffic from the public subnet.

---

###  EC2 Instances

* **Master Node (x1):**

  * Deployed in public subnet for management and orchestration.
  * Accessible via SSH and Ansible.

* **Worker Nodes (x2):**

  * Deployed in private subnet for application workloads.
  * Number configurable via variable `worker_count`.

---

###  ECR (Elastic Container Registry)

* **Frontend Repository:** Stores `depi-app-frontend` Docker images.
* **Backend Repository:** Stores `depi-app-backend` Docker images.

---

###  S3 (Simple Storage Service)

* **Logs Bucket:** Centralized location for logs from applications and infrastructure.

---

## 3. File Structure

```bash
Terraform/
├── main.tf               # Entry point for provider setup and module calls
├── variables.tf          # Input variable declarations and defaults
├── outputs.tf            # Declared Terraform outputs
├── s3.tf                 # S3 bucket for log storage
├── .terraform.lock.hcl   # Provider version lock file
│
└── modules/
    ├── compute/          # EC2 Instances (Master/Workers)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── ecr/              # ECR Repositories
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── network/          # VPC, Subnets, IGW, NAT Gateway
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── security_groups/  # Security Group Definitions
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 4. How to Use This Terraform Setup

###  Prerequisites

1. **AWS Account & Credentials**

   ```bash
   aws configure
   ```

2. **Terraform CLI**

   * Install Terraform v1.0.0+
   * [Terraform Installation Guide](https://developer.hashicorp.com/terraform/downloads)

3. **SSH Key Pair**

   * Ensure your public key exists:

     ```bash
     ~/.ssh/DEPI_Project_rsa.pub
     ```
   * Update its path in `modules/compute/main.tf` if different.

---

###  Step 1: Configuration (Optional)

Create a `terraform.tfvars` file in the root directory to override defaults.

**Example:**

```hcl
# Required variable
logs_s3_bucket_name = "your-unique-bucket-name-12345"

# Optional overrides
aws_region            = "us-east-1"
worker_count          = 3
master_instance_type  = "t3.medium"
```

---

###  Step 2: Initialize Terraform

```bash
terraform init
```

Initializes providers and module dependencies.

---

###  Step 3: Plan the Deployment

```bash
terraform plan
```

Previews resources that will be created.
✅ Review carefully before proceeding.

---

###  Step 4: Apply the Configuration

```bash
terraform apply
```

Type `yes` to confirm.
Terraform provisions all AWS resources — including the VPC, EC2s, ECR, and S3 bucket.

---

###  Step 5: Review Outputs

Example output:

```bash
Outputs:

backend_ecr_repo_url  = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/depi-app-backend"
frontend_ecr_repo_url = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/depi-app-frontend"
logs_s3_bucket_name   = "your-unique-bucket-name-12345"
master_public_ip      = "54.12.34.56"
worker_private_ips    = [
  "10.0.2.18",
  "10.0.2.86",
]
```

**Usage Tips:**

* `master_public_ip`: Add to **Ansible hosts.ini** under `[master-node]`.
* `worker_private_ips`: Add under `[worker-nodes]`.
* `*_ecr_repo_url`: Use in Jenkins pipelines for Docker push operations.

---

###  Step 6: Destroy the Infrastructure

To remove all created AWS resources:

```bash
terraform destroy
```

Type `yes` to confirm.

---

##  Summary

This Terraform setup provides a **complete AWS foundation** for a production-ready Kubernetes cluster — including secure networking, scalable EC2 nodes, and managed registries for CI/CD pipelines.

---

