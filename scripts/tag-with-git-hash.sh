#!/bin/bash
# scripts/tag-with-git-hash.sh
# Purpose: Tag existing images with current git hash
# Usage: ./scripts/tag-with-git-hash.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get git commit hash
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Tagging Images with Git Hash                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}Current Git Hash: ${GIT_HASH}${NC}"
echo ""

SERVICES=("auth-service" "user-service" "billing-service" "payment-service" "notification-service" "analytics-service" "admin-service" "frontend")

for service in "${SERVICES[@]}"; do
    # Check if latest tag exists
    if docker image inspect "${service}:latest" &> /dev/null; then
        echo -e "${YELLOW}Tagging ${service}...${NC}"
        
        # Tag with git hash
        docker tag "${service}:latest" "${service}:v1.0.0-${GIT_HASH}"
        docker tag "${service}:latest" "${service}:production"
        
        echo -e "${GREEN}✓ ${service}:v1.0.0-${GIT_HASH}${NC}"
        echo -e "${GREEN}✓ ${service}:production${NC}"
    else
        echo -e "${YELLOW}⚠ ${service}:latest not found, skipping${NC}"
    fi
    echo ""
done

echo -e "${GREEN}✓ Tagging complete!${NC}"
echo ""
echo -e "${BLUE}Available tags for each service:${NC}"
echo -e "  - latest"
echo -e "  - production"
echo -e "  - v1.0.0"
echo -e "  - v1.0.0-${GIT_HASH}"
