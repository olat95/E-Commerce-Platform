# ===== GENERATE SECURITY REPORT SCRIPT =====
# scripts/generate-security-report.sh
#!/bin/bash
# Purpose: Generate comprehensive HTML security report for all images
# Usage: ./scripts/generate-security-report.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="reports/security"
HTML_REPORT="$REPORT_DIR/security-report-$TIMESTAMP.html"

mkdir -p "$REPORT_DIR"

echo -e "${BLUE}Generating comprehensive security report...${NC}"

# HTML Header
cat > "$HTML_REPORT" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Scan Report - Microservices Platform</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric {
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .metric-critical {
            background-color: #fee;
            border-left: 4px solid #e74c3c;
        }
        .metric-high {
            background-color: #fff3cd;
            border-left: 4px solid #f39c12;
        }
        .metric-medium {
            background-color: #d1ecf1;
            border-left: 4px solid #3498db;
        }
        .metric-low {
            background-color: #d4edda;
            border-left: 4px solid #27ae60;
        }
        .metric-value {
            font-size: 36px;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            font-size: 14px;
            color: #7f8c8d;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .status-clean {
            color: #27ae60;
            font-weight: bold;
        }
        .status-warning {
            color: #f39c12;
            font-weight: bold;
        }
        .status-critical {
            color: #e74c3c;
            font-weight: bold;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            color: #7f8c8d;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 Security Scan Report</h1>
        <p><strong>Generated:</strong> TIMESTAMP_PLACEHOLDER</p>
        <p><strong>Project:</strong> Microservices on Kubernetes</p>
        
        <h2>Executive Summary</h2>
        <div class="summary">
            <div class="metric metric-critical">
                <div class="metric-label">Critical</div>
                <div class="metric-value">CRITICAL_COUNT</div>
            </div>
            <div class="metric metric-high">
                <div class="metric-label">High</div>
                <div class="metric-value">HIGH_COUNT</div>
            </div>
            <div class="metric metric-medium">
                <div class="metric-label">Medium</div>
                <div class="metric-value">MEDIUM_COUNT</div>
            </div>
            <div class="metric metric-low">
                <div class="metric-label">Low</div>
                <div class="metric-value">LOW_COUNT</div>
            </div>
        </div>
        
        <h2>Image Scan Results</h2>
        <table>
            <thead>
                <tr>
                    <th>Service</th>
                    <th>Status</th>
                    <th>Critical</th>
                    <th>High</th>
                    <th>Medium</th>
                    <th>Low</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>
                TABLE_ROWS_PLACEHOLDER
            </tbody>
        </table>
        
        <div class="footer">
            <p>Scanned with Trivy | Phase 2A Security Module</p>
            <p>For detailed vulnerability information, see individual scan reports</p>
        </div>
    </div>
</body>
</html>
EOF

# Scan all images and collect data
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

TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0
TABLE_ROWS=""

for image in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$image" | cut -d: -f1)
    
    echo -e "${YELLOW}Scanning $image...${NC}"
    
    # Scan and get JSON output
    SCAN_DATA=$(trivy image --format json --severity CRITICAL,HIGH,MEDIUM,LOW "$image" 2>/dev/null || echo '{}')
    
    if [ -n "$SCAN_DATA" ] && [ "$SCAN_DATA" != "{}" ]; then
        CRITICAL=$(echo "$SCAN_DATA" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' 2>/dev/null || echo 0)
        HIGH=$(echo "$SCAN_DATA" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' 2>/dev/null || echo 0)
        MEDIUM=$(echo "$SCAN_DATA" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' 2>/dev/null || echo 0)
        LOW=$(echo "$SCAN_DATA" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' 2>/dev/null || echo 0)
        
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))
        TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + MEDIUM))
        TOTAL_LOW=$((TOTAL_LOW + LOW))
        
        TOTAL_VULNS=$((CRITICAL + HIGH + MEDIUM + LOW))
        
        if [ "$TOTAL_VULNS" -eq 0 ]; then
            STATUS="<span class='status-clean'>✓ Clean</span>"
        elif [ "$CRITICAL" -gt 0 ]; then
            STATUS="<span class='status-critical'>✗ Critical</span>"
        elif [ "$HIGH" -gt 0 ]; then
            STATUS="<span class='status-warning'>⚠ Warning</span>"
        else
            STATUS="<span class='status-clean'>✓ Acceptable</span>"
        fi
        
        TABLE_ROWS="${TABLE_ROWS}<tr><td>${SERVICE_NAME}</td><td>${STATUS}</td><td>${CRITICAL}</td><td>${HIGH}</td><td>${MEDIUM}</td><td>${LOW}</td><td>${TOTAL_VULNS}</td></tr>"
    fi
done

# Replace placeholders
sed -i "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$HTML_REPORT"
sed -i "s/CRITICAL_COUNT/$TOTAL_CRITICAL/" "$HTML_REPORT"
sed -i "s/HIGH_COUNT/$TOTAL_HIGH/" "$HTML_REPORT"
sed -i "s/MEDIUM_COUNT/$TOTAL_MEDIUM/" "$HTML_REPORT"
sed -i "s/LOW_COUNT/$TOTAL_LOW/" "$HTML_REPORT"
sed -i "s|TABLE_ROWS_PLACEHOLDER|$TABLE_ROWS|" "$HTML_REPORT"

echo -e "${GREEN}✓ Security report generated!${NC}"
echo -e "${BLUE}Report location: ${YELLOW}$HTML_REPORT${NC}"
echo ""
echo -e "${CYAN}Open in browser:${NC}"
echo "  file://$PWD/$HTML_REPORT"
echo ""