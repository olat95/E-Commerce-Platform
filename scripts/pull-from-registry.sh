# scripts/pull-from-registry.sh
#!/bin/bash
# Purpose: Pull images from registry for verification
# Usage: ./scripts/pull-from-registry.sh [service-name] [tag]

set -e

SERVICE=${1:-auth-service}
TAG=${2:-v1.0.0}
NAMESPACE=${DOCKER_HUB_USERNAME}

echo "Pulling ${NAMESPACE}/${SERVICE}:${TAG}..."

# Remove local image first (if exists)
docker rmi "${NAMESPACE}/${SERVICE}:${TAG}" 2>/dev/null || true

# Pull from registry
docker pull "${NAMESPACE}/${SERVICE}:${TAG}"

# Verify
echo ""
echo "✓ Successfully pulled!"
echo ""
echo "Image details:"
docker inspect "${NAMESPACE}/${SERVICE}:${TAG}" --format='
  Repository: {{.RepoTags}}
  Size: {{.Size}} bytes
  Created: {{.Created}}
  Architecture: {{.Architecture}}
  OS: {{.Os}}'