# Ì≥ò Amazona Cloud-Native Architecture & Team Guide

**Project:** Amazona E-Commerce Platform
**Infrastructure:** Self-Managed Kubernetes on AWS
**Networking Model:** Classic Load Balancer (L4) + Nginx Ingress (L7)
**Version:** 1.0.0

---

## 1. ÌøõÔ∏è Master Connectivity Contract (The "Source of Truth")

**CRITICAL:** All teams must strictly adhere to these naming conventions, ports, and variable identifiers. Do not change these values without cross-team approval.

### 1.1 Network Topology & Service Discovery

| Service Name        | Type       | Internal Port | Protocol | Used By             |
| :------------------ | :--------- | :------------ | :------- | :------------------ |
| `backend-service`   | ClusterIP  | `5000`        | `TCP`    | Ingress, Frontend   |
| `frontend-service`  | ClusterIP  | `80`          | `TCP`    | Ingress             |
| `mongodb`           | ClusterIP  | `27017`       | `TCP`    | Backend             |
| `prometheus-service`| ClusterIP  | `9090`        | `TCP`    | Grafana             |
| `grafana-service`   | ClusterIP  | `3000`        | `TCP`    | Admins (via Forwarding) |

### 1.2 Environment Variable Registry

Applications will fail to start if these variables are missing or misnamed.

| Variable Key                | Required By | Source      | Value / Format                               |
| :-------------------------- | :---------- | :---------- | :------------------------------------------- |
| `MONGODB_URI`               | Backend     | Dynamic     | `mongodb://<user>:<pass>@mongodb:27017/amazona?authSource=admin` |
| `MONGO_INITDB_ROOT_USERNAME`| MongoDB     | Secret      | Root Database Username                       |
| `MONGO_INITDB_ROOT_PASSWORD`| MongoDB     | Secret      | Root Database Password                       |
| `AWS_ACCESS_KEY_ID`         | Backend     | Secret      | IAM User Access Key (for S3)                 |
| `AWS_SECRET_ACCESS_KEY`     | Backend     | Secret      | IAM User Secret Key (for S3)                 |
| `AWS_REGION`                | Backend     | ConfigMap   | `us-east-1`                                  |
| `AWS_BUCKET_NAME`           | Backend     | ConfigMap   | `amazona20`                                  |
| `JWT_SECRET`                | Backend     | Secret      | Token Signing Key                            |
| `PAYPAL_CLIENT_ID`          | Backend     | ConfigMap   | `sb`                                         |
| `REACT_APP_API_URL`         | Frontend    | ConfigMap   | `/api` (Routes via Ingress)                  |

---

## 2. Networking (Traffic Control) (mohamed osama)

**Deliverables:** Ingress Controller & Service Definitions.

### 2.1 Service Definitions

Create standard ClusterIP services matching the Network Topology table above.
**Selectors:** Must match the labels defined by Team Application (e.g., `app: backend`).
**File:** `services.yaml`

### 2.2 Ingress Configuration

**File:** `ingress.yaml`
**Controller:** Nginx (configured for AWS Classic Load Balancer).
**Resource Name:** `amazona-ingress`
**Namespace:** `amazona`
**Required Annotations:**
* `kubernetes.io/ingress.class: "nginx"`
* `nginx.ingress.kubernetes.io/rewrite-target: /$1`  # Critical for path stripping

**Routing Rules:**
* Path `/api/?(.*)` -> Service: `backend-service` (Port `5000`)
* Path `/?(.*)` -> Service: `frontend-service` (Port `80`)

---

## 3.  Application (Workloads) (shimaa)

**Deliverables:** Deployments for Database, Backend, and Frontend.

### 3.1 MongoDB Deployment

**File:** `02-mongodb-deployment.yaml`
**Kind:** Deployment (Single Replica)
**Image:** `mongo:6`
**Volume Configuration (Mandatory):**
* Volume Name: `data`
* PersistentVolumeClaim: `mongodb-pvc` (Created by Team Ops)
* Mount Path: `/data/db`
**Credentials:** Inject `MONGO_INITDB_ROOT_USERNAME` and `MONGO_INITDB_ROOT_PASSWORD` from secrets.

