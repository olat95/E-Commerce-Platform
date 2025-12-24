
#!/bin/bash
# scripts/push-to-registry.sh
# Purpose: Push all Docker images to container registry with full automation
# Author: DevOps Team
# Usage: ./scripts/push-to-registry.sh [registry-type] [namespace]
# Example: ./scripts/push-to-registry.sh dockerhub yourusername

set -e  # Exit on any error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Registry configuration
REGISTRY_TYPE="${1:-dockerhub}"  # dockerhub, ecr, acr, ghcr
NAMESPACE="${2:-${DOCKER_HUB_USERNAME}}"  # Your Docker Hub username or registry namespace

# Report configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="reports/registry"
REPORT_FILE="$REPORT_DIR/push-report-$TIMESTAMP.txt"
ERROR_LOG="$REPORT_DIR/push-errors-$TIMESTAMP.log"

# Create report directory
mkdir -p "$REPORT_DIR"

# Services to push
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

# Tags to push for each service
# Note: Build script creates these tags automatically with git hash
TAGS_TO_PUSH=(
    "latest"
    "v1.0.0"
    "v1.0.0-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

# Function: Print header
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Docker Image Registry Push                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function: Validate prerequisites
validate_prerequisites() {
    echo -e "${CYAN}Validating prerequisites...${NC}"
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker is installed${NC}"
    
    # Check if docker daemon is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker daemon is running${NC}"
    
    # Check if logged in to registry
    # Check config.json for authentication (more reliable on Windows)
    if [ ! -f ~/.docker/config.json ] || ! grep -q "auths" ~/.docker/config.json 2>/dev/null; then
        echo -e "${YELLOW}⚠ Cannot verify Docker registry login${NC}"
        echo -e "${YELLOW}If push fails, run: docker login${NC}"
    else
        echo -e "${GREEN}✓ Docker credentials found${NC}"
    fi
    
    # Check if namespace is set
    if [ -z "$NAMESPACE" ]; then
        echo -e "${RED}✗ Namespace not set${NC}"
        echo -e "${YELLOW}Usage: $0 dockerhub yourusername${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Namespace: $NAMESPACE${NC}"
    
    echo ""
}

# Function: Determine registry URL
get_registry_url() {
    case $REGISTRY_TYPE in
        dockerhub)
            REGISTRY_URL=""  # Docker Hub is default, no URL prefix needed
            FULL_PREFIX="$NAMESPACE"
            ;;
        ecr)
            # AWS ECR format: <account-id>.dkr.ecr.<region>.amazonaws.com
            if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$AWS_REGION" ]; then
                echo -e "${RED}Error: AWS_ACCOUNT_ID and AWS_REGION required for ECR${NC}"
                exit 1
            fi
            REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            FULL_PREFIX="$REGISTRY_URL"
            ;;
        acr)
            # Azure ACR format: <registry-name>.azurecr.io
            if [ -z "$ACR_NAME" ]; then
                echo -e "${RED}Error: ACR_NAME required for Azure Container Registry${NC}"
                exit 1
            fi
            REGISTRY_URL="${ACR_NAME}.azurecr.io"
            FULL_PREFIX="$REGISTRY_URL"
            ;;
        ghcr)
            # GitHub Container Registry format: ghcr.io/<namespace>
            REGISTRY_URL="ghcr.io"
            FULL_PREFIX="$REGISTRY_URL/$NAMESPACE"
            ;;
        *)
            echo -e "${RED}Error: Unknown registry type: $REGISTRY_TYPE${NC}"
            echo -e "${YELLOW}Supported: dockerhub, ecr, acr, ghcr${NC}"
            exit 1
            ;;
    esac
}

# Function: Tag image for registry
tag_for_registry() {
    local service=$1
    local local_tag=$2
    local registry_tag="${FULL_PREFIX}/${service}:${local_tag}"
    
    # Check if local image exists
    if ! docker images "${service}:${local_tag}" --format "{{.Repository}}" | grep -q "^${service}$"; then
        echo -e "${YELLOW}  ⚠ Local image not found: ${service}:${local_tag}${NC}"
        return 1
    fi
    
    # Tag for registry
    docker tag "${service}:${local_tag}" "$registry_tag"
    echo -e "${GREEN}  ✓ Tagged: $registry_tag${NC}"
    
    return 0
}

# Function: Push image to registry
push_image() {
    local image=$1
    local start_time=$(date +%s)
    
    echo -e "${CYAN}Pushing: $image${NC}"
    
    # Push with output capture for logging
    if docker push "$image" 2>&1 | tee -a "$ERROR_LOG"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ Pushed successfully (${duration}s)${NC}"
        return 0
    else
        echo -e "${RED}✗ Push failed${NC}"
        return 1
    fi
}

