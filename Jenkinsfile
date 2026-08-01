pipeline {
    agent any

    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REPO     = '277385995709.dkr.ecr.us-east-1.amazonaws.com/flask-cicd-app'
        IMAGE_TAG    = "${env.GIT_COMMIT}"
        EC2_HOST     = 'ec2-user@44.204.225.143'
        APP_PORT     = '5000'
        CONTAINER    = 'flask-app'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                script { env.LAST_STAGE = 'Checkout' }
                checkout scm
            }
        }

        stage('Install dependencies') {
            steps {
                script { env.LAST_STAGE = 'Install dependencies' }
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Test') {
            steps {
                script { env.LAST_STAGE = 'Test' }
                sh '''
                    . venv/bin/activate
                    pytest --junitxml=results.xml
                '''
            }
            post {
                always {
                    junit 'results.xml'
                }
                // any test failure throws a non-zero exit from pytest,
                // which fails this stage and halts the pipeline here —
                // Build/Push/Deploy never run.
            }
        }

        stage('Build') {
            steps {
                script { env.LAST_STAGE = 'Build' }
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
            }
        }

        stage('Push to ECR') {
            steps {
                script { env.LAST_STAGE = 'Push to ECR' }
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh '''
                        aws ecr get-login-password --region $AWS_REGION | \
                            docker login --username AWS --password-stdin $ECR_REPO
                        docker push $ECR_REPO:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script { env.LAST_STAGE = 'Deploy to EC2' }
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh '''
                        # Ship the same deploy.sh used for manual reproduction —
                        # single source of truth for the deploy logic, run by
                        # both the pipeline and a human if Jenkins is down.
                        scp -o StrictHostKeyChecking=no deploy.sh $EC2_HOST:/tmp/deploy.sh
                        ssh -o StrictHostKeyChecking=no $EC2_HOST "chmod +x /tmp/deploy.sh"
                        ssh -o StrictHostKeyChecking=no $EC2_HOST "/tmp/deploy.sh $ECR_REPO $IMAGE_TAG $AWS_REGION"
                    '''
                    // deploy.sh itself pulls, replaces the running container,
                    // and curls /health at the end — it exits non-zero if the
                    // health check fails, which fails this stage automatically.
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script { env.LAST_STAGE = 'Verify Deployment' }
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no $EC2_HOST \
                            'curl -sf http://localhost:'"$APP_PORT"'/health'
                    '''
                    // Independent, explicit gate on top of deploy.sh's own check —
                    // curl -f fails (non-zero exit) on any non-2xx response, so a
                    // container that starts but crashes immediately still fails
                    // the pipeline here even if deploy.sh's timing missed it.
                }
            }
        }
    }

    post {
        success {
            emailext(
                subject: "✅ SUCCESS: flask-cicd-app deployed (${env.GIT_COMMIT.take(7)})",
                body: """
                    <p><b>Deployment succeeded.</b></p>
                    <ul>
                      <li>Commit: ${env.GIT_COMMIT} (branch: ${env.GIT_BRANCH})</li>
                      <li>Image: ${ECR_REPO}:${IMAGE_TAG}</li>
                      <li>Deployed to: ${EC2_HOST}</li>
                      <li>Pipeline run: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></li>
                    </ul>
                """,
                mimeType: 'text/html',
                to: 'tanishqb212000@gmail.com'
            )
        }
        failure {
            emailext(
                subject: "❌ FAILED: flask-cicd-app pipeline — stage: ${env.LAST_STAGE ?: 'Unknown'}",
                body: """
                    <p><b>Pipeline failed.</b></p>
                    <ul>
                      <li>Failed stage: ${env.LAST_STAGE ?: 'Unknown'}</li>
                      <li>Commit: ${env.GIT_COMMIT} (branch: ${env.GIT_BRANCH})</li>
                      <li>Logs: <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></li>
                    </ul>
                """,
                mimeType: 'text/html',
                to: 'tanishqb212000@gmail.com'
            )
        }
    }
}