### 3.2 Backend Deployment

**File:** `03-backend-deployment.yaml`
**Kind:** Deployment (Replicas: 2)
**Image:** `<ECR_REPO>/backend:latest`
**Configuration:**
* Inject all AWS variables (`AWS_REGION`, `AWS_BUCKET_NAME`, etc.) from ConfigMaps/Secrets.
* DB Connection: Ensure `MONGODB_URI` points to the `mongodb` service on port `27017`.

### 3.3 Frontend Deployment

**File:** `04-frontend-deployment.yaml`
**Kind:** Deployment (Replicas: 2)
**Image:** `<ECR_REPO>/frontend:latest`
**Configuration:**
* `REACT_APP_API_URL`: Set this to `/api`. This ensures requests go to the Ingress Load Balancer, which then routes them to the backend.

---

## 4. Configuration (Secrets & State) (ahmed osama)

**Deliverables:** The central configuration store.

### 4.1 Namespace

**Resource:** Namespace named `amazona`.

### 4.2 Secrets (`amazona-secrets`)

**Type:** `Opaque`
**Keys (Base64 Encoded):**
* `aws-access-key-id`
* `aws-secret-access-key`
* `mongo-root-username`
* `mongo-root-password`
* `jwt-secret`

### 4.3 ConfigMap (`amazona-config`)

**Keys:**
* `AWS_REGION`: `"us-east-1"`
* `AWS_BUCKET_NAME`: `"amazona20"`
* `PAYPAL_CLIENT_ID`: `"sb"`

---

## 5.  Operations (Storage & Observability) (arwa elsawy)

**Deliverables:** Persistence layer, Data Seeding, and Monitoring Stack.

### 5.1 Storage Infrastructure

**StorageClass (`ebs-sc`):**
* Provisioner: `ebs.csi.aws.com`
* Parameters: `type: gp3`, `encrypted: "true"`

**Persistent Volume Claim (`mongodb-pvc`):**
* StorageClass: `ebs-sc`
* Size: `2Gi` (or larger as needed)
* AccessMode: `ReadWriteOnce`

### 5.2 Data Seeding (`seed-job`)

**Type:** Job
**Image:** Backend Image
**Command:** `["npm", "run", "seed-prod"]`
**Env:** Requires `MONGODB_URI` (same as Backend).
**Purpose:** Populates the database with initial products/users.

### 5.3 Observability Stack (Namespace: `monitoring`)

**A. Prometheus Deployment**
* **File:** `monitoring/prometheus.yaml`
* **Config:** Mount `prometheus.yml` ConfigMap to `/etc/prometheus/`.
* **Service:** Expose on port `9090`.

**B. Grafana Deployment**
* **File:** `monitoring/grafana.yaml`
* **Image:** `grafana/grafana:latest`
* **Service:** Expose on port `3000`.
* **Data Source:** Configure to point to `http://prometheus-service:9090`.

---

## Ì∫Ä Deployment Sequence (Strict Order)

1.  **Ops:** Apply `00-namespace.yaml` & `storage-class.yaml`.
2.  **Config:** Apply `configmaps.yaml` & `secrets.yaml`.
3.  **Ops:** Apply `mongodb-pvc.yaml` (Wait for Bound status).
4.  **App:** Apply `mongodb-deployment.yaml` (Wait for Running status).
    * **Check:** Ensure volume is successfully mounted via EBS Driver.
5.  **Ops:** Apply `monitoring/` stack (Prometheus & Grafana).
6.  **Ops:** Run `seed-job.yaml` (Wait for Completed status).
7.  **App:** Apply `backend-deployment.yaml` & `frontend-deployment.yaml`.
8.  **Networking:** Apply `services.yaml` & `ingress.yaml`.

---

**Verification:**
Access the application via the Load Balancer DNS provided by the Ingress Controller:
`http://<AWS_CLB_DNS_NAME>/`
