# Jenkins Pipeline Guide: Amazona Project

This guide explains how to operate the Amazona CI/CD pipeline. It breaks down **what** happens at each stage, **why** it is designed that way, and **how** you should interact with it.

---

## 1. Prerequisites (What You Need)

Before running the pipeline, ensure your environment is ready.

### ✅ Jenkins Configuration
You need these **Credentials** in Jenkins to access AWS and the Database:
*   `aws-access-key` / `aws-secret-key`: For AWS access (ECR, SSM).
*   `amazona-jwt-key`: For signing user tokens.
*   `mongo_db_creds`: For database root access.

### ✅ AWS Configuration (us-east-1)
We use **SSM Parameter Store** to manage config outside of code. Ensure these exist:
*   `/depi-project/amazona/frontend-ecr` (ECR URL)
*   `/depi-project/amazona/backend-ecr` (ECR URL)
*   `/depi-project/amazona/products-bucket` (S3 Bucket Name)

---

## 2. Pipeline Walkthrough (What & Why)

### Stage 1: Fetch Configuration
*   **What:** The pipeline asks AWS: "What is the current S3 bucket name? What is the ECR URL?"
*   **Why:** **Decoupling.** If we change the bucket name in AWS, we don't want to edit the source code and redeploy. We just update the parameter in AWS.
*   **How:** Uses `aws ssm get-parameter` to fetch values into environment variables.

### Stage 2: Intelligent Build Analysis
*   **What:** The pipeline checks `git diff` to see what changed since the last build.
*   **Why:** **Speed.** If you only changed the `README.md`, we shouldn't wait 10 minutes to rebuild the Docker images.
*   **How:**
    *   If `frontend/` changed → Build Frontend.
    *   If `backend/` changed → Build Backend.
    *   If `k8s-charts/` changed → Deploy Manifests.

### Stage 3: Build & Push Images
*   **What:** Compiles your code into Docker images and uploads them to ECR.
*   **Why:** **Efficiency.** We run Frontend and Backend builds **in parallel** (at the same time) to cut the wait time in half.
*   **How:**
    1.  Login to ECR.
    2.  `docker build` with a unique tag (e.g., `v1.0-55`).
    3.  `docker push` to the registry.

### Stage 4: Deployment (Helm)
*   **What:** Updates the Kubernetes cluster with the new images and configuration.
*   **Why:** **Reliability.** We use **Helm** instead of simple text replacement (`envsubst`) because Helm is atomic. If the database update fails, Helm cancels the *entire* deployment, preventing a broken state.
*   **How:**
    *   **Injects Secrets:** Passes Jenkins credentials securely to the cluster.
    *   **Updates Images:** Tells Kubernetes to pull the new tag (`v1.0-55`).
    *   **Waits:** Pauses until all Pods are `Ready`.

---

## 3. Operator Guide (How to Run)

### Standard Deployment
Use this for normal code updates (features, bug fixes).
1.  Go to the Jenkins Job.
2.  Click **Build with Parameters**.
3.  **Uncheck** `IsFirstRun`.
4.  Click **Build**.
    *   *Result:* It will only build what you changed.

### Full System Reset / First Run
Use this if you are setting up a new environment or things are out of sync.
1.  Go to the Jenkins Job.
2.  Click **Build with Parameters**.
3.  **Check** `IsFirstRun`.
4.  Click **Build**.
    *   *Result:* It forces a rebuild of EVERYTHING and reapplies all Kubernetes manifests.

---

## 4. Troubleshooting (What if it fails?)

| Error | Likely Cause | Solution |
| :--- | :--- | :--- |
| **Push Failed (Retrying...)** | Missing Permissions | Check IAM User policies. Needs `AmazonEC2ContainerRegistryPowerUser`. |
| **Helm Upgrade Failed** | Pod Crash | Run `kubectl get pods`. If a pod is `CrashLoopBackOff`, check its logs: `kubectl logs <pod-name>`. |
| **Database Connection Error** | Wrong Credentials | Check `mongo_db_creds` in Jenkins. Ensure they match what the app expects. |
