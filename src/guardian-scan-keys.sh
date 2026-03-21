#!/bin/bash
#===============================================================================
# GUARDIAN API KEY SCANNER - Detect Exposed API Keys
#===============================================================================
# Scans codebase for hardcoded API keys before encryption
# Forces agents to use environment variables instead
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: guardian-scan-keys <directory>"
    echo "Example: guardian-scan-keys ~/my-project/"
    exit 1
fi

TARGET="$1"

if [ ! -d "$TARGET" ]; then
    echo -e "${RED}❌ Directory not found: $TARGET${NC}"
    exit 1
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        GUARDIAN API Key Scanner - Security Check         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

FOUND_KEYS=0
SCAN_REPORT="$TARGET/.guardian_key_scan.md"

# API Key patterns to detect
declare -A PATTERNS=(
    ["AWS Access Key"]="AKIA[0-9A-Z]{16}"
    ["AWS Secret Key"]="[A-Za-z0-9/+=]{40}"
    ["GitHub Token"]="gh[pousr]_[A-Za-z0-9_]{36,}"
    ["GitLab Token"]="glpat-[A-Za-z0-9-]{20,}"
    ["Slack Token"]="xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24}"
    ["Stripe Key"]="sk_live_[0-9a-zA-Z]{24,}"
    ["Stripe Publishable"]="pk_live_[0-9a-zA-Z]{24,}"
    ["Google API Key"]="AIza[0-9A-Za-z_-]{35}"
    ["OpenAI Key"]="sk-[0-9a-zA-Z]{20,}"
    ["DeepSeek Key"]="sk-[0-9a-f]{32}"
    ["API Key Assignment"]="api_key\s*=\s*['\"][^'\"]{16,}['\"]"
    ["API Key Assignment 2"]="apikey\s*=\s*['\"][^'\"]{16,}['\"]"
    ["API Key in String"]="['\"]api[_-]?key['\"]\s*[:=]\s*['\"][^'\"]{16,}['\"]"
    ["Generic Secret"]="secret[_-]?key\s*=\s*['\"][^'\"]{8,}['\"]"
    ["Password in Config"]="password\s*=\s*['\"][^'\"]{6,}['\"]"
    ["Bearer Token"]="[Bb]earer\s+[a-zA-Z0-9\-_\.]{20,}"
    ["Private Key"]="-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
)

echo -e "${BLUE}[*] Scanning for exposed API keys and secrets...${NC}"
echo ""

# Create report header
cat > "$SCAN_REPORT" << HEADER
# GUARDIAN API Key Scan Report

**Scanned:** $(date '+%Y-%m-%d %H:%M:%S')  
**Directory:** $TARGET  
**Status:** $(if [ $FOUND_KEYS -eq 0 ]; then echo "✅ CLEAN"; else echo "🚨 KEYS FOUND"; fi)

---

## Findings

HEADER

# Scan files
while IFS= read -r -d '' file; do
    # Skip scan report itself and common non-code files
    [[ "$file" == *".guardian_key_scan.md" ]] && continue
    [[ "$file" == *"node_modules/"* ]] && continue
    [[ "$file" == *".git/"* ]] && continue
    [[ "$file" == *"__pycache__/"* ]] && continue
    
    for key_name in "${!PATTERNS[@]}"; do
        pattern="${PATTERNS[$key_name]}"
        
        # Search for pattern
        if grep -qE "$pattern" "$file" 2>/dev/null; then
            FOUND_KEYS=$((FOUND_KEYS + 1))
            
            # Get line numbers
            LINES=$(grep -nE "$pattern" "$file" 2>/dev/null | head -5)
            
            echo -e "  ${RED}🚨 FOUND:${NC} $key_name in $file"
            
            # Add to report
            cat >> "$SCAN_REPORT" << FINDING
### 🚨 $key_name

**File:** \`$file\`

**Lines:**
\`\`\`
$LINES
\`\`\`

**Remediation:**
1. Remove this key immediately from version control
2. Move to environment variable: \`export $key_name="your-key"\`
3. Use secrets manager (AWS Secrets Manager, HashiCorp Vault, etc.)
4. Add file to .gitignore if contains secrets

---

FINDING
        fi
    done
done < <(find "$TARGET" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.env" -o -name "*.conf" -o -name "*.config" -o -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null)

echo ""

if [ $FOUND_KEYS -gt 0 ]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              🚨 SECURITY RISK DETECTED 🚨                ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Found $FOUND_KEYS potential API key(s) or secret(s)${NC}"
    echo ""
    echo -e "${BLUE}REMEDIATION REQUIRED:${NC}"
    echo ""
    echo "1. Remove exposed keys from code"
    echo "2. Move to environment variables:"
    echo "   export API_KEY=\"your-key-here\""
    echo "3. Use .env file (add to .gitignore):"
    echo "   API_KEY=your-key-here"
    echo "4. Use secrets manager for production"
    echo ""
    echo -e "${YELLOW}Report saved to: $SCAN_REPORT${NC}"
    echo ""
    
    # Update report status
    sed -i "s/\*\*Status:\*\*.*/\*\*Status:\*\* 🚨 $FOUND_KEYS KEYS FOUND/" "$SCAN_REPORT"
    
    echo -e "${RED}❌ GUARDIAN ENCRYPTION BLOCKED${NC}"
    echo "   Fix security issues before encrypting"
    exit 1
else
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✅ NO EXPOSED KEYS FOUND                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ Codebase is clean - safe to encrypt${NC}"
    echo ""
    
    # Update report status
    sed -i "s/\*\*Status:\*\*.*/\*\*Status:\*\* ✅ CLEAN/" "$SCAN_REPORT"
    
    echo -e "${BLUE}Report saved to: $SCAN_REPORT${NC}"
    exit 0
fi
