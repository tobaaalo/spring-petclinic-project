pipeline {
    agent { label 'Jenkins-Agent' }
    
    tools {
        jdk 'Java17'
        maven 'Maven3'
    }
    
    environment {
        APP_NAME = "spring-petclinic-project"
        RELEASE = "1.0.0"
        DOCKER_USER = "tobaalo"
        DOCKER_PASS = 'dockerhub'
        IMAGE_NAME = "${DOCKER_USER}/${APP_NAME}"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
        JENKINS_API_TOKEN = credentials("JENKINS_API_TOKEN")
    }
    
    stages {
        stage("Cleanup Workspace") {
            steps {
                cleanWs()
            }
        }
        
        stage("Checkout from SCM") {
            steps {
                git branch: 'main', 
                    credentialsId: 'github', 
                    url: 'https://github.com/tobaaalo/spring-petclinic-project.git'
            }
        }

        stage('Format Code') {
            steps {
                sh 'mvn spring-javaformat:apply'
            }
}
        
        stage("Build Application") {
            steps {
                script {
                    // Build without tests first
                    sh "mvn clean package -DskipTests"
                }
            }
        }
        
        // stage("Test Application") {
        //     steps {
        //         sh "mvn test -Dmaven.test.failure.ignore=true"
        //     }
        //     post {
        //         always {
        //             junit '**/target/surefire-reports/*.xml'
        //         }
        //     }
        // }
        
        stage("SonarQube Analysis") {
            steps {
                script {
                    withSonarQubeEnv(credentialsId: 'jenkins-sonarqube-token') {
                        sh '''
                            mvn sonar:sonar \
                            -Dsonar.projectName=${APP_NAME} \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.java.binaries=target/classes
                        '''
                    }
                }
            }
        }
        
        stage("Quality Gate") {
            steps {
                script {
                    timeout(time: 15, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true, credentialsId: 'jenkins-sonarqube-token'
                    }
                }
            }
        }
        
        stage("Build & Push Docker Image") {
            steps {
                script {
                    docker.withRegistry('', DOCKER_PASS) {
                        // Pull the latest image to use as cache
                        try {
                            docker.image("${IMAGE_NAME}:latest").pull()
                        } catch (Exception e) {
                            echo "No cached image found, building from scratch"
                        }
                        
                        // Build with cache-from (without BuildKit)
                        def docker_image = docker.build(
                            "${IMAGE_NAME}",
                            "--cache-from ${IMAGE_NAME}:latest ."
                        )
                        
                        docker_image.push("${IMAGE_TAG}")
                        docker_image.push('latest')
                    }
                }
            }
        }
        
        stage("Trivy Scan") {
            steps {
                script {
                    sh """
                        docker run -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy image ${IMAGE_NAME}:latest \
                        --no-progress \
                        --scanners vuln \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --format table
                    """
                }
            }
        }
        
                
        stage("Trigger CD Pipeline") {
            steps {
                script {
                    build job: 'spring-pet-pipeline-cd',
                          parameters: [
                              string(name: 'IMAGE_TAG', value: "${IMAGE_TAG}")
                          ],
                          wait: false
                }
            }
        }
        
        stage("Cleanup Artifacts") {
            steps {
                script {
                    sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                    sh "docker rmi ${IMAGE_NAME}:latest || true"
                }
            }
        }
    }
    
    post {
        always {
            // Archive artifacts
            archiveArtifacts artifacts: '**/target/*.jar', allowEmptyArchive: true
        }
        failure {
            emailext body: '''${SCRIPT, template="groovy-html.template"}''',
                     subject: "${env.JOB_NAME} - Build # ${env.BUILD_NUMBER} - Failed",
                     mimeType: 'text/html',
                     to: "tobanehemiah@gmail.com",
                     attachLog: true
        }
        success {
            emailext body: '''${SCRIPT, template="groovy-html.template"}''',
                     subject: "${env.JOB_NAME} - Build # ${env.BUILD_NUMBER} - Successful",
                     mimeType: 'text/html',
                     to: "tobanehemiah@gmail.com"
        }
    }
}
