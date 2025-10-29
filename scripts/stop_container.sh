#!/bin/bash
set -e

echo "🛑 Stopping running container if exists..."
docker rm -f project-autoscale || true
echo "Container stopped."

