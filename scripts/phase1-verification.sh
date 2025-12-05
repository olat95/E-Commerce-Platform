#!/bin/bash
# phase1-verification.sh - Automated Phase 1 Verification

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Test result tracking
test_result() {
    TOTAL=$((TOTAL + 1))
    if [ $1 -eq 0 ]; then
        PASSED=$((PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC}: $2"
        return 0
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}✗ FAIL${NC}: $2"
        return 1
    fi
}

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Phase 1 Verification Test Suite         ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo ""

# ============================================================================
# Section 1: Container Status
# ============================================================================
echo -e "${YELLOW}[1/10] Checking Container Status...${NC}"

services=("auth-service" "user-service" "billing-service" "payment-service" "notification-service" "analytics-service" "admin-service" "frontend")
databases=("auth-db" "user-db" "billing-db" "payment-db" "analytics-db")

for service in "${services[@]}"; do
    docker-compose ps $service | grep -q "Up" 
    test_result $? "Container $service is running"
done

for db in "${databases[@]}"; do
    docker-compose ps $db | grep -q "Up"
    test_result $? "Database $db is running"
done

echo ""

# ============================================================================
# Section 2: Health Checks
# ============================================================================
echo -e "${YELLOW}[2/10] Testing Service Health Endpoints...${NC}"

health_ports=(8001 8002 8003 8004 8005 8006 8007)
health_names=("Auth" "User" "Billing" "Payment" "Notification" "Analytics" "Admin")

for i in "${!health_ports[@]}"; do
    port=${health_ports[$i]}
    name=${health_names[$i]}
    curl -sf http://localhost:$port/health > /dev/null 2>&1
    test_result $? "$name service health check"
done

echo ""

# ============================================================================
# Section 3: Database Readiness
# ============================================================================
echo -e "${YELLOW}[3/10] Testing Database Connections...${NC}"

ready_ports=(8001 8002 8003 8004 8006)
ready_names=("Auth" "User" "Billing" "Payment" "Analytics")

for i in "${!ready_ports[@]}"; do
    port=${ready_ports[$i]}
    name=${ready_names[$i]}
    response=$(curl -s http://localhost:$port/ready)
    echo "$response" | grep -q "ready"
    test_result $? "$name service database connection"
done

echo ""

# ============================================================================
# Section 4: Database Tables
# ============================================================================
echo -e "${YELLOW}[4/10] Verifying Database Tables...${NC}"

# Auth DB
docker-compose exec -T auth-db psql -U postgres -d auth_db -c "\dt" | grep -q "users"
test_result $? "Auth DB: users table exists"
docker-compose exec -T auth-db psql -U postgres -d auth_db -c "\dt" | grep -q "refresh_tokens"
test_result $? "Auth DB: refresh_tokens table exists"

# User DB
docker-compose exec -T user-db psql -U postgres -d user_db -c "\dt" | grep -q "profiles"
test_result $? "User DB: profiles table exists"

# Billing DB
docker-compose exec -T billing-db psql -U postgres -d billing_db -c "\dt" | grep -q "invoices"
test_result $? "Billing DB: invoices table exists"

# Payment DB
docker-compose exec -T payment-db psql -U postgres -d payment_db -c "\dt" | grep -q "payments"
test_result $? "Payment DB: payments table exists"

# Analytics DB
docker-compose exec -T analytics-db psql -U postgres -d analytics_db -c "\dt" | grep -q "events"
test_result $? "Analytics DB: events table exists"

echo ""

# ============================================================================
# Section 5: Frontend Accessibility
# ============================================================================
echo -e "${YELLOW}[5/10] Testing Frontend...${NC}"

curl -sf http://localhost:3000 > /dev/null 2>&1
test_result $? "Frontend is accessible on port 3000"

echo ""

# ============================================================================
# Section 6: User Registration
# ============================================================================
echo -e "${YELLOW}[6/10] Testing User Registration...${NC}"

TIMESTAMP=$(date +%s)
TEST_EMAIL="test${TIMESTAMP}@example.com"
TEST_PASSWORD="Test123!@#"

REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"role\": \"user\"
  }")

echo "$REGISTER_RESPONSE" | grep -q "accessToken"
test_result $? "User registration successful"

# Extract token
TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo "   Token extracted successfully"
    USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -1)
    echo "   User ID: $USER_ID"
else
    echo -e "${RED}   Failed to extract token${NC}"
fi

echo ""

# ============================================================================
# Section 7: User Login
# ============================================================================
echo -e "${YELLOW}[7/10] Testing User Login...${NC}"

LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }")

echo "$LOGIN_RESPONSE" | grep -q "accessToken"
test_result $? "User login successful"

echo ""

# ============================================================================
# Section 8: Token Validation
# ============================================================================
echo -e "${YELLOW}[8/10] Testing Token Validation...${NC}"

