#!/bin/bash
# scripts/tag-images.sh
# Purpose: Tag all Docker images with semantic versioning and git SHA
# Author: DevOps Team
# Usage: ./scripts/tag-images.sh [version] [environment]
# Example: ./scripts/tag-images.sh 1.0.0 production

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VERSION=${1:-$(cat VERSION 2>/dev/null || echo "1.0.0")}
ENVIRONMENT=${2:-"development"}
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="reports/tagging-report-$TIMESTAMP.txt"

# Validate version format (semantic versioning)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format. Use semantic versioning (MAJOR.MINOR.PATCH)${NC}"
    echo "Example: 1.0.0"
    exit 1
fi

# Validate environment
VALID_ENVS=("development" "staging" "production")
if [[ ! " ${VALID_ENVS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    echo -e "${RED}Error: Invalid environment. Use: development, staging, or production${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Docker Image Tagging                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Tagging Configuration:${NC}"
echo -e "  Version: ${YELLOW}v${VERSION}${NC}"
echo -e "  Git SHA: ${YELLOW}${GIT_SHA}${NC}"
echo -e "  Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "  Timestamp: ${YELLOW}${TIMESTAMP}${NC}"
echo ""

# Confirm before proceeding
read -p "Proceed with tagging? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Tagging cancelled."
    exit 0
fi

# Initialize report
{
    echo "Docker Image Tagging Report"
    echo "Generated: $(date)"
    echo "Version: v${VERSION}"
    echo "Git SHA: ${GIT_SHA}"
    echo "Environment: ${ENVIRONMENT}"
    echo "=============================================="
    echo ""
} > "$REPORT_FILE"

# Services to tag
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

echo -e "${CYAN}Tagging images...${NC}"
echo ""

SUCCESSFUL=0
FAILED=0

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Processing: $service${NC}"
    
    # Check if optimized image exists
    if ! docker images "${service}:optimized" --format "{{.Repository}}" | grep -q "^${service}$"; then
        echo -e "${RED}  ✗ Image not found: ${service}:optimized${NC}"
        FAILED=$((FAILED + 1))
        
        {
            echo "Service: $service"
            echo "  Status: FAILED - Image not found"
            echo ""
        } >> "$REPORT_FILE"
        
        continue
    fi
    
    # Tag 1: Version + Git SHA (primary identifier)
    TAG_VERSION_SHA="v${VERSION}-${GIT_SHA}"
    docker tag "${service}:optimized" "${service}:${TAG_VERSION_SHA}"
    echo -e "${GREEN}  ✓ Tagged: ${service}:${TAG_VERSION_SHA}${NC}"
    
    # Tag 2: Version only
    TAG_VERSION="v${VERSION}"
    docker tag "${service}:optimized" "${service}:${TAG_VERSION}"
    echo -e "${GREEN}  ✓ Tagged: ${service}:${TAG_VERSION}${NC}"
    
    # Tag 3: Environment
    TAG_ENV="${ENVIRONMENT}"
    docker tag "${service}:optimized" "${service}:${TAG_ENV}"
    echo -e "${GREEN}  ✓ Tagged: ${service}:${TAG_ENV}${NC}"
    
    # Tag 4: Latest (always)
    docker tag "${service}:optimized" "${service}:latest"
    echo -e "${GREEN}  ✓ Tagged: ${service}:latest${NC}"
    
    SUCCESSFUL=$((SUCCESSFUL + 1))
    
    # Add to report
    {
        echo "Service: $service"
        echo "  Status: SUCCESS"
        echo "  Tags Created:"
        echo "    - ${service}:${TAG_VERSION_SHA}"
        echo "    - ${service}:${TAG_VERSION}"
        echo "    - ${service}:${TAG_ENV}"
        echo "    - ${service}:latest"
        echo ""
    } >> "$REPORT_FILE"
    
    echo ""
done

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Tagging Summary                                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Successful: $SUCCESSFUL${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

# Final report
{
    echo "=============================================="
    echo "SUMMARY"
    echo "=============================================="
    echo "Successful: $SUCCESSFUL"
    echo "Failed: $FAILED"
    echo ""
    echo "Next Steps:"
    echo "1. Verify tags: docker images | grep '$service'"
    echo "2. Push to registry: ./scripts/push-to-registry.sh"
    echo "3. Update git tag: git tag v${VERSION} && git push --tags"
} >> "$REPORT_FILE"

echo -e "${CYAN}Report saved to: ${YELLOW}$REPORT_FILE${NC}"
echo ""

# Show tagged images
echo -e "${CYAN}Tagged images (sample):${NC}"
docker images auth-service --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -6
echo ""

# Next steps
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Verify tags: docker images | grep 'v${VERSION}'"
echo "  2. Create git tag: git tag -a v${VERSION} -m 'Release v${VERSION}'"
echo "  3. Push to registry: ./scripts/push-to-registry.sh v${VERSION}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All images tagged successfully!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some images failed to tag. Check report for details.${NC}"
    exit 1
fi