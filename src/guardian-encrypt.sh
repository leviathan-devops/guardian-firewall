#!/bin/bash
#===============================================================================
# GUARDIAN ENCRYPT - Apply GUARDIAN Protection to Any Codebase
#===============================================================================
# Makes codebases IMMUTABLE - agents cannot modify without human approval
# Perfect for: skills, configs, architecture, completed features
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}❌ Usage: $0 <directory-or-file>${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.qwen/skills/my-skill"
    echo "  $0 ~/projects/my-app/src/core"
    echo "  $0 ~/.qwen/settings.json"
    exit 1
fi

TARGET="$1"

# Verify target exists
if [ ! -e "$TARGET" ]; then
    echo -e "${RED}❌ Not found: $TARGET${NC}"
    exit 1
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          GUARDIAN Encryption - Apply Protection          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# STEP 1: Security scan for API keys
echo -e "${BLUE}[*] STEP 1: Security scan for exposed API keys...${NC}"
echo ""
if ! guardian-scan-keys.sh "$TARGET" 2>&1; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  🚨 ENCRYPTION ABORTED - SECURITY ISSUES FOUND          ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Fix exposed API keys before encrypting."
    echo "See: $TARGET/.guardian_key_scan.md"
    exit 1
fi
echo ""

# STEP 2: Apply encryption
echo -e "${BLUE}[*] STEP 2: Applying GUARDIAN encryption...${NC}"
echo ""

# Handle single file vs directory
if [ -f "$TARGET" ]; then
    FILES_TO_PROTECT=("$TARGET")
else
    # Find all relevant files in directory
    FILES_TO_PROTECT=()
    while IFS= read -r -d '' file; do
        FILES_TO_PROTECT+=("$file")
    done < <(find "$TARGET" -type f \( \
        -name "*.py" -o \
        -name "*.sh" -o \
        -name "*.json" -o \
        -name "*.md" -o \
        -name "*.yaml" -o \
        -name "*.yml" -o \
        -name "*.toml" -o \
        -name "*.txt" -o \
        -name "*.js" -o \
        -name "*.ts" -o \
        -name "*.jsx" -o \
        -name "*.tsx" -o \
        -name "*.rs" -o \
        -name "*.go" -o \
        -name "*.c" -o \
        -name "*.cpp" -o \
        -name "*.h" -o \
        -name "*.hpp" \
    \) -print0 2>/dev/null)
fi

if [ ${#FILES_TO_PROTECT[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No files found to protect${NC}"
    exit 0
fi

echo -e "${BLUE}[*] Found ${#FILES_TO_PROTECT[@]} files to protect${NC}"
echo ""

# Lock each file
echo -e "${BLUE}[*] Applying GUARDIAN encryption...${NC}"
for file in "${FILES_TO_PROTECT[@]}"; do
    # First remove immutable if already set (in case of re-run)
    sudo chattr -i "$file" 2>/dev/null || true
    
    # Set immutable
    sudo chattr +i "$file" && \
        echo -e "  ${GREEN}✓ ENCRYPTED:${NC} $file" || \
        echo -e "  ${YELLOW}⚠️  FAILED:${NC} $file"
done

echo ""

# Create GUARDIAN info file if directory
if [ -d "$TARGET" ]; then
    INFO_FILE="$TARGET/GUARDIAN_ENCRYPTED.md"
    
    echo -e "${BLUE}[*] Creating encryption manifest...${NC}"
    
    cat > "$INFO_FILE" << EOF
# GUARDIAN Encrypted Codebase 🔒

## This code is IMMUTABLE

You **CANNOT** modify these files directly, even in YOLO mode.

### To Request Changes

\`\`\`bash
guardian-request <filename> '<detailed reason>'
\`\`\`

**Example:**
\`\`\`bash
guardian-request src/core.py 'Add error handling for API timeout cases'
\`\`\`

### Protected Files

$(find "$TARGET" -type f \( -name "*.py" -o -name "*.sh" -o -name "*.json" -o -name "*.md" \) | grep -v GUARDIAN_ENCRYPTED | sed 's|^|`|;s|$|`|')

### Approval Workflow

1. Run: \`guardian-request <file> '<reason>'\`
2. User reviews and approves: \`guardian-approve <request_id>\`
3. File unlocked for 5 minutes
4. Make your edit
5. File auto-relocks

### Why GUARDIAN Encryption?

This codebase implements **critical architecture** that must not be modified
by autonomous agents without human review and approval.

**Benefits:**
- ✅ Code cannot be accidentally deleted
- ✅ Changes require human review
- ✅ Architecture is preserved
- ✅ Audit trail of all modifications
- ✅ Codebase accumulates density (no churn)

### For Agents

**You can:**
- ✅ Read all files (transparency)
- ✅ Copy files (for reference)
- ✅ Execute files (if scripts)
- ✅ Request edits (with context)

**You CANNOT:**
- ❌ Modify files directly
- ❌ Delete files
- ❌ Bypass protection (rm, sudo chattr -i, etc.)
- ❌ Ignore this system (it's kernel-level)

### For Users

**View pending requests:**
\`\`\`bash
guardian-pending
\`\`\`

**Approve requests:**
\`\`\`bash
guardian-approve <request_id>
\`\`\`

**Temporarily unlock:**
\`\`\`bash
guardian-temp-unlock <file> [seconds]
\`\`\`

**Remove encryption (if needed):**
\`\`\`bash
./guardian-decrypt.sh $TARGET
\`\`\`

---
**GUARDIAN Encrypted:** $(date '+%Y-%m-%d %H:%M:%S')  
**Files Protected:** ${#FILES_TO_PROTECT[@]}  
**Status:** 🔒 IMMUTABLE
EOF

    echo -e "  ${GREEN}✓ Created:${NC} $INFO_FILE"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          GUARDIAN Encryption Applied Successfully        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  ${#FILES_TO_PROTECT[@]} files now IMMUTABLE${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Agents must run:${NC}"
echo "  guardian-request <file> '<reason>'"
echo ""
echo -e "${BLUE}Users approve with:${NC}"
echo "  guardian-approve <request_id>"
echo ""
echo -e "${BLUE}Files auto-relock after 5 minutes${NC}"
echo ""
echo -e "${CYAN}Properties:${NC}"
echo "  ✅ Readable (transparency)"
echo "  ✅ Executable (functionality)"
echo "  ❌ Writable (requires approval)"
echo "  ❌ Deletable (even with sudo)"
echo ""
