// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        AWS_REGION = 'us-west-2'
        ECR_REPOSITORY = 'opentelemetry-demo'
    }

    stages {
        stage('Check agent tools') {
            steps {
                sh '''
                    set -eu
                    for tool in aws docker git go python3; do
                        command -v "$tool" >/dev/null 2>&1 || {
                            echo "Required tool is missing: $tool" >&2
                            exit 1
                        }
                    done
                    docker compose version
                '''
            }
        }

        stage('Check for GitOps-only commit') {
            steps {
                script {
                    env.GITOPS_ONLY = sh(
                        script: "git log -1 --format=%s | grep -Fq '[gitops-only]' && echo true || echo false",
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Validate GitOps image updater') {
            steps {
                sh '''
                    set -eu
                    sh -n scripts/publish-images-to-ecr.sh scripts/update-argocd-image-tags.sh
                    python3 -m unittest discover -s test -p 'test_update_argocd_image_tags.py'
                '''
            }
        }

        stage('Build Product Catalog') {
            steps {
                dir('src/product-catalog') {
                    sh 'go build ./...'
                }
            }
        }

        stage('Test Product Catalog') {
            steps {
                dir('src/product-catalog') {
                    sh 'go test ./...'
                }
            }
        }

        stage('Create ECR repository and log in') {
            when {
                allOf {
                    branch 'main'
                    expression { env.GITOPS_ONLY != 'true' }
                }
            }
            steps {
                sh 'bash scripts/publish-images-to-ecr.sh login'
            }
        }

        stage('Build Docker images') {
            when {
                allOf {
                    branch 'main'
                    expression { env.GITOPS_ONLY != 'true' }
                }
            }
            steps {
                sh 'bash scripts/publish-images-to-ecr.sh build'
            }
        }

        stage('Push Docker images to ECR') {
            when {
                allOf {
                    branch 'main'
                    expression { env.GITOPS_ONLY != 'true' }
                }
            }
            steps {
                sh 'bash scripts/publish-images-to-ecr.sh push'
            }
        }

        stage('Update GitOps image tags') {
            when {
                allOf {
                    branch 'main'
                    expression { env.GITOPS_ONLY != 'true' }
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-gitops-write',
                    usernameVariable: 'GITOPS_USERNAME',
                    passwordVariable: 'GITOPS_TOKEN'
                )]) {
                    sh '''
                        set +x
                        BEFORE=$(git rev-parse HEAD)
                        bash scripts/update-argocd-image-tags.sh
                        AFTER=$(git rev-parse HEAD)
                        if [ "$BEFORE" != "$AFTER" ]; then
                            AUTH=$(printf '%s' "$GITOPS_USERNAME:$GITOPS_TOKEN" | base64 | tr -d '\\n')
                            git -c "http.extraheader=AUTHORIZATION: basic $AUTH" push origin HEAD:main
                        fi
                    '''
                }
            }
        }
    }
}
