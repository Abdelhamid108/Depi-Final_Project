# Kubernetes & Helm System Documentation

**Project:** Depi Final Project Infrastructure  
**Version:** 1.1  
**Last Updated:** 2025-11-29

## 1. System Overview

This documentation provides a technical reference for the self-managed Kubernetes infrastructure and the "Amazona" E-commerce Helm chart. The system leverages a decoupled Control Plane and Data Plane architecture on AWS EC2, orchestrated via Kubeadm and Ansible.

### 1.1. Self-Managed Cluster Architecture
Unlike managed services (EKS), this cluster is fully self-managed, providing complete control over the Control Plane components and configuration.

*   **Control Plane (Master Node)**:
    *   **Component**: `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `etcd`.
    *   **Host**: EC2 Instance in **Public Subnet**.
    *   **Access**: Serves as the Bastion Host for SSH access to the private Data Plane.
*   **Data Plane (Worker Nodes)**:
    *   **Component**: `kubelet`, `kube-proxy`, Container Runtime (Docker/containerd).
    *   **Host**: EC2 Instances in **Private Subnets**.
    *   **Security**: No direct internet access; outbound traffic routed via NAT Gateway.
*   **Cloud Controller Manager**:
    *   Integrates the self-managed cluster with AWS APIs to provision Load Balancers and EBS Volumes.

### 1.2. Cluster Configuration Specifications
The following technical specifications define the self-managed cluster state as enforced by Ansible.

| Component | Specification | Details |
| :--- | :--- | :--- |
| **Orchestrator** | `kubeadm` | Bootstraps the Control Plane. |
| **CRI** | `cri-dockerd` | Docker Shim allowing Kubernetes to use Docker Engine as the runtime. |
| **CNI** | `Calico` (v3.28) | Provides Pod networking and Network Policy enforcement. |
| **Cloud Provider** | `external` | Kubelet configured with `--cloud-provider=external` to integrate with AWS CCM. |
| **Pod CIDR** | `192.168.0.0/16` | Defined during `kubeadm init` for Calico compatibility. |
| **Service CIDR** | Default | Standard Service IP range. |

### 1.3. Network Integration
*   **Ingress Controller**: NGINX Ingress Controller deployed as a DaemonSet/Deployment.
*   **Load Balancer**: AWS **Classic Load Balancer (CLB)** provisioned automatically by the Ingress Controller service to expose the cluster to the internet.

## 2. Helm Chart Reference (`amazona`)

The application lifecycle is managed via the `amazona` Helm chart.

### 2.1. Rationale for Using Helm
Helm is utilized as the Package Manager for Kubernetes to achieve the following architectural goals:

1.  **Templating & Reusability**:
    *   Enables dynamic injection of environment-specific values (e.g., `Values.backend.replicas`, `Values.ingress.app_host`) without hardcoding manifests.
    *   Allows the same chart to be deployed across multiple environments (Dev, Staging, Prod) by simply swapping the `values.yaml` file.
2.  **Atomic Deployments**:
    *   Helm treats the entire application stack (Frontend + Backend + DB + Monitoring) as a single "Release".
    *   If any part of the upgrade fails, Helm can automatically roll back the entire release to the previous stable state.
3.  **Dependency Management**:
    *   Manages complex dependencies (e.g., ensuring ConfigMaps are created before Pods) through a unified deployment command.

### 2.2. Directory Structure
```text
k8s-charts/
├── Chart.yaml                  # Chart metadata
├── values.yaml                 # Default configuration values
└── templates/                  # Kubernetes manifest templates
    ├── 00-cluster-issuer.yaml  # Cert-Manager Issuer
    ├── 00-rbac.yaml            # RBAC roles and bindings
    ├── 01-secrets.yaml         # Application secrets
    ├── 01-storage-class.yaml   # Storage Class definition
    ├── 02-configmaps.yaml      # Configuration maps
    ├── 03-*-service.yaml       # Services for Backend, Frontend, MongoDB
    ├── 04-*-deployment.yaml    # Deployments for Backend, Frontend, MongoDB
    ├── 05-*-ingress.yaml       # Ingress rules for App and Monitoring
    ├── 06-prometheus.yaml      # Prometheus stack
    ├── 06-grafana.yaml         # Grafana dashboard
    └── 07-seed-product.yaml    # Job to seed initial data
### 2.2. Manifest Reference

The following table details the purpose and configuration of each template file in the chart.

