# ===== LIST TAGS SCRIPT =====
# scripts/list-tags.sh
#!/bin/bash
# Purpose: List all Docker image tags in organized format
# Usage: ./scripts/list-tags.sh [service-name]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE=${1:-all}

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

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Docker Image Tags                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$SERVICE" != "all" ]; then
    SERVICES=("$SERVICE")
fi

for service in "${SERVICES[@]}"; do
    echo -e "${CYAN}${service}:${NC}"
    
    # Check if images exist
    if ! docker images "$service" --format "{{.Repository}}" | grep -q "^${service}$"; then
        echo -e "${YELLOW}  No images found${NC}"
        echo ""
        continue
    fi
    
    # Version tags
    echo -e "${GREEN}  Version tags:${NC}"
    docker images "$service" --format "    {{.Tag}}" | grep "^v[0-9]" | sort -V || echo "    None"
    
    # Environment tags
    echo -e "${GREEN}  Environment tags:${NC}"
    docker images "$service" --format "    {{.Tag}}" | grep -E "^(development|staging|production)$" || echo "    None"
    
    # Other tags
    echo -e "${GREEN}  Other tags:${NC}"
    docker images "$service" --format "    {{.Tag}}" | grep -vE "^(v[0-9]|development|staging|production|<none>)" || echo "    None"
    
    echo ""
done