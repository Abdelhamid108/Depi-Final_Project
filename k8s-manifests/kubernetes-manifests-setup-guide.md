# Amazona Cloud-Native Architecture & Implementation Guide

**Project:** Amazona E-Commerce Platform  
**Infrastructure:** Self-Managed Kubernetes on AWS  
**Architecture Pattern:** Microservices-style (Frontend, Backend, Database)  
**Ingress Model:** AWS Classic Load Balancer (L4) + Nginx Ingress Controller (L7)  
**Version:** 1.0.1  

---

## 1.  Master Connectivity Contract (The "Source of Truth")

**CRITICAL:** This section defines the immutable interface contracts between services. All teams must strictly adhere to these naming conventions, ports, and variable identifiers. **Do not change these values without cross-team approval.**

### 1.1 Network Topology & Service Discovery

Internal communication relies on Kubernetes DNS. Services must be named exactly as follows:

| Service Name             | Type      | Internal Port | Protocol | Used By                             |
| :----------------------- | :-------- | :------------ | :------- | :---------------------------------- |
| **`backend-service`**    | ClusterIP | `5000`        | TCP      | Ingress Controller, Frontend Pods   |
| **`frontend-service`**   | ClusterIP | `80`          | TCP      | Ingress Controller                  |
| **`mongodb`**            | ClusterIP | `27017`       | TCP      | Backend Pods                        |
| **`prometheus-service`** | ClusterIP | `9090`        | TCP      | Grafana                             |
| **`grafana-service`**    | ClusterIP | `3000`        | TCP      | Admin Users (via Port Forwarding or Ingress) |

### 1.2 Environment Variable Registry

Applications will fail to start if these variables are missing or misnamed in the Deployment manifests.

| App Env Variable (UPPERCASE)   | Mapped From K8s Key (lowercase) | Source      | Value / Format                                               |
| :----------------------------- | :------------------------------ | :---------- | :----------------------------------------------------------- |
| `MONGODB_URI`                  | N/A (Constructed)               | **Dynamic** | `mongodb://<user>:<pass>@mongodb:27017/amazona?authSource=admin` |
| `MONGO_INITDB_ROOT_USERNAME`   | `mongo-root-username`           | **Secret**  | Root Database Username                                       |
| `MONGO_INITDB_ROOT_PASSWORD`   | `mongo-root-password`           | **Secret**  | Root Database Password                                       |
| `AWS_ACCESS_KEY_ID`            | `aws-access-key-id`             | **Secret**  | IAM User Access Key (for S3 uploads)                         |
| `AWS_SECRET_ACCESS_KEY`        | `aws-secret-access-key`         | **Secret**  | IAM User Secret Key (for S3 uploads)                         |
| `AWS_REGION`                   | `aws-region`                    | **ConfigMap** | `us-east-1`                                                  |
| `AWS_BUCKET_NAME`              | `aws-bucket-name`               | **ConfigMap** | `amazona20`                                                  |
| `JWT_SECRET`                   | `jwt-secret`                    | **Secret**  | Token Signing Key                                            |
| `PAYPAL_CLIENT_ID`             | `paypal-client-id`              | **ConfigMap** | `sb`                                                         |
| `REACT_APP_API_URL`            | `react-app-api-url`             | **ConfigMap** | `/api` (Routes via Ingress)                                  |

---

## 2.  Team Networking (Mohamed Osama)

**Role:** Traffic Control & Routing  
**Deliverables:** Service Definitions & Ingress Configuration.

### 2.1 Service Definitions (`services.yaml`)

Create standard `ClusterIP` services. Ensure `selectors` match the labels defined by the Application team.

**Specification:**
*   **Backend:** Name `backend-service`, Port `5000`, Selector `app: backend`.
*   **Frontend:** Name `frontend-service`, Port `80`, Selector `app: frontend`.
*   **Database:** Name `mongodb`, Port `27017`, Selector `app: mongodb`.

### 2.2 Ingress Configuration (`ingress.yaml`)

Configure Nginx to handle path-based routing. This effectively splits traffic between the frontend and backend using a single Load Balancer.

**Critical Annotations:**
*   `kubernetes.io/ingress.class: "nginx"`
*   `nginx.ingress.kubernetes.io/rewrite-target: /$1` (This strips the `/api` prefix before sending the request to the backend).

**Routing Rules:**
1.  **Path:** `/api/?(.*)` $\rightarrow$ **Service:** `backend-service` **Port:** `5000`
2.  **Path:** `/?(.*)` $\rightarrow$ **Service:** `frontend-service` **Port:** `80`

---

## 3. Team Application (Shimaa)

**Role:** Workload Deployment  
**Deliverables:** Deployment Manifests for Database, Backend, and Frontend.

### 3.1 MongoDB Deployment (`02-mongodb-deployment.yaml`)

*   **Kind:** `Deployment`
*   **Replicas:** 1 (Stateful requirement)
*   **Image:** `mongo:6`
*   **Volume Mounts:**
    *   Mount volume named `data` to path `/data/db`.
    *   **Important:** The volume must reference the PVC `mongodb-pvc` created by Team Operations.
*   **Environment:**
    *   Inject `MONGO_INITDB_ROOT_USERNAME` from Secret `amazona-secrets`.
    *   Inject `MONGO_INITDB_ROOT_PASSWORD` from Secret `amazona-secrets`.

### 3.2 Backend Deployment (`03-backend-deployment.yaml`)

