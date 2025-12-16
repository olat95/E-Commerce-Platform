#!/bin/bash
# scripts/build-optimized.sh
# Purpose: Build all optimized Docker images
# Usage: ./scripts/build-optimized.sh

set -e

# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Building Optimized Docker Images                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

SERVICES=("auth-service" "user-service" "billing-service" "payment-service" "notification-service" "analytics-service" "admin-service" "frontend")

START_TIME=$(date +%s)

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building $service...${NC}"
    
    SERVICE_START=$(date +%s)
    
    docker build \
        -t "${service}:optimized" \
        -f "${PROJECT_ROOT}/services/${service}/Dockerfile" \
        "${PROJECT_ROOT}/services/${service}/" \
        --no-cache
    
    SERVICE_END=$(date +%s)
    SERVICE_TIME=$((SERVICE_END - SERVICE_START))
    
    echo -e "${GREEN}✓ $service built in ${SERVICE_TIME}s${NC}"
    echo ""
done

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo -e "${GREEN}✓ All images built successfully!${NC}"
echo -e "${BLUE}Total build time: ${TOTAL_TIME}s${NC}"
echo ""