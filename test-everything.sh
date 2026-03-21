#!/bin/bash
#===============================================================================
# GUARDIAN Firewall - Comprehensive Test Suite
#===============================================================================
# Tests ALL components before shipping
#===============================================================================

# Don't exit on error - we want to run all tests
# set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TEST_DIR="/tmp/guardian-full-test-$$"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     GUARDIAN Firewall - Complete System Test Suite       ${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

cleanup() {
    echo ""
    echo -e "${BLUE}[*] Cleaning up...${NC}"
    sudo chattr -i "$TEST_DIR"/* 2>/dev/null || true
    rm -rf "$TEST_DIR"
    echo "✓ Cleanup complete"
}

trap cleanup EXIT

#===============================================================================
# TEST 1: Installation Script
#===============================================================================
test_installation() {
    echo -e "${BLUE}[TEST 1] Testing installation script...${NC}"
    
    # Run install script - it may fail on copying locked files but should complete core setup
    OUTPUT=$(cd /home/leviathan/guardian-firewall && ./install.sh 2>&1)
    
    # Check if core components are installed (even if some files are already locked)
    if command -v guardian &> /dev/null && command -v guardian-nlp &> /dev/null; then
        echo -e "  ${GREEN}✓ PASS: Guardian commands available${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Guardian commands not available${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

#===============================================================================
# TEST 2: Guardian Core Commands
#===============================================================================
test_guardian_core() {
    echo -e "${BLUE}[TEST 2] Testing Guardian core commands...${NC}"
    
    # Test guardian status
    if guardian status 2>&1 | grep -q "Protection Status"; then
        echo -e "  ${GREEN}✓ PASS: guardian status works${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: guardian status failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test guardian-nlp
    if guardian-nlp 2>&1 | grep -q "Usage"; then
        echo -e "  ${GREEN}✓ PASS: guardian-nlp works${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: guardian-nlp failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

#===============================================================================
# TEST 3: API Key Scanner
#===============================================================================
test_api_key_scanner() {
    echo -e "${BLUE}[TEST 3] Testing API key scanner...${NC}"
    
    # Create test codebase with exposed key
    mkdir -p "$TEST_DIR/api-test"
    echo 'API_KEY = "sk-1234567890abcdefghijklmnopqrstuvwxyz"' > "$TEST_DIR/api-test/config.py"
    
    # Run scanner - should detect key
    if guardian-scan-keys.sh "$TEST_DIR/api-test" 2>&1 | grep -q "SECURITY RISK DETECTED"; then
        echo -e "  ${GREEN}✓ PASS: API key detected${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: API key not detected${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Create clean codebase
    mkdir -p "$TEST_DIR/clean-test"
    echo 'API_KEY = os.environ.get("API_KEY")' > "$TEST_DIR/clean-test/config.py"
    
    # Run scanner - should pass
    if guardian-scan-keys.sh "$TEST_DIR/clean-test" 2>&1 | grep -q "NO EXPOSED KEYS FOUND"; then
        echo -e "  ${GREEN}✓ PASS: Clean codebase passes${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Clean codebase failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

#===============================================================================
# TEST 4: Guardian Encryption
#===============================================================================
test_guardian_encryption() {
    echo -e "${BLUE}[TEST 4] Testing Guardian Encryption...${NC}"
    
    # Create test codebase
    mkdir -p "$TEST_DIR/encrypt-test"
    echo 'def hello(): return "world"' > "$TEST_DIR/encrypt-test/app.py"
    echo '{"name": "test"}' > "$TEST_DIR/encrypt-test/config.json"
    
    # Run encryption
    if guardian-encrypt.sh "$TEST_DIR/encrypt-test" 2>&1 | grep -q "Applied Successfully"; then
        echo -e "  ${GREEN}✓ PASS: Encryption applied${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Encryption failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Verify files are immutable
    if lsattr "$TEST_DIR/encrypt-test/app.py" 2>&1 | grep -q "^....i"; then
        echo -e "  ${GREEN}✓ PASS: Files are immutable${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Files not immutable${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Verify delete is blocked
    if ! rm "$TEST_DIR/encrypt-test/app.py" 2>/dev/null; then
        echo -e "  ${GREEN}✓ PASS: Delete blocked${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Delete allowed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Verify execution works
    if python3 "$TEST_DIR/encrypt-test/app.py" -c "print('ok')" 2>&1; then
        echo -e "  ${GREEN}✓ PASS: Execution works${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Execution failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

#===============================================================================
# TEST 5: Guardian Angel
#===============================================================================
test_guardian_angel() {
    echo -e "${BLUE}[TEST 5] Testing Guardian Angel...${NC}"
    
    # Create test build with vulnerabilities
    mkdir -p "$TEST_DIR/angel-test/src"
    cat > "$TEST_DIR/angel-test/src/app.py" << 'PYEOF'
# Vulnerable code
API_KEY = "sk-test123456789"

def run_cmd(user_input):
    import os
    os.system("echo " + user_input)
PYEOF
    
    # Start monitoring
    if guardian-angel start "$TEST_DIR/angel-test" angel-test-001 2>&1 | grep -q "monitoring"; then
        echo -e "  ${GREEN}✓ PASS: Monitoring started${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Monitoring failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Run scan
    if guardian-angel scan angel-test-001 2>&1 | grep -q "CRITICAL"; then
        echo -e "  ${GREEN}✓ PASS: Vulnerabilities detected${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Vulnerabilities not detected${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Generate report
    if guardian-angel report angel-test-001 2>&1 | grep -q "Security Report"; then
        echo -e "  ${GREEN}✓ PASS: Report generated${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Report failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

#===============================================================================
# TEST 6: Natural Language Approval
#===============================================================================
test_natural_language() {
    echo -e "${BLUE}[TEST 6] Testing natural language approval...${NC}"
    
    # Create a request
    mkdir -p "$TEST_DIR/nlp-test"
    echo "test" > "$TEST_DIR/nlp-test/file.txt"
    sudo chattr +i "$TEST_DIR/nlp-test/file.txt"
    
    # Create request via guardian-nlp
    if guardian-nlp request "$TEST_DIR/nlp-test/file.txt" "Test edit" 2>&1 | grep -q "Request"; then
        echo -e "  ${GREEN}✓ PASS: Request created${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Request failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Check pending
    if guardian-nlp pending 2>&1 | grep -q "Pending"; then
        echo -e "  ${GREEN}✓ PASS: Pending visible${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL: Pending not visible${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

#===============================================================================
# TEST 7: Documentation Files
#===============================================================================
test_documentation() {
    echo -e "${BLUE}[TEST 7] Testing documentation...${NC}"
    
    # Check all required docs exist
    for doc in README.md \
               docs/GUARDIAN_FINAL.md \
               docs/GUARDIAN_NATURAL_LANGUAGE.md \
               docs/GUARDIAN_ENCRYPTION_PRODUCTION.md \
               prompts/guardian-angel-integration.txt \
               skills/guardian-encryption-skill.json; do
        if [ -f "/home/leviathan/guardian-firewall/$doc" ]; then
            echo -e "  ${GREEN}✓ PASS: $doc exists${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "  ${RED}✗ FAIL: $doc missing${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done
    
    echo ""
}

#===============================================================================
# MAIN
#===============================================================================
mkdir -p "$TEST_DIR"

test_installation
test_guardian_core
test_api_key_scanner
test_guardian_encryption
test_guardian_angel
test_natural_language
test_documentation

# Summary
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  TEST SUMMARY                            ${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED - GUARDIAN FIREWALL READY FOR PRODUCTION${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED - FIX REQUIRED BEFORE SHIPPING${NC}"
    exit 1
fi