*   **Kind:** `Deployment`
*   **Replicas:** 2
*   **Image:** `<YOUR_ECR_REPO_URL>/backend:latest`
*   **Environment Configuration:**
    *   **AWS Credentials:** Inject `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY` from Secret `amazona-secrets`.
    *   **App Config:** Inject `AWS_REGION`, `AWS_BUCKET_NAME`, `PAYPAL_CLIENT_ID` from ConfigMap `amazona-config`.
    *   **Secrets:** Inject `JWT_SECRET` from Secret `amazona-secrets`.
    *   **Database Connection (`MONGODB_URI`):**
        *   You must construct this string dynamically in the YAML using the secret values.
        *   **Value:** `"mongodb://$(MONGO_USER):$(MONGO_PASS)@mongodb:27017/amazona?authSource=admin"`
        *   *(Ensure you define variables `MONGO_USER` and `MONGO_PASS` from the secret first within the `env` block)*.

### 3.3 Frontend Deployment (`04-frontend-deployment.yaml`)

*   **Kind:** `Deployment`
*   **Replicas:** 2
*   **Image:** `<YOUR_ECR_REPO_URL>/frontend:latest`
*   **Environment Configuration:**
    *   **API URL:** Inject `REACT_APP_API_URL` from ConfigMap `amazona-config`.
    *   **Value:** The value must be `/api`. This ensures the React app (running in the browser) sends requests to the Ingress Controller, which then routes them to the backend.

---

## 4. Team Configuration (Ahmed Osama)

**Role:** Secrets Management & Configuration  
**Deliverables:** Namespace, Secrets, and ConfigMaps.

### 4.1 Namespace (`00-namespace.yaml`)

*   **Resource:** `Namespace`
*   **Name:** `amazona`
*   **Purpose:** All project resources must be deployed into this namespace to ensure isolation.

### 4.2 Secrets (`01-secrets.yaml`)

*   **Name:** `amazona-secrets`
*   **Type:** `Opaque`
*   **Data Keys (Must be Base64 Encoded):**
    *   `aws-access-key-id`
    *   `aws-secret-access-key`
    *   `mongo-root-username` (Default: `admin`)
    *   `mongo-root-password` (Default: `password`)
    *   `jwt-secret` (Default: `somethingsecret`)

### 4.3 ConfigMap (`01-configmaps.yaml`)

*   **Name:** `amazona-config`
*   **Data Keys (Plain Text):**
    *   `aws-region`: `"us-east-1"`
    *   `aws-bucket-name`: `"amazona20"` (Or your unique bucket name)
    *   `paypal-client-id`: `"sb"`
    *   `react-app-api-url`: `"/api"`

---

## 5. Operations (Arwa Elsawy)

**Role:** Persistence, Seeding & Observability  
**Deliverables:** StorageClass, PVC, Seed Job, Monitoring Stack.

### 5.1 Storage Infrastructure

*   **StorageClass (`ebs-storage-class.yaml`):**
    *   **Name:** `ebs-sc`
    *   **Provisioner:** `ebs.csi.aws.com`
    *   **Parameters:** `type: gp3`, `encrypted: "true"`
*   **Persistent Volume Claim (`mongodb-pvc.yaml`):**
    *   **Name:** `mongodb-pvc` (This name is referenced by the DB Deployment).
    *   **StorageClass:** `ebs-sc`
    *   **Size:** `2Gi` (or `4Gi` based on need)
    *   **AccessMode:** `ReadWriteOnce`

### 5.2 Database Seeding (`seed-job.yaml`)

*   **Kind:** `Job`
*   **Purpose:** Populates the database with initial products and users so the app isn't empty.
*   **Image:** Use the **Backend Image**.
*   **Command:** `["npm", "run", "seed-prod"]`
*   **Environment:** Requires the exact same `MONGODB_URI` configuration as the Backend Deployment.

### 5.3 Observability Stack (`monitoring/`)

Create a dedicated folder `monitoring` for these manifests.

**A. Prometheus (`prometheus.yaml`)**
*   **Workload:** Deployment (1 replica).
*   **Config:** Mount a `ConfigMap` containing `prometheus.yml` to `/etc/prometheus/`.
*   **Service:** ClusterIP exposing port `9090`.

**B. Grafana (`grafana.yaml`)**
*   **Workload:** Deployment (1 replica).
*   **Image:** `grafana/grafana:latest`.
*   **Service:** ClusterIP exposing port `3000`.
*   **Configuration:** Add `prometheus-service:9090` as a Data Source.

---

## Deployment Execution Plan

To avoid dependency errors (e.g., Pods failing because Secrets don't exist), deploy in this **strict order**:

1.  **[Ops]** Apply Namespace & Storage Class:
    `kubectl apply -f 00-namespace.yaml -f ebs-storage-class.yaml`
2.  **[Config]** Apply Secrets & ConfigMaps:
    `kubectl apply -f 01-secrets.yaml -f 01-configmaps.yaml`
3.  **[Ops]** Apply PVC:
    `kubectl apply -f mongodb-pvc.yaml` (Wait for status: `Bound`)
4.  **[App]** Deploy MongoDB:
    `kubectl apply -f 02-mongodb-deployment.yaml` (Wait for status: `Running`)
5.  **[Ops]** Run Seed Job:
    `kubectl apply -f seed-job.yaml` (Wait for status: `Completed`)
6.  **[Ops]** Deploy Monitoring Stack:
    `kubectl apply -f monitoring/`
7.  **[App]** Deploy Backend & Frontend:
    `kubectl apply -f 03-backend-deployment.yaml -f 04-frontend-deployment.yaml`
8.  **[Network]** Apply Services & Ingress:
    `kubectl apply -f services.yaml -f ingress.yaml`

**Final Verification:**
Retrieve the Load Balancer DNS and access the application:
```bash
kubectl get svc -n ingress-nginx
