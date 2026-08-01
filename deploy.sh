#!/usr/bin/env bash
# Manual reproduction of the deploy step, run on the EC2 instance itself.
# Mirrors exactly what the Jenkins "Deploy to EC2" stage does over SSH.
#
# Usage: ./deploy.sh <ECR_REPO_URI> <IMAGE_TAG> <AWS_REGION>
# Example: ./deploy.sh 123456789012.dkr.ecr.ap-south-1.amazonaws.com/flask-cicd-app abc1234 ap-south-1

set -euo pipefail

ECR_REPO="${1:?Usage: deploy.sh <ECR_REPO_URI> <IMAGE_TAG> <AWS_REGION>}"
IMAGE_TAG="${2:?Usage: deploy.sh <ECR_REPO_URI> <IMAGE_TAG> <AWS_REGION>}"
AWS_REGION="${3:?Usage: deploy.sh <ECR_REPO_URI> <IMAGE_TAG> <AWS_REGION>}"
CONTAINER_NAME="flask-app"
APP_PORT=5000

echo "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPO"

echo "Pulling image $ECR_REPO:$IMAGE_TAG ..."
docker pull "$ECR_REPO:$IMAGE_TAG"

echo "Stopping and removing any existing container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting new container..."
docker run -d --name "$CONTAINER_NAME" -p "${APP_PORT}:${APP_PORT}" "$ECR_REPO:$IMAGE_TAG"

echo "Verifying deployment via /health ..."
sleep 3
if curl -sf "http://localhost:${APP_PORT}/health"; then
  echo -e "\nDeployment verified successfully."
else
  echo -e "\nDeployment verification FAILED — container did not respond healthy."
  exit 1
fi
