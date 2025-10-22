#!/bin/bash
set -e

# Stop and remove container
docker stop project-autoscale || true
docker rm project-autoscale || true