if [ -n "$TOKEN" ]; then
    VALIDATE_RESPONSE=$(curl -s -X POST http://localhost:8001/api/auth/validate \
      -H "Authorization: Bearer $TOKEN")
    
    echo "$VALIDATE_RESPONSE" | grep -q "valid"
    test_result $? "Token validation successful"
else
    echo -e "${RED}✗ SKIP: No token available for validation${NC}"
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
fi

echo ""

# ============================================================================
# Section 9: Create and Pay Invoice Flow
# ============================================================================
echo -e "${YELLOW}[9/10] Testing Invoice Creation and Payment...${NC}"

if [ -n "$TOKEN" ] && [ -n "$USER_ID" ]; then
    # Create invoice
    INVOICE_RESPONSE=$(curl -s -X POST http://localhost:8003/api/billing/invoices \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{
        \"userId\": $USER_ID,
        \"amount\": 99.99,
        \"items\": [{\"name\": \"Test Plan\", \"quantity\": 1, \"price\": 99.99}],
        \"description\": \"Test invoice\"
      }")
    
    echo "$INVOICE_RESPONSE" | grep -q "invoice"
    test_result $? "Invoice creation successful"
    
    INVOICE_ID=$(echo "$INVOICE_RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -1)
    
    if [ -n "$INVOICE_ID" ]; then
        echo "   Invoice ID: $INVOICE_ID"
        
        # Process payment
        PAYMENT_RESPONSE=$(curl -s -X POST http://localhost:8004/api/payments/process \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $TOKEN" \
          -d "{
            \"invoiceId\": $INVOICE_ID,
            \"method\": \"credit_card\",
            \"cardDetails\": {
              \"number\": \"4111111111111111\",
              \"cvv\": \"123\",
              \"expiry\": \"12/25\"
            }
          }")
        
        echo "$PAYMENT_RESPONSE" | grep -q "payment"
        test_result $? "Payment processing successful"
        
        # Check payment status
        PAYMENT_STATUS=$(echo "$PAYMENT_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$PAYMENT_STATUS" = "completed" ]; then
            echo "   Payment status: completed"
        else
            echo "   Payment status: $PAYMENT_STATUS (simulated failure)"
        fi
    fi
else
    echo -e "${RED}✗ SKIP: No token or user ID for invoice test${NC}"
    FAILED=$((FAILED + 2))
    TOTAL=$((TOTAL + 2))
fi

echo ""

# ============================================================================
# Section 10: Error Handling Tests
# ============================================================================
echo -e "${YELLOW}[10/10] Testing Error Handling...${NC}"

# Test invalid token
INVALID_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET http://localhost:8002/api/users/1 \
  -H "Authorization: Bearer invalid-token")
HTTP_CODE=$(echo "$INVALID_RESPONSE" | tail -n1)
[ "$HTTP_CODE" = "401" ]
test_result $? "Invalid token returns 401"

# Test missing token
NO_TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET http://localhost:8002/api/users/1)
HTTP_CODE=$(echo "$NO_TOKEN_RESPONSE" | tail -n1)
[ "$HTTP_CODE" = "401" ]
test_result $? "Missing token returns 401"

# Test non-existent resource
if [ -n "$TOKEN" ]; then
    NOT_FOUND_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET http://localhost:8003/api/billing/invoices/99999 \
      -H "Authorization: Bearer $TOKEN")
    HTTP_CODE=$(echo "$NOT_FOUND_RESPONSE" | tail -n1)
    [ "$HTTP_CODE" = "404" ]
    test_result $? "Non-existent resource returns 404"
fi

echo ""

# ============================================================================
# Final Results
# ============================================================================
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Test Results Summary             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Tests:  $TOTAL"
echo -e "${GREEN}Passed:       $PASSED${NC}"
echo -e "${RED}Failed:       $FAILED${NC}"
echo ""

# Calculate percentage
if [ $TOTAL -gt 0 ]; then
    PERCENTAGE=$((PASSED * 100 / TOTAL))
    echo -e "Success Rate: ${PERCENTAGE}%"
else
    PERCENTAGE=0
fi

echo ""

# Final verdict
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  🎉 CONGRATULATIONS! 🎉                    ║${NC}"
    echo -e "${GREEN}║  Phase 1 is COMPLETE!                     ║${NC}"
    echo -e "${GREEN}║  You're ready for Phase 2!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    exit 0
elif [ $PERCENTAGE -ge 85 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  ALMOST THERE! ⚠️                      ║${NC}"
    echo -e "${YELLOW}║  ${FAILED} tests failed. Review and fix.         ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
    exit 1
else
    echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ PHASE 1 INCOMPLETE ❌                  ║${NC}"
    echo -e "${RED}║  Please review failed tests above         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
    exit 1
fi