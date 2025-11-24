# í³˜ Amazona Cloud-Native Architecture & Team Guide

**Project:** Amazona E-Commerce Platform
**Infrastructure:** Self-Managed Kubernetes on AWS
**Networking Model:** Classic Load Balancer (L4) + Nginx Ingress (L7)
**Version:** 1.0.1

---

## 1. Master Connectivity Contract 

**CRITICAL:** All teams must strictly adhere to these naming conventions.
Environment Variables (in the app) are `UPPERCASE`.
Secret/ConfigMap Keys (in Kubernetes) are `lowercase-kebab-case`.
You must map them correctly in your Deployment YAMLs.

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

| App Env Variable (UPPERCASE) | Mapped From K8s Key (lowercase) | Source    | Value / Format                               |
| :--------------------------- | :------------------------------ | :-------- | :------------------------------------------- |
| `MONGODB_URL`                | N/A (Constructed)               | Dynamic   | `mongodb://<user>:<pass>@mongodb:27017/amazona?authSource=admin` |
| `MONGO_INITDB_ROOT_USERNAME` | `mongo-root-username`           | Secret    | Root Database Username                       |
| `MONGO_INITDB_ROOT_PASSWORD` | `mongo-root-password`           | Secret    | Root Database Password                       |
| `AWS_ACCESS_KEY_ID`          | `aws-access-key-id`             | Secret    | IAM User Access Key                          |
| `AWS_SECRET_ACCESS_KEY`      | `aws-secret-access-key`         | Secret    | IAM User Secret Key                          |
| `AWS_REGION`                 | `aws-region`                    | ConfigMap | `us-east-1`                                  |
| `AWS_BUCKET_NAME`            | `aws-bucket-name`               | ConfigMap | `amazona20`                                  |
| `JWT_SECRET`                 | `jwt-secret`                    | Secret    | Token Signing Key                            |
| `PAYPAL_CLIENT_ID`           | `paypal-client-id`              | ConfigMap | `sb`                                         |
| `REACT_APP_API_URL`          | `react-app-api-url`             | ConfigMap | `/api` (Routes via Ingress)                  |

---

## 2.  Networking (Traffic Control) (mohamed osama)

**Deliverables:** Ingress Controller & Service Definitions.

### 2.1 Service Definitions

**File:** `services.yaml`
Create standard ClusterIP services matching the Network Topology table.

### 2.2 Ingress Configuration

**File:** `ingress.yaml`
**Annotations:**
* `kubernetes.io/ingress.class: "nginx"`
* `nginx.ingress.kubernetes.io/rewrite-target: /$1`
**Routing:**
* `/api/?(.*)` $\rightarrow$ `backend-service:5000`
* `/?(.*)` $\rightarrow$ `frontend-service:80`

---

## 3. Application (Workloads) "shimaa"

**Deliverables:** Deployments for Database, Backend, and Frontend.

### 3.1 MongoDB Deployment

**File:** `02-mongodb-deployment.yaml`
**Image:** `mongo:6`
**Env Mapping:**
* `MONGO_INITDB_ROOT_USERNAME` $\leftarrow$ Secret Key: `mongo-root-username`
* `MONGO_INITDB_ROOT_PASSWORD` $\leftarrow$ Secret Key: `mongo-root-password`

### 3.2 Backend Deployment

**File:** `03-backend-deployment.yaml`
**Image:** `<ECR_REPO>/backend:latest`
**Env Mapping:**
* `AWS_ACCESS_KEY_ID` $\leftarrow$ Secret Key: `aws-access-key-id`
* `MONGODB_URL`: Construct this string using the secret values: `value: "mongodb://$(MONGO_USER):$(MONGO_PASS)@mongodb:27017/amazona?authSource=admin"`

### 3.3 Frontend Deployment

**File:** `04-frontend-deployment.yaml`
**Image:** `<ECR_REPO>/frontend:latest`
**Env Mapping:**
* `REACT_APP_API_URL` $\leftarrow$ ConfigMap Key: `react-app-api-url` (Value: `/api`)

---

## 4.  Configuration (Secrets & State) ahmed osama

**Deliverables:** The central configuration store.

### 4.1 Secrets (`amazona-secrets`)

**Keys (lowercase-kebab-case):**
* `aws-access-key-id`
* `aws-secret-access-key`
* `mongo-root-username`
* `mongo-root-password`
* `jwt-secret`

### 4.2 ConfigMap (`amazona-config`)

**Keys (lowercase-kebab-case):**
* `aws-region`: `"us-east-1"`
* `aws-bucket-name`: `"amazona20"`
* `paypal-client-id`: `"sb"`
* `react-app-api-url`: `"/api"`

---

## 5.  Operations (Storage & Observability) (arwa elsawy)

### 5.1 Storage

**StorageClass:** `ebs-sc` (`gp3`, encrypted)
**PVC:** `mongodb-pvc` (`2Gi`)

### 5.2 Data Seeding (`seed-job`)

**Command:** `["npm", "run", "seed-prod"]`
**Env:** Must have `MONGODB_URL` injected just like the Backend.

### 5.3 Observability

**Prometheus:** Port `9090`
**Grafana:** Port `3000`

---

## Deployment Sequence

1.  **Namespace & Storage:** `00-namespace.yaml`, `storage-class.yaml`
2.  **Config:** `configmaps.yaml`, `secrets.yaml`
3.  **DB Storage:** `mongodb-pvc.yaml`
4.  **DB App:** `mongodb-deployment.yaml`
5.  **Monitoring:** `monitoring/`
6.  **Seed:** `seed-job.yaml`
7.  **Apps:** `backend-deployment.yaml`, `frontend-deployment.yaml`
8.  **Network:** `services.yaml`, `ingress.yaml`