| File | Kind | Purpose & Key Configuration |
| :--- | :--- | :--- |
| `00-cluster-issuer.yaml` | `ClusterIssuer` | **TLS Management**: Configures Cert-Manager to use Let's Encrypt Production (`acme-v02`). Uses HTTP-01 challenge via NGINX. |
| `00-rbac.yaml` | `ClusterRole` | **Service Discovery**: Grants Prometheus read-only access to `pods`, `services`, and `nodes` to enable auto-discovery of scrape targets. |
| `01-secrets.yaml` | `Secret` | **Credentials**: Stores sensitive data (AWS Keys, DB Passwords, JWT Token) injected from `values.yaml`. Base64 encoded. |
| `01-storage-class.yaml` | `StorageClass` | **EBS Provisioning**: Defines the `ebs-sc` class using `ebs.csi.aws.com`. Configures **gp3** volumes with encryption enabled. Set as default. |
| `02-configmaps.yaml` | `ConfigMap` | **App Config**: Stores non-sensitive config like `aws-region`, `bucket-name`, and `react-app-api-url`. |
| `03-backend-service.yaml` | `Service` | **Internal Networking**: Exposes the Backend Pods on port `5000` (ClusterIP). |
| `03-frontend-service.yaml` | `Service` | **Internal Networking**: Exposes the Frontend Pods on port `80` (ClusterIP). |
| `03-mongodb-service.yaml` | `Service` | **Database Networking**: Exposes MongoDB on port `27017`. Headless service for StatefulSet discovery. |
| `04-backend-deployment.yaml` | `Deployment` | **API Workload**: Deploys the Node.js backend. Configured with Prometheus scrape annotations (`/metrics`). |
| `04-frontend-deployment.yaml` | `Deployment` | **UI Workload**: Deploys the React frontend. Injects API URL from ConfigMap. |
| `04-mongodb-deployment.yaml` | `StatefulSet` | **Database Workload**: Deploys MongoDB with a persistent volume claim template (`data`) using the `ebs-sc` storage class. |
| `05-app-ingress.yaml` | `Ingress` | **Public Routing**: Routes `amzona-depi...` to Frontend/Backend. Enforces HTTPS and rewrite rules. |
| `05-monitoring-ingress.yaml` | `Ingress` | **Admin Routing**: Routes `monitor-amzona...` to Grafana/Prometheus. Enforces **Basic Auth**. |
| `06-prometheus.yaml` | `Deployment` | **Metrics Engine**: Deploys Prometheus v2.40. Configured to scrape the cluster and itself. |
| `06-grafana.yaml` | `Deployment` | **Visualization**: Deploys Grafana v10. Auto-provisions Prometheus as a datasource. |
| `07-seed-product.yaml` | `Job` | **Data Initialization**: A **Helm Hook** (`post-install`) that runs `npm run seed` to populate the DB with initial products. Deletes itself on success. |

### 2.3. Configuration Values (`values.yaml`)

| Parameter               | Default                                  | Description                          |
| :---------------------- | :--------------------------------------- | :----------------------------------- |
| `backend.image`         | `depi-app-backend:latest`                | Docker image for the backend API.    |
| `backend.replicas`      | `2`                                      | Number of backend replicas.          |
| `backend.port`          | `5000`                                   | Internal port for the backend.       |
| `frontend.image`        | `depi-app-frontend:latest`               | Docker image for the frontend UI.    |
| `frontend.replicas`     | `2`                                      | Number of frontend replicas.         |
| `frontend.port`         | `80`                                     | Internal port for the frontend.      |
| `config.bucketName`     | `default-bucket`                         | S3 bucket name for product images.   |
| `config.region`         | `us-east-1`                              | AWS Region for S3 access.            |
| `ingress.app_host`      | `amzona-depi-devops.kozow.com`           | DNS hostname for the application.    |
| `ingress.app_monitor`   | `monitor-amzona-depi-devops.kozow.com` | DNS hostname for Grafana/Prometheus. |

### 2.3. Secrets Management
Sensitive data is injected via `values.yaml` (under `secrets`) or set during installation.
*   `AWS_ACCESS_KEY` / `AWS_SECRET_KEY`: For S3 access.
*   `JWT_TOKEN`: For user authentication.
*   `DB_USER` / `DB_PASS`: For MongoDB authentication.

## 3. Deep Dive: Resource Specifications

### 3.1. Ingress & Routing Strategy
The cluster utilizes a split-ingress strategy to enforce distinct security policies for application traffic versus administrative monitoring traffic. Both are served via the **Classic Load Balancer (CLB)**.

#### Application Ingress (`05-app-ingress.yaml`)
*   **Host**: `{{ .Values.ingress.app_host }}`
*   **TLS Termination**: Managed by Cert-Manager (`letsencrypt-prod` ClusterIssuer).
*   **Traffic Flow**:
    1.  **CLB** (Port 443) → **Ingress Controller**
    2.  **Ingress Controller** → **Service** (ClusterIP)
    3.  **Service** → **Pod**

