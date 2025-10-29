#!/bin/bash
set -e

echo "🧹 Cleaning up old Docker containers and images..."
docker rm -f project-autoscale || true
docker system prune -f || true
echo "Cleanup complete."

