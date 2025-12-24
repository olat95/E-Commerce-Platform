# scripts/list-registry-images.sh
#!/bin/bash
# Purpose: List all images in registry using Docker Hub API
# Usage: ./scripts/list-registry-images.sh [namespace]

set -e

NAMESPACE=${1:-${DOCKER_HUB_USERNAME}}

if [ -z "$NAMESPACE" ]; then
    echo "Error: Namespace required"
    echo "Usage: $0 yourusername"
    exit 1
fi

echo "Fetching repositories for namespace: $NAMESPACE"
echo ""

# List repositories (requires Docker Hub token)
curl -s "https://hub.docker.com/v2/repositories/${NAMESPACE}/?page_size=100" | \
    jq -r '.results[] | "\(.name): \(.pull_count) pulls, updated \(.last_updated)"'