| Path         | Service            | Port   | Rewrites |
| :----------- | :----------------- | :----- | :------- |
| `/?(api/.*)` | `backend-service`  | `5000` | `/$1`    |
| `/?(.*)`     | `frontend-service` | `80`   | None     |

#### Monitoring Ingress (`05-monitoring-ingress.yaml`)
*   **Host**: `{{ .Values.ingress.app_monitor }}`
*   **Access Control**: **Basic Authentication** enforced via NGINX annotations.
    *   `nginx.ingress.kubernetes.io/auth-type: "basic"`
    *   `nginx.ingress.kubernetes.io/auth-secret: "prometheus-basic-auth"`

| Path          | Service              | Port   |
| :------------ | :------------------- | :----- |
| `/prometheus` | `prometheus-service` | `9090` |
| `/`           | `grafana-service`    | `3000` |

### 3.2. Monitoring Stack Configuration
The monitoring stack is deployed as a self-contained unit within the `amazona` namespace.

#### Prometheus
*   **Service Discovery**: Configured via `kubernetes_sd_configs` to discover Pods in the `amazona` namespace.
*   **Scraping Logic**: Targets pods with the annotation `prometheus.io/scrape: "true"`.

#### Grafana
*   **Datasource Provisioning**: Automatically connects to the internal Prometheus service (`http://prometheus-service...:9090`).
*   **Authentication**: Admin credentials initialized via environment variables.

### 3.3. Workload Configuration

#### Backend API
*   **Observability**: Exposes metrics at `/metrics` on port `5000`.
*   **Environment**:
    *   `AWS_REGION`, `AWS_BUCKET_NAME`: ConfigMap.
    *   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`: Secrets.
    *   `MONGODB_URL`: Constructed dynamically.

#### MongoDB (StatefulSet)
*   **Architecture**: Deployed as a **StatefulSet** to ensure a stable network identity (`mongodb-0`) and persistent storage binding.
*   **Storage**: 1Gi Persistent Volume Claim (PVC) backed by **EBS GP2/GP3** (provisioned via AWS EBS CSI Driver).

## 4. Architectural Decisions

### 4.1. RBAC Configuration
A dedicated `ClusterRole` and `ServiceAccount` are defined for Prometheus.
*   **Objective**: Enable Service Discovery while adhering to Least Privilege.
*   **Permissions**: Read-only access (`get`, `list`, `watch`) to `nodes`, `services`, `endpoints`, `pods`, and `ingresses`.
*   **Restriction**: No write access is granted, mitigating the impact of potential compromise.

### 4.2. Ingress Segmentation
Ingress resources are separated by function.
*   **Public Ingress**: Serves customer traffic with no authentication requirements.
*   **Admin Ingress**: Serves monitoring tools with strict Basic Authentication.
*   **Benefit**: Decouples the security posture of the application from the operational tools.

## 5. Deployment Procedure (SOP)

### 5.1. Prerequisites
1.  **Kubernetes Cluster**: A functional self-managed cluster (Master + Workers).
2.  **Load Balancer**: AWS Classic Load Balancer (CLB) provisioned by the Ingress Controller.
3.  **Helm**: Installed on the Control Node.

### 5.2. Installation
Execute the Helm install command, injecting the required secrets.

```bash
helm install amazona ./k8s-charts \
  --set secrets.AWS_ACCESS_KEY="<YOUR_ACCESS_KEY>" \
  --set secrets.AWS_SECRET_KEY="<YOUR_SECRET_KEY>" \
  --set secrets.JWT_TOKEN="<YOUR_JWT_SECRET>" \
  --set secrets.DB_USER="admin" \
  --set secrets.DB_PASS="password"
```

### 5.3. Verification
1.  **Pod Status**: Ensure all pods are `Running`.
    ```bash
    kubectl get pods -n amazona
    ```
2.  **Ingress Status**: Verify the CLB hostname is assigned.
    ```bash
    kubectl get ingress -n amazona
    ```
3.  **Access**: Navigate to the configured DNS endpoints.

## 6. Troubleshooting

| Symptom                          | Root Cause                                | Resolution                                                    |
| :------------------------------- | :---------------------------------------- | :------------------------------------------------------------ |
| **Pods Pending**                 | PVC not bound or insufficient resources.  | Check StorageClass and EBS limits.                            |
| **Ingress 404/502**              | Backend service unreachable.              | Verify Service selectors and Pod health. Check NGINX logs.    |
| **DB Connection Failed**         | Invalid credentials or network issue.     | Verify Secret values and MongoDB StatefulSet status.          |
| **Load Balancer Not Created**    | Cloud Controller Manager failure.         | Check `kube-system` logs for `aws-cloud-controller-manager`.  |

