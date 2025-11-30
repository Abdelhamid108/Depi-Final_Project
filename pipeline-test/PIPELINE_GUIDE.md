# CI/CD Pipeline Documentation: Amazona Project

## 1. Architecture Overview

The Amazona CI/CD pipeline implements a GitOps-driven workflow for building, testing, and deploying the Amazona microservices architecture to Kubernetes. It utilizes Jenkins for orchestration, AWS ECR for artifact storage, and Helm for release management.

### Pipeline Stages
1.  **Configuration Retrieval:** Dynamic injection of infrastructure parameters from AWS SSM.
2.  **Change Detection:** Conditional logic to determine build scope based on git diffs.
3.  **Artifact Construction:** Parallelized Docker builds for Frontend and Backend services.
4.  **Deployment:** Atomic Helm upgrades to the target Kubernetes cluster.

---

## 2. Configuration Specifications

### 2.1 Environment Variables & Secrets
The following credentials must be configured in the Jenkins Credentials Store.

| Credential ID | Type | Usage |
| :--- | :--- | :--- |
| `aws-access-key` | Secret Text | AWS IAM Access Key for ECR/SSM access. |
| `aws-secret-key` | Secret Text | AWS IAM Secret Key. |
| `amazona-jwt-key` | Secret Text | JWT signing key injected into Backend pods. |
| `mongo_db_creds` | Username/Password | Root authentication for MongoDB StatefulSet. |

### 2.2 Infrastructure Parameters (AWS SSM)
Configuration is decoupled from the pipeline code via AWS Systems Manager Parameter Store (`us-east-1`).

| Parameter Path | Description |
| :--- | :--- |
| `/depi-project/amazona/frontend-ecr` | ECR Repository URI for Frontend. |
| `/depi-project/amazona/backend-ecr` | ECR Repository URI for Backend. |
| `/depi-project/amazona/products-bucket` | S3 Bucket name for product assets. |

---

## 3. Build Logic & Versioning

### 3.1 Conditional Execution
To optimize resource utilization, the pipeline employs a differential build strategy:
*   **Full Rebuild:** Triggered if `IsFirstRun` parameter is `true`.
*   **Incremental Build:** Triggered if changes are detected in `frontend/` or `backend/` directories relative to `HEAD~1`.
*   **Manifest Update:** Triggered if `k8s-charts/` is modified or if any image is rebuilt.

### 3.2 Artifact Versioning
Docker images are tagged using an immutable, sequential versioning scheme based on git commit depth:
*   Format: `v1.0-<COMMIT_COUNT>`
*   Example: `v1.0-55`
This ensures strict traceability between the running artifact and the source code state.

---

## 4. Deployment Strategy

Deployment is managed via **Helm** to ensure atomicity and idempotency.

### 4.1 Release Management
*   **Release Name:** `amazona`
*   **Namespace:** `amazona`
*   **Chart Path:** `./k8s-charts`

### 4.2 Dynamic Value Injection
The pipeline overrides default chart values at runtime using the `--set` flag:
*   `frontend.image`: Injected with the newly built ECR tag.
*   `backend.image`: Injected with the newly built ECR tag.
*   `secrets.*`: Injected from Jenkins Credentials.

### 4.3 Pre-Deployment Operations
1.  **Namespace Provisioning:** Idempotent creation of the `amazona` namespace.
2.  **Secret Rotation:** Regeneration of the `regcred` Kubernetes Secret to handle AWS ECR token expiration (12-hour TTL).

---

## 5. Operational Procedures

### 5.1 Triggering a Deployment
1.  Navigate to the Jenkins Job.
2.  Select **Build with Parameters**.
3.  Set `IsFirstRun` to `true` only for initial provisioning or disaster recovery.
4.  Execute Build.

### 5.2 Rollback Procedure
In the event of a deployment failure, Helm allows for immediate rollback to the previous stable revision.
Execute the following command on the control plane:
```bash
helm rollback amazona 0 -n amazona
```

### 5.3 Troubleshooting
*   **ECR Authentication Failure:** Verify the IAM User associated with the Jenkins credentials has `AmazonEC2ContainerRegistryPowerUser` policy attached.
*   **Pod Startup Timeout:** The pipeline utilizes `--wait`. If the build times out, inspect pod logs (`kubectl logs -l app=backend -n amazona`) for application-level errors.
