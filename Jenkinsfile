pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'

        // AWS Credentials for ECR and S3 access
        AWS_ACCESS_KEY = credentials('aws-access-key')
        AWS_SECRET_KEY = credentials('aws-secret-key')
        
        // JWT Secret for application token signing
        JWT_TOKEN = credentials('amazona-jwt-key')

        // MongoDB Credentials for database authentication
        DB_CREDS = credentials('mongo_db_creds')

        DB_USER = "${DB_CREDS_USR}"
        DB_PASS = "${DB_CREDS_PSW}"
    }
    
    parameters {
        booleanParam(name: 'IsFirstRun', defaultValue: false, description: 'Check for first run to deploy everything')
    }

    stages {
        stage('Fetch Configuration') {
            steps {
                script {
                    env.FRONTEND_ECR_URL = sh(script: 'aws ssm get-parameter --name "/depi-project/amazona/frontend-ecr" --query "Parameter.Value" --output text', returnStdout: true).trim()
                    env.BACKEND_ECR_URL = sh(script: 'aws ssm get-parameter --name "/depi-project/amazona/backend-ecr" --query "Parameter.Value" --output text', returnStdout: true).trim()
                    env.BUCKET_NAME = sh(script: 'aws ssm get-parameter --name "/depi-project/amazona/products-bucket" --query "Parameter.Value" --output text', returnStdout: true).trim()
                    echo "Frontend Repo URL :${env.FRONTEND_ECR_URL}"
                }
            }
        }

        stage('Check Changes') {
            steps {
                script {
                        // Smart Deployment Logic:
                        // If 'IsFirstRun' is true, we force a full build and deploy of all components.
                        // Otherwise, we use 'git diff' to identify which directories have changed.
                        // This optimizes the pipeline by only building/deploying what is necessary.
                        if (params.IsFirstRun) {
                            env.BUILD_FRONTEND = 'true'
                            env.BUILD_BACKEND  = 'true'
                            env.APPLY_MANIFESTS = 'true'
                        } else {
                            def changes = sh(script: 'git diff --name-only HEAD~1 || true', returnStdout: true).trim()
                            env.BUILD_FRONTEND = changes.contains('frontend/') ? 'true' : 'false'
                            env.BUILD_BACKEND  = changes.contains('backend/') ? 'true' : 'false'
                            
                            // Manifests are applied if:
                            // 1. The 'k8s-manifests' folder itself has changed.
                            // 2. The Frontend or Backend images were rebuilt (requiring a deployment update).
                            if (changes.contains('k8s-manifests/') || env.BUILD_FRONTEND == 'true' || env.BUILD_BACKEND == 'true') {
                                env.APPLY_MANIFESTS = 'true'
                            } else {
                                env.APPLY_MANIFESTS = 'false'
                            }
                            echo "Changed files:\n${changes}"
                        }
                    echo "BUILD_FRONTEND=${env.BUILD_FRONTEND}, BUILD_BACKEND=${env.BUILD_BACKEND}, APPLY_MANIFESTS=${env.APPLY_MANIFESTS}"

                    // Dynamic Versioning Strategy:
                    // We use the Git Commit Count for each service folder to generate a unique, sequential version tag (e.g., v1.0-42).
                    // This ensures that:
                    // 1. Tags are human-readable and sequential.
                    // 2. Tags only increment when code in the specific service folder changes.
                    // 3. We achieve idempotency: re-running the pipeline without code changes produces the same tag.
                    def backend_count  = sh(script: 'git rev-list --count HEAD backend/ || echo 0', returnStdout: true).trim()
                    def frontend_count = sh(script: 'git rev-list --count HEAD frontend/ || echo 0', returnStdout: true).trim()

                    env.BACKEND_IMAGE_TAG = "v1.0-${backend_count}"
                    env.FRONTEND_IMAGE_TAG = "v1.0-${frontend_count}"
                    
                    echo "Tags: Backend=${env.BACKEND_IMAGE_TAG}, Frontend=${env.FRONTEND_IMAGE_TAG}"
                }
            }
        }

        stage('Build Frontend') {
            agent { label 'k8s_worker' }
            when { environment name: 'BUILD_FRONTEND', value: 'true' }
            steps {
                script {
                    def registryUrl = env.FRONTEND_ECR_URL.split('/')[0]
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${registryUrl}"

                    dir('frontend') {
                        sh "docker build -t ${env.FRONTEND_ECR_URL}:${FRONTEND_IMAGE_TAG} ."
                        sh "docker push ${env.FRONTEND_ECR_URL}:${FRONTEND_IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Build Backend') {
            agent { label 'k8s_worker' }
            when { environment name: 'BUILD_BACKEND', value: 'true' }
            steps {
                script {
                    def registryUrl = env.BACKEND_ECR_URL.split('/')[0]
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${registryUrl}"

                    dir('backend') {
                        sh "docker build -t ${env.BACKEND_ECR_URL}:${BACKEND_IMAGE_TAG} ."
                        sh "docker push ${env.BACKEND_ECR_URL}:${BACKEND_IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Deploy Manifests') {
            agent { label 'k8s_master' }
            when { environment name: 'APPLY_MANIFESTS', value: 'true' }
            steps {
                script {
                    dir('k8s-manifests') {
                        // Secret Injection:
                        // Inject sensitive environment variables (DB creds, JWT token) into manifests at runtime.
                        // We use a temporary file pattern (*-injected.yaml) to avoid file truncation issues 
                        // that occur when redirecting output to the same file being read.
                        sh "envsubst < 02-configmaps.yaml > 02-configmaps-injected.yaml && mv 02-configmaps-injected.yaml 02-configmaps.yaml"
                        sh "envsubst < 01-secrets.yaml > 01-secrets-injected.yaml && mv 01-secrets-injected.yaml 01-secrets.yaml"

                        // Dynamic Image Tag Injection:
                        // Inject the dynamically generated image tags (e.g., v1.0-42) into deployment manifests
                        // to ensure the exact built version is deployed.
                        if (env.BUILD_BACKEND == 'true') {
                            env.BACKEND_IMAGE = "${env.BACKEND_ECR_URL}:${BACKEND_IMAGE_TAG}"
                            sh "envsubst < backend/04-backend-deployment.yaml > backend/04-backend-deployment-injected.yaml && mv backend/04-backend-deployment-injected.yaml backend/04-backend-deployment.yaml"
                        }
                        if (env.BUILD_FRONTEND == 'true') {
                            env.FRONTEND_IMAGE = "${env.FRONTEND_ECR_URL}:${FRONTEND_IMAGE_TAG}"
                            sh "envsubst < frontend/04-frontend-deployment.yaml > frontend/04-frontend-deployment-injected.yaml && mv frontend/04-frontend-deployment-injected.yaml frontend/04-frontend-deployment.yaml"
                        }
                       
                        // install nginx controller 
                        sh "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml"
                       
                        // Patch: Remove the "nlb" annotation to force Classic Load Balancer
                        sh "kubectl annotate service ingress-nginx-controller -n ingress-nginx service.beta.kubernetes.io/aws-load-balancer-type-"
                        
                        // Recursive Application:
                        // Apply all manifests recursively. Kubernetes handles dependency ordering and performs
                        // rolling updates if image tags or configurations have changed.
                        // applying with option excluding the seed job that has label skip apply
                        sh "kubectl apply -f . --recursive -l 'skip-apply!=true'" 
                       
                        if (parms.IsFirstRun == 'true') {
                           echo "Applying seed job "
                           """
                           envsubst < 07-seed-product.yaml > 07-seed-product-injected.yaml
                           kubectl apply -f 07-seed-product-injected.yaml
                           """
                        } else {
                           echo "job already exist"
                        }
                    }
                }
            }
        }
    }
}

