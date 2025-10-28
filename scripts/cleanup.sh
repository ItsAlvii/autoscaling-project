#!/bin/bash
set -e

# Stop any running container named "app"
sudo docker stop app || true
sudo docker rm app || true

# Remove unused Docker resources (containers, networks, images, volumes)
sudo docker system prune -af || true

# Clean old deployment files to prevent CodeDeploy overwrite errors
sudo rm -rf /home/ubuntu/autoscaing-project/* || true

echo "Cleanup complete: old app stopped, unused Docker resources removed, and project directory cleared."

