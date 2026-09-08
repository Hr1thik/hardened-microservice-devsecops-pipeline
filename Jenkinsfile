pipeline {
    agent any

    environment {
        APP_IMAGE = "devsecops-app:${BUILD_NUMBER}"
    }

    stages {
        stage('Secrets Scanning') {
            steps {
                echo 'Running TruffleHog secrets scan...'
                sh '''
                    docker run --rm -v "${WORKSPACE}":/pwd \
                        trufflesecurity/trufflehog:latest filesystem /pwd --fail
                '''
            }
        }

        stage('SAST Analysis') {
            steps {
                echo 'Running Semgrep SAST against OWASP Top 10...'
                sh '''
                    docker run --rm -v "${WORKSPACE}":/src \
                        semgrep/semgrep semgrep scan --config auto --error
                '''
            }
        }

        stage('IaC & Policy Audit') {
            steps {
                echo 'Running Trivy IaC configuration audit...'
                sh '''
                    docker run --rm -v "${WORKSPACE}":/src \
                        aquasec/trivy:latest config --exit-code 1 /src
                '''

                echo 'Running Kyverno admission policy validation...'
                sh '''
                    docker run --rm -v "${WORKSPACE}":/workspace \
                        ghcr.io/kyverno/kyverno-cli:latest \
                        apply /workspace/k8s/policies/policy-disallow-root.yml \
                        --resource /workspace/k8s/deployment.yml
                '''
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building production image: ${APP_IMAGE}..."
                sh "docker build -t ${APP_IMAGE} ."
            }
        }

        stage('Container Vulnerability Scan') {
            steps {
                echo 'Running Trivy container scan for unpatched HIGH/CRITICAL CVEs...'
                sh """
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --ignore-unfixed \
                        --exit-code 1 \
                        ${APP_IMAGE}
                """
            }
        }
    }

    post {
        always {
            echo 'Cleaning up intermediate images and containers...'
            sh "docker rmi ${APP_IMAGE} || true"
        }
        success {
            echo 'All DevSecOps quality gates passed successfully!'
        }
        failure {
            echo 'Pipeline failed due to security or policy violations.'
        }
    }
}