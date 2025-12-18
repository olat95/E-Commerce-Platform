#!/bin/bash
# scripts/scan-images.sh
# Purpose: Automated security scanning of all Docker images using Trivy
# Author: DevOps Team
# Usage: ./scripts/scan-images.sh [--severity CRITICAL,HIGH] [--format json|table|html]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default settings
SEVERITY="${1:-CRITICAL,HIGH,MEDIUM}"
FORMAT="${2:-table}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="reports/security"
SUMMARY_FILE="$REPORT_DIR/scan-summary-$TIMESTAMP.txt"

# Create report directory
mkdir -p "$REPORT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Security Vulnerability Scanning                 ║${NC}"
echo -e "${BLUE}║        Trivy Scanner - All Images                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Scan Configuration:${NC}"
echo -e "  Severity Levels: ${YELLOW}$SEVERITY${NC}"
echo -e "  Output Format: ${YELLOW}$FORMAT${NC}"
echo -e "  Report Directory: ${YELLOW}$REPORT_DIR${NC}"
echo ""

# Initialize summary
{
    echo "Security Scan Summary Report"
    echo "Generated: $(date)"
    echo "Severity Filter: $SEVERITY"
    echo "=============================================="
    echo ""
} > "$SUMMARY_FILE"

# Services to scan
SERVICES=(
    "auth-service:optimized"
    "user-service:optimized"
    "billing-service:optimized"
    "payment-service:optimized"
    "notification-service:optimized"
    "analytics-service:optimized"
    "admin-service:optimized"
    "frontend:optimized"
)

# Counters
TOTAL_IMAGES=0
CRITICAL_FOUND=0
HIGH_FOUND=0
MEDIUM_FOUND=0
LOW_FOUND=0
CLEAN_IMAGES=0

