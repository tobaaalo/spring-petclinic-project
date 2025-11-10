pipeline {
    agent { label 'Jenkins-Agent' }
    
    tools {
        jdk 'Java17'
        maven 'Maven3'
    }
    
    environment {
        APP_NAME = "spring-petclinic-project"
        RELEASE = "1.0.0"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
    }
    
    stages {
        // -------------------------
        stage("Cleanup Workspace") {
            steps {
                cleanWs()
            }
        }

        // -------------------------
        stage("Checkout from SCM") {
            steps {
                git branch: 'main', credentialsId: 'github', url: 'https://github.com/tobaaalo/spring-petclinic-project.git'
            }
        }

        // -------------------------
        stage("Build Application") {
            steps {
                sh "mvn clean package"
            }
        }

        // -------------------------
        stage("Test Application") {
            steps {
                sh "mvn test"
            }
        }

        // -------------------------
        stage("SonarQube Analysis") {
            steps {
                script {
                    withSonarQubeEnv(credentialsId: 'jenkins-sonarqube-token') {
                        sh "mvn sonar:sonar"
                    }
                }
            }
        }

        // -------------------------
        stage("Quality Gate") {
            steps {
                script {
                    // Wait for SonarQube quality gate result
                    waitForQualityGate abortPipeline: true, credentialsId: 'jenkins-sonarqube-token'
                }
            }
        }

        // -------------------------
        stage("Build & Push Docker Image") {
            steps {
                script {
                    // Use Jenkins credentials for Docker Hub
                    withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                     usernameVariable: 'DOCKER_USER',
                                                     passwordVariable: 'DOCKER_PASS')]) {
                        def IMAGE_NAME = "${DOCKER_USER}/${APP_NAME}"
                        
                        // Build Docker image
                        def docker_image = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                        
                        // Push to Docker Hub
                        docker.withRegistry('', DOCKER_PASS) {
                            docker_image.push("${IMAGE_TAG}")
                            docker_image.push('latest')
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! 🎉"
        }
        failure {
            echo "Pipeline failed! ❌ Check logs for details."
        }
        always {
            cleanWs()
        }
    }
}
