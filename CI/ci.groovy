pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = "AWS_ACCOUNT_ID"
        AWS_REGION = "ap-south-1"
        ECR_REPO_NAME = "app-repo"
        BRANCH_NAME = "main"
        AWS_CREDENTIALS_ID = "aws-credentials-id"
    }

    triggers {
        pollSCM('H/5 * * * *') // Polls Git every 5 minutes check weather code commit happen or not
    }

    stages {
        stage('Checkout Repo') {
            steps {
                script {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${BRANCH_NAME}"]],
                        userRemoteConfigs: [[
                            url: 'https://github.com/Deepak-0822/theonemoment.git',
                            // credentialsId: 'c70fd5a3-dbcc-45df-b4d6-098b46d25cc9' ## Public repo - no credentials needed
                        ]]
                    ])
                }
            }
        }

        stage("Build & Package") {
            steps {
                script {
                    def pom = readMavenPom file: "pom.xml"
                    env.PROJECT_VERSION = pom.getVersion()
                }
                sh "mvn clean install -DskipTests"
                echo 'Maven build completed'
            }
        }

        stage("Docker Build & Push to ECR") {
            steps {
                script {
                    def imageTag = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${PROJECT_VERSION}-${BUILD_NUMBER}"

                    // Login to AWS ECR
                    withAWS(region: "${AWS_REGION}", credentials: "${AWS_CREDENTIALS_ID}") {
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    }

                    // Build and Push Docker Image
                    sh """
                    docker build -t ${imageTag} .
                    docker push ${imageTag}
                    """
                    
                    echo "Successfully pushed Docker image: ${imageTag}"
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline executed successfully!"
        }
        failure {
            echo "Pipeline failed. Check logs for errors."
        }
    }
}
