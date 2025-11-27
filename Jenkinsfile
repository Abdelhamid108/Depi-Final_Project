pipeline {
    agent any

    environment {
        
        AWS_REGION = 'us-east-1'
        IMAGE_TAG = "v1.0"
        
        AWS_ACCESS_KEY = credentials('aws-access-key')
        AWS_ACCESS_KEY = credentials('aws-secret-key')
        

        AWS_ACCESS_KEY = credentials('amazona-jwt-key')
        
        DB_CREDS = credentials('mongo_db_creds')
       
        DB_USER = "${DB_CREDS_USR}"
        DB_PASS = "${DB_CREDS_PSW}"
           
    } 
    parameters {
     booleanParam defaultValue: false, name: 'IsFirstRun'
    }


    stages {
        stage('Fetch Configuration') {
            steps {
                    script {
                        env.FRONTEND_ECR_URL = sh(script: 'aws ssm get-parameter   --name "/depi-project/amazona/frontend-ecr"   --query "Parameter.Value"   --output text', returnStdout: true).trim()
                        env.BACKEND_ECR_URL = sh(script: 'aws ssm get-parameter   --name "/depi-project/amazona/backend-ecr"   --query "Parameter.Value"   --output text' , returnStdout: true).trim()
                        env.BUCKET_NAME = sh(script: 'aws ssm get-parameter   --name "/depi-project/amazona/products-bucket"   --query "Parameter.Value"   --output text' , returnStdout: true).trim()
                        echo "Frontend Repo URL :${env.FRONTEND_ECR_URL}"
                    }
                }
            }
        

        stage('Check Changes') {
            steps {
                script {
                    if (IsFirstRun) {
                       env.BUILD_FRONTEND = 'true'
                       env.BUILD_BACKEND  = 'true'
                       env.APPLY_MANIFESTS = 'true'
                    } else {
                    
                    def changes = sh(script: 'git diff --name-only HEAD~1 || true', returnStdout: true).trim()
                    env.BUILD_FRONTEND = changes.contains('frontend/') ? 'true' : 'false'
                    env.BUILD_BACKEND  = changes.contains('backend/') ? 'true' : 'false'
                    if (changes.contains('k8s_manifests/') || env.BUILD_FRONTEND == 'true' || env.BUILD_BACKEND == 'true') {
                        env.APPLY_MANIFESTS = 'true' } else {
                        env.APPLY_MANIFETS = 'false'
                    }

                    echo "Changed files:\n${changes}"
                    echo "BUILD_FRONTEND=${env.BUILD_FRONTEND}, BUILD_BACKEND=${env.BUILD_BACKEND}, APPLY_MANIFESTS=${env.APPLY_MANIFESTS}"
                   }
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
                        sh "docker build -t ${env.FRONTEND_ECR_URL}:${IMAGE_TAG} ."
                        sh "docker push ${env.FRONTEND_ECR_URL}:${IMAGE_TAG}"
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
                        sh "docker build -t ${env.BACKEND_ECR_URL}:${IMAGE_TAG} ."
                        sh "docker push ${env.BACKEND_ECR_URL}:${IMAGE_TAG}"
                    }
                }
            }
        }
        stage ('Deploy Manifists') {
          agent { label 'k8s_master' }
          when { environment name: 'APPLY_MANIFESTS', value: 'true' }
          steps {
           script {
             dir ('k8s_manifests') {
             envsubst < 01-configmaps.yaml > 01-configmaps-injected.yaml && mv 01-configmaps-injected.yaml 01-configmaps.yaml
             envsubst < 01-secrets.yaml > 01-secrets-injected.yaml && mv 01-secrets-injected.yaml 01-secrets.yaml
             
            kubectl apply -R .
            if (env.BUILD_BACKEND) {
               kubectl set
             }
         
            }

           }
          }
        }
    }
}

