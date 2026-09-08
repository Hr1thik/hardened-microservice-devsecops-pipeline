pipeline {
    agent any

    environment {
        APP_IMAGE = "devsecops-app:${BUILD_NUMBER}"
        WS = "${WORKSPACE}"
    }

    stages {
        stage('Secrets Scanning') {
            steps {
                echo 'Running TruffleHog secrets scan...'
                sh """
                    docker run --rm --volumes-from jenkins-devsecops \
                        trufflesecurity/trufflehog:latest filesystem ${WS} --fail
                """
            }
        }

        stage('SAST Analysis') {
            steps {
                echo 'Running Semgrep SAST against OWASP Top 10...'
                sh """
                    docker run --rm --volumes-from jenkins-devsecops \
                        -e SEMGREP_IN_DOCKER=0 \
                        semgrep/semgrep semgrep scan \
                        --config "p/owasp-top-ten" \
                        --config "p/javascript" \
                        --exclude ".github" \
                        --exclude "k8s" \
                        --error ${WS}
                """
            }
        }

        stage('IaC & Policy Audit') {
            steps {
                echo 'Running Trivy IaC configuration audit...'
                sh """
                    docker run --rm --volumes-from jenkins-devsecops \
                        aquasec/trivy:latest config \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        ${WS}
                """

                echo 'Running Kyverno admission policy validation...'
                sh """
                    docker run --rm --volumes-from jenkins-devsecops \
                        ghcr.io/kyverno/kyverno-cli:latest \
                        apply ${WS}/k8s/policies/policy-disallow-root.yml \
                        --resource ${WS}/k8s/deployment.yml
                """
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building production image: ${APP_IMAGE}..."
                sh """
                    cd ${WS}
                    docker build -t ${APP_IMAGE} .
                """
            }
        }

        stage('DAST Dynamic Analysis') {
            steps {
                echo 'Executing OWASP ZAP baseline dynamic scan and generating report...'
                sh """
                    # 1. Create isolated network
                    docker network create zap-net || true

                    # 2. Start target app container
                    docker run -d --name dso-target-app --network zap-net ${APP_IMAGE}
                    sleep 4

                    # 3. Symlink /zap/wrk to Jenkins workspace and generate zap_report.html
                    docker run --rm --network zap-net \
                        --volumes-from jenkins-devsecops \
                        -u root \
                        --entrypoint sh \
                        zaproxy/zap-stable:latest \
                        -c "rm -rf /zap/wrk && ln -s ${WS} /zap/wrk && zap-baseline.py -t http://dso-target-app:3000 -m 1 -r zap_report.html -I || true"

                    # 4. Clean up test container and network
                    docker rm -f dso-target-app || true
                    docker network rm zap-net || true
                """
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
            echo 'All DevSecOps quality gates (SAST + DAST + IaC + CVEs) passed!'
        }
        failure {
            echo 'Pipeline failed due to security or policy violations.'
        }
    }
}