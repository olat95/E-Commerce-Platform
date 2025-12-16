#!/bin/bash
# scripts/analyze-images.sh
# Purpose: Analyze current Docker image sizes and identify optimization opportunities
# Author: DevOps Team
# Date: 2025-12-03
# Usage: ./scripts/analyze-images.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Output file
REPORT_FILE="reports/image-analysis-$(date +%Y%m%d-%H%M%S).txt"
CSV_FILE="reports/image-sizes.csv"

# Create reports directory
mkdir -p reports

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Docker Image Analysis Report                    ║${NC}"
echo -e "${BLUE}║        Phase 2A - Module 1                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to convert bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    fi
}

# Start report
{
    echo "Docker Image Analysis Report"
    echo "Generated: $(date)"
    echo "=============================================="
    echo ""
} > "$REPORT_FILE"

# Initialize CSV
echo "Service,Image,Size (MB),Layers,Base Image,Created,Optimization Potential" > "$CSV_FILE"

# Services to analyze
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

echo -e "${CYAN}Analyzing images...${NC}"
echo ""

TOTAL_SIZE=0
TOTAL_LAYERS=0

# Table header
printf "${YELLOW}%-25s %-15s %-10s %-15s${NC}\n" "SERVICE" "SIZE" "LAYERS" "BASE IMAGE"
echo "--------------------------------------------------------------------------------"

for service in "${SERVICES[@]}"; do
    IMAGE="microservices-k8s-project-${service}"
    
    if docker images --format "{{.Repository}}" | grep -q "^${IMAGE}$"; then
        # Get image details
        SIZE=$(docker images --format "{{.Size}}" "$IMAGE:latest" | head -1)
        SIZE_BYTES=$(docker inspect "$IMAGE:latest" --format='{{.Size}}' 2>/dev/null || echo 0)
        LAYERS=$(docker history "$IMAGE:latest" --no-trunc --format "{{.ID}}" | grep -v "missing" | wc -l)
        BASE_IMAGE=$(docker inspect "$IMAGE:latest" --format='{{index .Config.Image}}' 2>/dev/null || echo "unknown")
        CREATED=$(docker inspect "$IMAGE:latest" --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1)
        
        # Calculate optimization potential
        SIZE_MB=$(awk "BEGIN {printf \"%.0f\", $SIZE_BYTES / 1048576}")
        if [ "$SIZE_MB" -gt 500 ]; then
            OPTIMIZATION="High (>500MB)"
            OPT_COLOR=$RED
        elif [ "$SIZE_MB" -gt 200 ]; then
            OPTIMIZATION="Medium (>200MB)"
            OPT_COLOR=$YELLOW
        else
            OPTIMIZATION="Low (<200MB)"
            OPT_COLOR=$GREEN
        fi
        
        # Display
        printf "${OPT_COLOR}%-25s %-15s %-10s %-15s${NC}\n" "$service" "$SIZE" "$LAYERS" "${BASE_IMAGE:0:15}..."
        
        # Add to report
        {
            echo "Service: $service"
            echo "  Image: $IMAGE:latest"
            echo "  Size: $SIZE ($SIZE_BYTES bytes)"
            echo "  Layers: $LAYERS"
            echo "  Base Image: $BASE_IMAGE"
            echo "  Created: $CREATED"
            echo "  Optimization Potential: $OPTIMIZATION"
            echo ""
        } >> "$REPORT_FILE"
        
        # Add to CSV
        echo "$service,$IMAGE:latest,$SIZE_MB,$LAYERS,$BASE_IMAGE,$CREATED,$OPTIMIZATION" >> "$CSV_FILE"
        
        # Totals
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))
        TOTAL_LAYERS=$((TOTAL_LAYERS + LAYERS))
    else
        echo -e "${RED}✗ Image not found: $IMAGE${NC}"
    fi
done

echo ""
echo "--------------------------------------------------------------------------------"

