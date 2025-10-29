#!/bin/bash
set -e

cd /home/ubuntu/autoscaing-project

if [ -f scripts/deploy_env.sh ]; then
  source scripts/deploy_env.sh
else
  echo "⚠️ deploy_env.sh not found, using 'latest' tag."
  DEPLOY_IMAGE_TAG="latest"
fi

IMAGE="haideralvii/project-autoscale:${DEPLOY_IMAGE_TAG}"

echo "🚀 Deploying image: $IMAGE"

systemctl start docker || true
docker pull "$IMAGE"
docker rm -f project-autoscale || true
docker run -d --name project-autoscale -p 8080:8080 --restart=always "$IMAGE"

echo "✅ Deployment finished: $IMAGE"

