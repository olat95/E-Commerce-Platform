# ===== COMPARE SIZES SCRIPT =====
# scripts/compare-sizes.sh
#!/bin/bash
# Purpose: Compare original vs optimized image sizes
# Usage: ./scripts/compare-sizes.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPORT_FILE="reports/optimization-results-$(date +%Y%m%d-%H%M%S).txt"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Image Size Comparison Report                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

{
    echo "Image Size Comparison Report"
    echo "Generated: $(date)"
    echo "=============================================="
    echo ""
} > "$REPORT_FILE"

SERVICES=("auth-service" "user-service" "billing-service" "payment-service" "notification-service" "analytics-service" "admin-service" "frontend")

printf "${YELLOW}%-25s %-15s %-15s %-15s %-10s${NC}\n" "SERVICE" "ORIGINAL" "OPTIMIZED" "SAVINGS" "% REDUCTION"
echo "------------------------------------------------------------------------------------------------"

TOTAL_ORIGINAL=0
TOTAL_OPTIMIZED=0

for service in "${SERVICES[@]}"; do
    ORIGINAL_IMAGE="microservices-k8s-project-${service}:latest"
    OPTIMIZED_IMAGE="${service}:optimized"
    
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${ORIGINAL_IMAGE}$"; then
        ORIGINAL_SIZE=$(docker inspect "$ORIGINAL_IMAGE" --format='{{.Size}}' 2>/dev/null || echo 0)
    else
        ORIGINAL_SIZE=0
    fi
    
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${OPTIMIZED_IMAGE}$"; then
        OPTIMIZED_SIZE=$(docker inspect "$OPTIMIZED_IMAGE" --format='{{.Size}}' 2>/dev/null || echo 0)
    else
        OPTIMIZED_SIZE=0
    fi
    
    if [ "$ORIGINAL_SIZE" -gt 0 ] && [ "$OPTIMIZED_SIZE" -gt 0 ]; then
        SAVINGS=$((ORIGINAL_SIZE - OPTIMIZED_SIZE))
        REDUCTION=$((SAVINGS * 100 / ORIGINAL_SIZE))
        
        ORIGINAL_MB=$((ORIGINAL_SIZE / 1048576))
        OPTIMIZED_MB=$((OPTIMIZED_SIZE / 1048576))
        SAVINGS_MB=$((SAVINGS / 1048576))
        
        if [ "$REDUCTION" -ge 50 ]; then
            COLOR=$GREEN
        elif [ "$REDUCTION" -ge 30 ]; then
            COLOR=$YELLOW
        else
            COLOR=$RED
        fi
        
        printf "${COLOR}%-25s %-15s %-15s %-15s %-10s${NC}\n" \
            "$service" \
            "${ORIGINAL_MB}MB" \
            "${OPTIMIZED_MB}MB" \
            "${SAVINGS_MB}MB" \
            "${REDUCTION}%"
        
        {
            echo "Service: $service"
            echo "  Original: ${ORIGINAL_MB}MB"
            echo "  Optimized: ${OPTIMIZED_MB}MB"
            echo "  Savings: ${SAVINGS_MB}MB"
            echo "  Reduction: ${REDUCTION}%"
            echo ""
        } >> "$REPORT_FILE"
        
        TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + ORIGINAL_SIZE))
        TOTAL_OPTIMIZED=$((TOTAL_OPTIMIZED + OPTIMIZED_SIZE))
    else
        echo -e "${RED}✗ Comparison not available for $service${NC}"
    fi
done

echo "------------------------------------------------------------------------------------------------"

if [ "$TOTAL_ORIGINAL" -gt 0 ]; then
    TOTAL_SAVINGS=$((TOTAL_ORIGINAL - TOTAL_OPTIMIZED))
    TOTAL_REDUCTION=$((TOTAL_SAVINGS * 100 / TOTAL_ORIGINAL))
    
    TOTAL_ORIGINAL_MB=$((TOTAL_ORIGINAL / 1048576))
    TOTAL_OPTIMIZED_MB=$((TOTAL_OPTIMIZED / 1048576))
    TOTAL_SAVINGS_MB=$((TOTAL_SAVINGS / 1048576))
    
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  Original Total:  ${RED}${TOTAL_ORIGINAL_MB}MB${NC}"
    echo -e "  Optimized Total: ${GREEN}${TOTAL_OPTIMIZED_MB}MB${NC}"
    echo -e "  Total Savings:   ${YELLOW}${TOTAL_SAVINGS_MB}MB${NC}"
    echo -e "  Reduction:       ${GREEN}${TOTAL_REDUCTION}%${NC}"
    
    {
        echo "=============================================="
        echo "TOTAL SUMMARY"
        echo "=============================================="
        echo "Original Total: ${TOTAL_ORIGINAL_MB}MB"
        echo "Optimized Total: ${TOTAL_OPTIMIZED_MB}MB"
        echo "Total Savings: ${TOTAL_SAVINGS_MB}MB"
        echo "Total Reduction: ${TOTAL_REDUCTION}%"
    } >> "$REPORT_FILE"
    
    if [ "$TOTAL_REDUCTION" -ge 50 ]; then
        echo ""
        echo -e "${GREEN}✓ EXCELLENT! Achieved >50% reduction!${NC}"
    elif [ "$TOTAL_REDUCTION" -ge 30 ]; then
        echo ""
        echo -e "${YELLOW}⚠ GOOD! Achieved 30-50% reduction. Consider further optimization.${NC}"
    else
        echo ""
        echo -e "${RED}✗ WARNING! Less than 30% reduction. Review optimization techniques.${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Report saved to: ${YELLOW}$REPORT_FILE${NC}"
echo ""