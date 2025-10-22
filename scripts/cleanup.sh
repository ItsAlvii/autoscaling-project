#!/bin/bash
set -e

# Remove unused Docker resources
docker system prune -f || true


