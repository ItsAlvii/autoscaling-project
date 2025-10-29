#!/bin/bash
set -e

echo "Running pre-cleanup before file copy..."

# Stop any running containers (optional)
sudo docker stop app || true
sudo docker rm app || true

# Delete old deployment directory to prevent file conflicts
sudo rm -rf /home/ubuntu/autoscaing-project/* || true

echo "Pre-cleanup complete."