# Summary
TOTAL_SIZE_HUMAN=$(bytes_to_human $TOTAL_SIZE)
AVG_SIZE=$((TOTAL_SIZE / ${#SERVICES[@]}))
AVG_SIZE_HUMAN=$(bytes_to_human $AVG_SIZE)
AVG_LAYERS=$((TOTAL_LAYERS / ${#SERVICES[@]}))

echo -e "${BLUE}Summary:${NC}"
echo -e "  Total Images: ${GREEN}${#SERVICES[@]}${NC}"
echo -e "  Total Size: ${YELLOW}$TOTAL_SIZE_HUMAN${NC}"
echo -e "  Average Size: ${YELLOW}$AVG_SIZE_HUMAN${NC}"
echo -e "  Total Layers: ${YELLOW}$TOTAL_LAYERS${NC}"
echo -e "  Average Layers: ${YELLOW}$AVG_LAYERS${NC}"
echo ""

# Add summary to report
{
    echo "=============================================="
    echo "SUMMARY"
    echo "=============================================="
    echo "Total Images: ${#SERVICES[@]}"
    echo "Total Size: $TOTAL_SIZE_HUMAN ($TOTAL_SIZE bytes)"
    echo "Average Size: $AVG_SIZE_HUMAN"
    echo "Total Layers: $TOTAL_LAYERS"
    echo "Average Layers: $AVG_LAYERS"
    echo ""
} >> "$REPORT_FILE"

# Detailed layer analysis
echo -e "${CYAN}Detailed Layer Analysis:${NC}"
echo ""

for service in "${SERVICES[@]}"; do
    IMAGE="microservices-k8s-project-${service}"
    
    if docker images --format "{{.Repository}}" | grep -q "^${IMAGE}$"; then
        echo -e "${YELLOW}$service:${NC}"
        
        {
            echo "=============================================="
            echo "LAYER ANALYSIS: $service"
            echo "=============================================="
        } >> "$REPORT_FILE"
        
        docker history "$IMAGE:latest" --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}" | head -10 >> "$REPORT_FILE"
        docker history "$IMAGE:latest" --format "  {{.Size}}\t{{.CreatedBy}}" | head -5
        
        echo "" >> "$REPORT_FILE"
        echo ""
    fi
done

# Optimization recommendations
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Optimization Recommendations                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

{
    echo "=============================================="
    echo "OPTIMIZATION RECOMMENDATIONS"
    echo "=============================================="
    echo ""
} >> "$REPORT_FILE"

RECOMMENDATIONS=(
    "1. Use Alpine Linux base images (node:18-alpine vs node:18)"
    "2. Multi-stage builds to exclude build dependencies"
    "3. Combine RUN commands to reduce layers"
    "4. Use .dockerignore to exclude unnecessary files"
    "5. Clear package manager cache after installation"
    "6. Use specific package versions"
    "7. Minimize number of COPY/ADD instructions"
    "8. Order Dockerfile from least to most frequently changed"
)

for rec in "${RECOMMENDATIONS[@]}"; do
    echo -e "${GREEN}✓${NC} $rec"
    echo "$rec" >> "$REPORT_FILE"
done

echo ""
echo -e "${BLUE}Report saved to: ${YELLOW}$REPORT_FILE${NC}"
echo -e "${BLUE}CSV data saved to: ${YELLOW}$CSV_FILE${NC}"
echo ""

# Potential savings calculation
echo -e "${CYAN}Estimated Optimization Potential:${NC}"
OPTIMIZED_SIZE=$((TOTAL_SIZE / 2))  # Conservative 50% reduction
SAVINGS=$((TOTAL_SIZE - OPTIMIZED_SIZE))
SAVINGS_HUMAN=$(bytes_to_human $SAVINGS)
OPTIMIZED_SIZE_HUMAN=$(bytes_to_human $OPTIMIZED_SIZE)

echo -e "  Current Total: ${RED}$TOTAL_SIZE_HUMAN${NC}"
echo -e "  Expected After Optimization: ${GREEN}$OPTIMIZED_SIZE_HUMAN${NC}"
echo -e "  Potential Savings: ${YELLOW}$SAVINGS_HUMAN (50%)${NC}"
echo ""

{
    echo ""
    echo "=============================================="
    echo "OPTIMIZATION POTENTIAL"
    echo "=============================================="
    echo "Current Total Size: $TOTAL_SIZE_HUMAN"
    echo "Expected After Optimization: $OPTIMIZED_SIZE_HUMAN"
    echo "Potential Savings: $SAVINGS_HUMAN (50% reduction)"
    echo ""
    echo "Next Steps:"
    echo "1. Review Dockerfiles for each service"
    echo "2. Implement multi-stage builds"
    echo "3. Switch to Alpine base images"
    echo "4. Update .dockerignore files"
    echo "5. Run optimization build script"
    echo "6. Compare results with this baseline"
} >> "$REPORT_FILE"

echo -e "${GREEN}✓ Analysis complete!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Review the detailed report: cat $REPORT_FILE"
echo "  2. Run: ./scripts/optimize-dockerfiles.sh"
echo "  3. Rebuild images: ./scripts/build-optimized.sh"
echo "  4. Compare results: ./scripts/compare-sizes.sh"
echo ""