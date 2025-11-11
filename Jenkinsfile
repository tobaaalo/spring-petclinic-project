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
        //         script {
        //             // Run tests with proper database initialization
        //             sh '''
        //                 mvn test \
        //                 -Dspring.profiles.active=test \
        //                 -Dspring.sql.init.mode=always \
        //                 -Dspring.jpa.defer-datasource-initialization=true
        //             '''
        //         }
        //     }
        //     post {
        //         always {
        //             // Publish test results
        //             junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
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
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true, credentialsId: 'jenkins-sonarqube-token'
                    }
                }
            }
        }
        
        stage("Build & Push Docker Image") {
            steps {
                script {
                    docker.withRegistry('', DOCKER_PASS) {
                        def docker_image = docker.build("${IMAGE_NAME}")
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
        
        stage("Cleanup Artifacts") {
            steps {
                script {
                    sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                    sh "docker rmi ${IMAGE_NAME}:latest || true"
                }
            }
        }
        
        stage("Trigger CD Pipeline") {
            steps {
                script {
                    sh """
                        curl -v --user adminUser:${JENKINS_API_TOKEN} \
                        -X POST \
                        -H 'cache-control: no-cache' \
                        -H 'content-type: application/x-www-form-urlencoded' \
                        --data 'IMAGE_TAG=${IMAGE_TAG}' \
                        'https://ec2-35-178-210-128.eu-west-2.compute.amazonaws.com:8080/job/spring-pet-pipeline-01/buildWithParameters?token=gitops-token'
                    """
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