# Function: Calculate image size
get_image_size() {
    local image=$1
    docker inspect "$image" --format='{{.Size}}' 2>/dev/null || echo 0
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header

# Initialize report
{
    echo "Docker Registry Push Report"
    echo "Generated: $(date)"
    echo "Registry: $REGISTRY_TYPE"
    echo "Namespace: $NAMESPACE"
    echo "=============================================="
    echo ""
} > "$REPORT_FILE"

# Validate prerequisites
validate_prerequisites

# Determine registry URL
get_registry_url

echo -e "${CYAN}Configuration:${NC}"
echo -e "  Registry Type: ${YELLOW}$REGISTRY_TYPE${NC}"
echo -e "  Namespace: ${YELLOW}$NAMESPACE${NC}"
echo -e "  Full Prefix: ${YELLOW}$FULL_PREFIX${NC}"
echo -e "  Services: ${YELLOW}${#SERVICES[@]}${NC}"
echo -e "  Tags per service: ${YELLOW}${#TAGS_TO_PUSH[@]}${NC}"
echo ""

# Confirm before proceeding
read -p "Proceed with pushing images? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Push cancelled."
    exit 0
fi

# Counters
TOTAL_IMAGES=0
SUCCESSFUL_PUSHES=0
FAILED_PUSHES=0
TOTAL_SIZE=0

# Process each service
for service in "${SERVICES[@]}"; do
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Processing: $service${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    SERVICE_SUCCESS=0
    SERVICE_FAILED=0
    
    {
        echo "Service: $service"
        echo "----------------------------------------"
    } >> "$REPORT_FILE"
    
    # Tag and push each version
    for tag in "${TAGS_TO_PUSH[@]}"; do
        TOTAL_IMAGES=$((TOTAL_IMAGES + 1))
        
        # Tag for registry
        if tag_for_registry "$service" "$tag"; then
            registry_image="${FULL_PREFIX}/${service}:${tag}"
            
            # Get image size
            size=$(get_image_size "$registry_image")
            TOTAL_SIZE=$((TOTAL_SIZE + size))
            
            # Push to registry
            if push_image "$registry_image"; then
                SUCCESSFUL_PUSHES=$((SUCCESSFUL_PUSHES + 1))
                SERVICE_SUCCESS=$((SERVICE_SUCCESS + 1))
                
                {
                    echo "  ✓ $tag - SUCCESS"
                    echo "    URL: $registry_image"
                    echo "    Size: $((size / 1048576)) MB"
                } >> "$REPORT_FILE"
            else
                FAILED_PUSHES=$((FAILED_PUSHES + 1))
                SERVICE_FAILED=$((SERVICE_FAILED + 1))
                
                {
                    echo "  ✗ $tag - FAILED"
                } >> "$REPORT_FILE"
            fi
        else
            FAILED_PUSHES=$((FAILED_PUSHES + 1))
            SERVICE_FAILED=$((SERVICE_FAILED + 1))
            
            {
                echo "  ✗ $tag - NOT FOUND"
            } >> "$REPORT_FILE"
        fi
        
        echo ""
    done
    
    # Service summary
    echo -e "${CYAN}Service Summary:${NC}"
    echo -e "  Successful: ${GREEN}$SERVICE_SUCCESS${NC}"
    echo -e "  Failed: ${RED}$SERVICE_FAILED${NC}"
    
    {
        echo "  Summary: $SERVICE_SUCCESS successful, $SERVICE_FAILED failed"
        echo ""
    } >> "$REPORT_FILE"
done

# ============================================================================
# FINAL SUMMARY
# ============================================================================

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Push Summary                                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Total Images: ${TOTAL_IMAGES}${NC}"
echo -e "${GREEN}Successful: ${SUCCESSFUL_PUSHES}${NC}"
echo -e "${RED}Failed: ${FAILED_PUSHES}${NC}"
echo -e "${YELLOW}Total Size: $((TOTAL_SIZE / 1048576)) MB${NC}"
echo ""

# Write summary to report
{
    echo "=============================================="
    echo "TOTAL SUMMARY"
    echo "=============================================="
    echo "Total Images: $TOTAL_IMAGES"
    echo "Successful: $SUCCESSFUL_PUSHES"
    echo "Failed: $FAILED_PUSHES"
    echo "Total Size: $((TOTAL_SIZE / 1048576)) MB"
    echo ""
    echo "Registry URLs:"
    for service in "${SERVICES[@]}"; do
        echo "  ${FULL_PREFIX}/${service}"
    done
    echo ""
} >> "$REPORT_FILE"

# Show registry URLs
echo -e "${CYAN}Your images are now available at:${NC}"
if [ "$REGISTRY_TYPE" = "dockerhub" ]; then
    echo -e "  https://hub.docker.com/r/${NAMESPACE}"
    echo ""
    echo -e "${CYAN}Individual repositories:${NC}"
    for service in "${SERVICES[@]}"; do
        echo -e "  https://hub.docker.com/r/${NAMESPACE}/${service}"
    done
else
    for service in "${SERVICES[@]}"; do
        echo -e "  ${FULL_PREFIX}/${service}"
    done
fi

echo ""
echo -e "${CYAN}Reports:${NC}"
echo -e "  Summary: ${YELLOW}$REPORT_FILE${NC}"
echo -e "  Errors: ${YELLOW}$ERROR_LOG${NC}"
echo ""

# Next steps
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Verify images on registry web interface"
echo "  2. Test pull: docker pull ${FULL_PREFIX}/auth-service:v1.0.0"
echo "  3. Update deployment configs with registry URLs"
echo "  4. Document registry workflows"
echo ""

# Exit code based on results
if [ $FAILED_PUSHES -eq 0 ]; then
    echo -e "${GREEN}✓ All images pushed successfully!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some pushes failed. Check error log for details.${NC}"
    exit 1
fi