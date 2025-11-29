# Pipleline Documentation

## CI/CD Pipeline Documentation

This document describes the ened-toend CI/CD pipeline used to build,package, and deploy AMAZONA application. The pipeline is written in Jenkins Syntax.

## 1. Overview
This pipeline automates the full CI/CD workflow for the AmazonA application. It follows DevOps best practices with: \
 • Secure credential management \
 • Centralized config retrieval \
 • Selective builds to reduce pipeline time \
 • Parallelized Docker builds \
 • Dynamic image versioning \
 • Kubernetes deployments using Helm \
 • Automatic AWS ECR credential rotation \
 • Idempotent namespace creation

## 2. Global Environment Configuration
All secrets are accessed through Jenkins Credentials Binding, which prevents storing sensitive data in code.

Environment variables include: \
**AWS_ACCESS_KEY & AWS_SECRET_KEY:** Used to authenticate with AWS services. \
**JWT_TOKEN:** Passed to backend services for user authentication. \
**DB_CREDS:** MongoDB login credentials injected into kubernetes via helm.

## 3. Pipeline Parameter 
IsFirstRun false Forces rebuilding and redeploying all components

This is helpful when doing: \
 • Cluster reboots \
 • Dependency upgrades \
 • Full system refresh

## 4. Stage: Fetch Configuration
Non-sensitive configuration is fetched from AWS Systems Manager Parameter Store, including: \
 • Frontend ECR URL \
 • Backend ECR URL \
 • S3 bucket name

Command used :
```
aws ssm get-parameter \
  --name "/depi-project/amazona/frontend-ecr" \
  --query "Parameter.Value" \
  --output text

```
The following parameters are fetched: \
 • Frontend ECR Repository URL \
 • Backend ECR Repository URL \
 • Products S3 Bucket Name 

**Why SSM?** \
 • Allows configuration changes without editing code \
 • Secure \
 • Centralized \
 • Supports environment-specific overrides

## 5. Stage: Check Changes 
This stage determines what needs rebuilding by comparing the latest commit with the previous one.

Detecting File Changes:

```
git diff --name-only HEAD~1
```
Based on the changes: \
 • If anything inside frontend/ changed → rebuild frontend \
 • If anything inside backend/ changed → rebuild backend \
 • If k8s-chart/ changed → redeploy manifests \
 • If IsFirstRun=true → rebuild & redeploy everything 

This prevents unnecessary builds and significantly reduces pipeline duration.

## 6. Stage: Dynamic Image Tagging 

To ensure each image is unique and traceable, tags are generated using commit counts:
```
git rev-list --count HEAD frontend/
git rev-list --count HEAD backend/
```
**Benefits** \
 • Clear version progression \
 • Reproducible builds \
 • Easy rollback \
 • Maps running pods to specific commits

## 7. Stage : Build & Push Docker Images 
Frontend and backend builds run in parallel for speed.

**AWS ECR login**

AWS ECR requires a fresh login token for each build:

```
aws ecr get-login-password --region $AWS_REGION | \
docker login --username AWS --password-stdin <registry-url>
```
**Build Commands:**

```Frontend
docker build -t $FRONTEND_ECR_URL:$FRONTEND_IMAGE_TAG .
```
```backend
docker build -t $BACKEND_ECR_URL:$BACKEND_IMAGE_TAG .
```
**Push Commands:**
```
docker push $FRONTEND_ECR_URL:$FRONTEND_IMAGE_TAG
docker push $BACKEND_ECR_URL:$BACKEND_IMAGE_TAG
```
**Important Notes** \
 • Builds run on agents labeled k8s_worker \
 • Parallel execution reduces total build time by ~50% 

## 8. Deploy with Helm (CD)
This stage handles full deployment into Kubernetes using Helm:

## 8.1 Namespace Idempotency
Ensures the amazona namespace exists without errors, even if created before:

```
kubectl create namespace amazona --dry-run=client -o yaml | kubectl apply -f -
```
## 8.2 AWS ECR Credential Rotation
Since AWS ECR tokens expire every 12 hours, the pipeline regenerates the Kubernetes pull secret (regcred) every deployment:

```
kubectl create secret docker-registry regcred \
  --docker-server=<ecr-domain> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region $AWS_REGION) \
  --dry-run=client -o yaml | kubectl apply -n amazona -f -

```
This prevents pod image pull failures.

## 8.3 Helm Deployment (Atomic Update)
Helm is used because it: \
 • Deploys all Kubernetes resources atomically \
 • Injects secrets cleanly \
 • Supports post-install hooks \
 • Verifies pod readiness with --wait \
 • Version-controls all manifests

**Deployment Commands:**
```
helm upgrade --install amazona ./k8s-charts \
  --namespace amazona \
  --set frontend.image=$FRONTEND_ECR_URL:$FRONTEND_IMAGE_TAG \
  --set backend.image=$BACKEND_ECR_URL:$BACKEND_IMAGE_TAG \
  --set secrets.AWS_ACCESS_KEY=$AWS_ACCESS_KEY \
  --set secrets.AWS_SECRET_KEY=$AWS_SECRET_KEY \
  --set secrets.JWT_TOKEN=$JWT_TOKEN \
  --set secrets.DB_USER=$DB_USER \
  --set secrets.DB_PASS=$DB_PASS \
  --set config.bucketName=$BUCKET_NAME \
  --wait
```
This ensures: \
 • Both services update together \
 • Config/secrets synced with each deployment \
 • Only succeeds if pods reach Ready state \

