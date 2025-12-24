# ===== RETAG SCRIPT =====
# scripts/retag-for-environment.sh
#!/bin/bash
# Purpose: Update environment tags for deployment
# Usage: ./scripts/retag-for-environment.sh <version> <environment>
# Example: ./scripts/retag-for-environment.sh v1.0.0-a3f9c82 production

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

VERSION_TAG=$1
ENVIRONMENT=$2

if [ -z "$VERSION_TAG" ] || [ -z "$ENVIRONMENT" ]; then
    echo -e "${RED}Usage: $0 <version-tag> <environment>${NC}"
    echo "Example: $0 v1.0.0-a3f9c82 production"
    exit 1
fi

VALID_ENVS=("development" "staging" "production")
if [[ ! " ${VALID_ENVS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    echo -e "${RED}Error: Invalid environment. Use: development, staging, or production${NC}"
    exit 1
fi

echo -e "${BLUE}Retagging images for ${ENVIRONMENT} environment${NC}"
echo -e "Version: ${YELLOW}${VERSION_TAG}${NC}"
echo ""

SERVICES=(
    "auth-service"
    "user-service"
    "billing-service"
    "payment-service"
    "notification-service"
    "analytics-service"
    "admin-service"
    "frontend"
)

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}$service${NC}"
    
    # Check if version tag exists
    if ! docker images "${service}:${VERSION_TAG}" --format "{{.Repository}}" | grep -q "^${service}$"; then
        echo -e "${RED}  ✗ Version tag not found: ${service}:${VERSION_TAG}${NC}"
        continue
    fi
    
    # Retag for environment
    docker tag "${service}:${VERSION_TAG}" "${service}:${ENVIRONMENT}"
    echo -e "${GREEN}  ✓ Retagged: ${service}:${ENVIRONMENT}${NC}"
done

echo ""
echo -e "${GREEN}✓ Environment tags updated!${NC}"
echo -e "${CYAN}Verify: docker images | grep ${ENVIRONMENT}${NC}"