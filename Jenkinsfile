pipeline {
    agent any

    environment {
        // Global Configuration
        AWS_REGION = 'us-east-1'

        // --------------------------------------------------------
        // SECURITY & CREDENTIALS MANAGEMENT
        // --------------------------------------------------------
        // We bind credentials to environment variables to avoid hardcoding secrets.
        // These are managed via the Jenkins Credentials Plugin.
        
        // Infrastructure Credentials (AWS ECR & S3)
        AWS_ACCESS_KEY = credentials('aws-access-key')
        AWS_SECRET_KEY = credentials('aws-secret-key')

        // Application Secrets
        JWT_TOKEN = credentials('amazona-jwt-key')

        // Database Authentication (MongoDB)
        DB_CREDS = credentials('mongo_db_creds')
        DB_USER = "${DB_CREDS_USR}"
        DB_PASS = "${DB_CREDS_PSW}"
    }

    parameters {
        // Operational Flag: Allows manual override to force a full redeployment
        // Useful for disaster recovery or fresh environment setup.
        booleanParam(name: 'IsFirstRun', defaultValue: false, description: 'Force rebuild and redeploy of all components')
    }

    stages {
        // --------------------------------------------------------
        // STAGE 1: CONFIGURATION MANAGEMENT
        // --------------------------------------------------------
        stage('Fetch Configuration') {
            steps {
                script {
                    // Pattern: Centralized Configuration
                    // We fetch non-sensitive configuration parameters from AWS Systems Manager (SSM) Parameter Store.
                    // This decouples configuration from the pipeline code, allowing config updates without code changes.
                    env.FRONTEND_ECR_URL = sh(script: 'aws ssm get-parameter --name "/depi-project/amazona/frontend-ecr" --query "Parameter.Value" --output text', returnStdout: true).trim()
                    env.BACKEND_ECR_URL = sh(script: 'aws ssm get-parameter --name "/depi-project/amazona/backend-ecr" --query "Parameter.Value" --output text', returnStdout: true).trim()
                    env.BUCKET_NAME = sh(script: 'aws ssm get-parameter --name "/depi-project/amazona/products-bucket" --query "Parameter.Value" --output text', returnStdout: true).trim()
                    
                    echo "Configuration loaded successfully. Registry: ${env.FRONTEND_ECR_URL.split('/')[0]}"
                }
            }
        }

        // --------------------------------------------------------
        // STAGE 2: INTELLIGENT BUILD ANALYSIS
        // --------------------------------------------------------
        stage('Check Changes') {
            steps {
                script {
                    // Pattern: Selective Building (Optimization)
                    // Instead of rebuilding everything on every commit, we analyze the git diff.
                    // This reduces pipeline latency and resource consumption.
                    if (params.IsFirstRun) {
                        env.BUILD_FRONTEND = 'true'
                        env.BUILD_BACKEND  = 'true'
                        env.APPLY_MANIFESTS = 'true'
                        echo "Execution Mode: Full Rebuild (Forced by User)"
                    } else {
                        // Check for changes in the specific service directories relative to the previous commit
                        def changes = sh(script: 'git diff --name-only HEAD~1 || true', returnStdout: true).trim()
                        
                        env.BUILD_FRONTEND = changes.contains('frontend/') ? 'true' : 'false'
                        env.BUILD_BACKEND  = changes.contains('backend/') ? 'true' : 'false'

                        // Manifests are applied if the chart changed OR if images were rebuilt
                        if (changes.contains('k8s-chart/') || env.BUILD_FRONTEND == 'true' || env.BUILD_BACKEND == 'true') {
                            env.APPLY_MANIFESTS = 'true'
                        } else {
                            env.APPLY_MANIFESTS = 'false'
                        }
                    }
                    
                    // Pattern: Dynamic & Immutable Tagging
                    // We use the git commit count to generate human-readable, sequential tags (e.g., v1.0-55).
                    // This ensures traceability: we can link every running container back to a specific state of the code.
                    def backend_count  = sh(script: 'git rev-list --count HEAD backend/ || echo 0', returnStdout: true).trim()
                    def frontend_count = sh(script: 'git rev-list --count HEAD frontend/ || echo 0', returnStdout: true).trim()

                    env.BACKEND_IMAGE_TAG = "v1.0-${backend_count}"
                    env.FRONTEND_IMAGE_TAG = "v1.0-${frontend_count}"

                    echo "Build Plan: Frontend=${env.BUILD_FRONTEND}, Backend=${env.BUILD_BACKEND}, Deploy=${env.APPLY_MANIFESTS}"
                }
            }
        }

        // --------------------------------------------------------
        // STAGE 3: ARTIFACT GENERATION (CI)
        // --------------------------------------------------------
        stage('Build & Push Images') {
            // Optimization: Parallel Execution
            // Frontend and Backend builds are independent, so we run them simultaneously to cut wait time by ~50%.
            parallel {
                stage('Build Frontend') {
                    agent { label 'k8s_worker' } // Offload heavy build tasks to worker nodes
                    when { environment name: 'BUILD_FRONTEND', value: 'true' }
                    steps {
                        script {
                            // Logic: Dynamic Registry Authentication
                            def registryUrl = "https://" + env.FRONTEND_ECR_URL.split('/')[0]
                            // We use password-stdin for secure, non-interactive login
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
                            def registryUrl = "https://" + env.BACKEND_ECR_URL.split('/')[0]
                            sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${registryUrl}"

                            dir('backend') {
                                sh "docker build -t ${env.BACKEND_ECR_URL}:${BACKEND_IMAGE_TAG} ."
                                sh "docker push ${env.BACKEND_ECR_URL}:${BACKEND_IMAGE_TAG}"
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------
        // STAGE 4: DEPLOYMENT (CD)
        // --------------------------------------------------------
        stage('Deploy with Helm') {
            agent { label 'k8s_master' } // Deployment operations must run on the Control Plane (or a node with kubectl access)
            when { environment name: 'APPLY_MANIFESTS', value: 'true' }
            steps {
                script {
                    // Task 1: Namespace Idempotency
                    // Problem: 'kubectl create namespace' fails if the namespace exists.
                    // Solution: Use '--dry-run=client -o yaml | kubectl apply -f -'.
                    // This ensures the namespace exists (creating it if missing, updating it if present) without throwing errors.
                    sh "kubectl create namespace amazona --dry-run=client -o yaml | kubectl apply -f -"

                    // Task 2: Credentials Rotation (RegCred)
                    // Problem: AWS ECR tokens expire every 12 hours.
                    // Solution: We regenerate the 'regcred' secret on every deployment to ensure the cluster can always pull images.
                    // We use the same dry-run pattern here to safely create or update the secret.
                    def regServer = env.FRONTEND_ECR_URL.split('/')[0]
                    sh """
                        kubectl create secret docker-registry regcred \
                        --docker-server=${regServer} \
                        --docker-username=AWS \
                        --docker-password=\$(aws ecr get-login-password --region ${AWS_REGION}) \
                        --dry-run=client -o yaml | kubectl apply -n amazona -f -
                    """

                    // Task 3: Atomic Application Deployment via Helm
                    // Why Helm?
                    // 1. Atomic Updates: Updates all components (Deployments, Services, Configs) together.
                    // 2. Secret Injection: Securely passes Jenkins credentials into K8s environment variables.
                    // 3. Hooks Management: Automatically handles the database seeding logic (Post-Install Hooks).
                    // 4. Verification: '--wait' ensures the pipeline only passes if the pods actually start running.
                    sh """
                        helm upgrade --install amazona ./k8s-chart \
                        --namespace amazona \
                        --set frontend.image=${env.FRONTEND_ECR_URL}:${FRONTEND_IMAGE_TAG} \
                        --set backend.image=${env.BACKEND_ECR_URL}:${BACKEND_IMAGE_TAG} \
                        --set secrets.AWS_ACCESS_KEY=${AWS_ACCESS_KEY} \
                        --set secrets.AWS_SECRET_KEY=${AWS_SECRET_KEY} \
                        --set secrets.JWT_TOKEN=${JWT_TOKEN} \
                        --set secrets.mongoUser=${DB_USER} \
                        --set secrets.mongoPass=${DB_PASS} \
                        --set config.bucketName=${env.BUCKET_NAME} \
                        --wait
                    """
                }
            }
        }
    }
}