# Scan each image
for image in "${SERVICES[@]}"; do
    TOTAL_IMAGES=$((TOTAL_IMAGES + 1))
    SERVICE_NAME=$(echo "$image" | cut -d: -f1)
    
    echo -e "${CYAN}Scanning: ${YELLOW}$image${NC}"
    
    # Table format output
    if [ "$FORMAT" = "table" ]; then
        trivy image \
            --severity "$SEVERITY" \
            --no-progress \
            "$image" | tee "$REPORT_DIR/${SERVICE_NAME}-scan-$TIMESTAMP.txt"
    fi
    
    # JSON format output
    if [ "$FORMAT" = "json" ]; then
        trivy image \
            --format json \
            --severity "$SEVERITY" \
            --output "$REPORT_DIR/${SERVICE_NAME}-scan-$TIMESTAMP.json" \
            "$image"
        
        echo -e "${GREEN}✓ JSON report saved${NC}"
    fi
    
    # HTML format output
    if [ "$FORMAT" = "html" ]; then
        trivy image \
            --format template \
            --template "@contrib/html.tpl" \
            --severity "$SEVERITY" \
            --output "$REPORT_DIR/${SERVICE_NAME}-scan-$TIMESTAMP.html" \
            "$image"
        
        echo -e "${GREEN}✓ HTML report saved${NC}"
    fi
    
    # Get vulnerability counts
    SCAN_OUTPUT=$(trivy image --format json --severity "$SEVERITY" "$image" 2>/dev/null || echo '{}')
    
    if [ -n "$SCAN_OUTPUT" ] && [ "$SCAN_OUTPUT" != "{}" ]; then
        CRITICAL=$(echo "$SCAN_OUTPUT" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' 2>/dev/null || echo 0)
        HIGH=$(echo "$SCAN_OUTPUT" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' 2>/dev/null || echo 0)
        MEDIUM=$(echo "$SCAN_OUTPUT" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' 2>/dev/null || echo 0)
        LOW=$(echo "$SCAN_OUTPUT" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' 2>/dev/null || echo 0)
        
        CRITICAL_FOUND=$((CRITICAL_FOUND + CRITICAL))
        HIGH_FOUND=$((HIGH_FOUND + HIGH))
        MEDIUM_FOUND=$((MEDIUM_FOUND + MEDIUM))
        LOW_FOUND=$((LOW_FOUND + LOW))
        
        TOTAL_VULNS=$((CRITICAL + HIGH + MEDIUM + LOW))
        
        if [ "$TOTAL_VULNS" -eq 0 ]; then
            echo -e "${GREEN}✓ No vulnerabilities found!${NC}"
            CLEAN_IMAGES=$((CLEAN_IMAGES + 1))
            STATUS="CLEAN"
            COLOR=$GREEN
        elif [ "$CRITICAL" -gt 0 ]; then
            echo -e "${RED}✗ CRITICAL: $CRITICAL | HIGH: $HIGH | MEDIUM: $MEDIUM | LOW: $LOW${NC}"
            STATUS="CRITICAL"
            COLOR=$RED
        elif [ "$HIGH" -gt 0 ]; then
            echo -e "${YELLOW}⚠ HIGH: $HIGH | MEDIUM: $MEDIUM | LOW: $LOW${NC}"
            STATUS="WARNING"
            COLOR=$YELLOW
        else
            echo -e "${GREEN}✓ MEDIUM: $MEDIUM | LOW: $LOW${NC}"
            STATUS="ACCEPTABLE"
            COLOR=$GREEN
        fi
        
        # Add to summary
        {
            echo "Image: $image"
            echo "  Status: $STATUS"
            echo "  Critical: $CRITICAL"
            echo "  High: $HIGH"
            echo "  Medium: $MEDIUM"
            echo "  Low: $LOW"
            echo "  Total: $TOTAL_VULNS"
            echo ""
        } >> "$SUMMARY_FILE"
    else
        echo -e "${GREEN}✓ Scan completed - No vulnerabilities${NC}"
        CLEAN_IMAGES=$((CLEAN_IMAGES + 1))
    fi
    
    echo ""
done

# Final summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Scan Summary                                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Images Scanned: ${GREEN}$TOTAL_IMAGES${NC}"
echo -e "${CYAN}Clean Images: ${GREEN}$CLEAN_IMAGES${NC}"
echo ""
echo -e "${RED}Critical Vulnerabilities: $CRITICAL_FOUND${NC}"
echo -e "${YELLOW}High Vulnerabilities: $HIGH_FOUND${NC}"
echo -e "${CYAN}Medium Vulnerabilities: $MEDIUM_FOUND${NC}"
echo -e "${GREEN}Low Vulnerabilities: $LOW_FOUND${NC}"
echo ""

# Write summary totals
{
    echo "=============================================="
    echo "TOTAL SUMMARY"
    echo "=============================================="
    echo "Images Scanned: $TOTAL_IMAGES"
    echo "Clean Images: $CLEAN_IMAGES"
    echo "Critical: $CRITICAL_FOUND"
    echo "High: $HIGH_FOUND"
    echo "Medium: $MEDIUM_FOUND"
    echo "Low: $LOW_FOUND"
    echo ""
} >> "$SUMMARY_FILE"

# Security status
if [ "$CRITICAL_FOUND" -gt 0 ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  SECURITY ALERT: CRITICAL VULNERABILITIES FOUND   ║${NC}"
    echo -e "${RED}║  Action Required: Fix immediately before deployment   ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    EXIT_CODE=1
elif [ "$HIGH_FOUND" -gt 0 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  WARNING: HIGH SEVERITY VULNERABILITIES FOUND     ║${NC}"
    echo -e "${YELLOW}║  Action Required: Fix within 7 days                   ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    EXIT_CODE=0
else
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ SECURITY CHECK PASSED                              ║${NC}"
    echo -e "${GREEN}║  No critical or high severity vulnerabilities         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    EXIT_CODE=0
fi

echo ""
echo -e "${CYAN}Reports Location:${NC}"
echo -e "  Summary: ${YELLOW}$SUMMARY_FILE${NC}"
echo -e "  Details: ${YELLOW}$REPORT_DIR/${NC}"
echo ""

# Recommendations
echo -e "${CYAN}Next Steps:${NC}"
if [ "$CRITICAL_FOUND" -gt 0 ] || [ "$HIGH_FOUND" -gt 0 ]; then
    echo "  1. Review detailed reports in $REPORT_DIR"
    echo "  2. Update base images: docker pull node:18-alpine"
    echo "  3. Update dependencies: npm update"
    echo "  4. Rebuild images: ./scripts/build-optimized.sh"
    echo "  5. Rescan: ./scripts/scan-images.sh"
else
    echo "  1. Review scan summary: cat $SUMMARY_FILE"
    echo "  2. Fix medium/low issues when convenient"
    echo "  3. Proceed to image tagging: ./scripts/tag-images.sh"
fi
echo ""

exit $EXIT_CODE