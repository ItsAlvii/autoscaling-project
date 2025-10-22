#!/bin/bash
set -e

# Load deployment environment variables
if [ -f scripts/deploy_env.sh ]; then
    source scripts/deploy_env.sh
fi

DOCKERHUB_USERNAME="haideralvii"
IMAGE_NAME="${DOCKERHUB_USERNAME}/project-autoscale"
IMAGE_TAG="${DEPLOY_IMAGE_TAG:-latest}"

# Ensure Docker is running
systemctl start docker

# Stop and remove old container
docker rm -f project-autoscale || true

# Pull and run new container
docker pull "${IMAGE_NAME}:${IMAGE_TAG}"
docker run -d --name project-autoscale -p 8080:8080 --restart=always "${IMAGE_NAME}:${IMAGE_TAG}"

