# ===== BUILD ALL SCRIPT =====
# scripts/build-all.sh
#!/bin/bash
# Purpose: Build all services with options for parallel builds
# Usage: ./scripts/build-all.sh [--parallel] [--no-cache]

set -e

PARALLEL=false
NO_CACHE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --parallel)
            PARALLEL=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--parallel] [--no-cache]"
            exit 1
            ;;
    esac
done

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Building All Services                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

SERVICES=("auth-service" "user-service" "billing-service" "payment-service" "notification-service" "analytics-service" "admin-service" "frontend")

build_service() {
    local service=$1
    echo -e "${YELLOW}Building $service...${NC}"
    
    docker build \
        -t "${service}:latest" \
        -f "services/${service}/Dockerfile" \
        $NO_CACHE \
        "services/${service}/" \
        > "reports/build-${service}.log" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service built successfully${NC}"
    else
        echo -e "${RED}✗ $service build failed${NC}"
        return 1
    fi
}

START_TIME=$(date +%s)

if [ "$PARALLEL" = true ]; then
    echo -e "${BLUE}Building services in parallel...${NC}"
    echo ""
    
    for service in "${SERVICES[@]}"; do
        build_service "$service" &
    done
    
    wait
else
    echo -e "${BLUE}Building services sequentially...${NC}"
    echo ""
    
    for service in "${SERVICES[@]}"; do
        build_service "$service"
    done
fi

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}✓ All services built!${NC}"
echo -e "${BLUE}Total time: ${TOTAL_TIME}s${NC}"
echo ""
echo -e "${YELLOW}Build logs saved to reports/build-*.log${NC}"