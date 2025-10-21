#!/bin/bash
DOCKERHUB_USERNAME="haideralvii"
IMAGE="${DOCKERHUB_USERNAME}/project-autoscale:latest"

# Ensure Docker is running
systemctl start docker

# Pull and start container
docker pull "$IMAGE"
docker run -d --name project-autoscale -p 8080:8080 --restart=always "$IMAGE"

