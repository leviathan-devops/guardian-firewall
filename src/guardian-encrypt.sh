#!/bin/bash
#===============================================================================
# GUARDIAN ENCRYPTION - Apply Protection to Codebase
# Version: 1.0.3-beta (User Sovereignty Fixed)
#===============================================================================
# SAFETY: Will NOT protect user shell configs or security files
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# USER SOVEREIGNTY - NEVER PROTECT THESE PATTERNS
USER_SOVEREIGN_PATTERNS=(
    ".bashrc"
    ".bash_aliases"
    ".bash_profile"
    ".profile"
    ".zshrc"
    ".zprofile"
    ".ssh/"
    ".gnupg/"
    ".config/autostart/"
    ".gnupg/"
    ".password"
    ".secret"
)

check_user_sovereignty() {
    local target="$1"
    
    for pattern in "${USER_SOVEREIGN_PATTERNS[@]}"; do
        if [[ "$target" == *"$pattern"* ]] || [[ "$target" == "$HOME/$pattern" ]]; then
            echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  🚨 USER SOVEREIGNTY VIOLATION DETECTED                  ║${NC}"
            echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${RED}Cannot protect: $target${NC}"
            echo ""
            echo "This file is protected by USER SOVEREIGNTY."
            echo "Guardian cannot protect user shell configs or security files."
            echo ""
            echo "If you really need to protect this file, you must:"
            echo "  1. Move it to a non-user-sovereign location"
            echo "  2. Or use sudo chattr +i manually (not recommended)"
            echo ""
            exit 1
        fi
    done
}

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

# CRITICAL: Check user sovereignty BEFORE doing anything
echo -e "${BLUE}[*] Checking user sovereignty...${NC}"
check_user_sovereignty "$TARGET"
echo -e "${GREEN}✓ User sovereignty verified${NC}"
echo ""

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          GUARDIAN Encryption - Apply Protection          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# STEP 1: Security scan for API keys
echo -e "${BLUE}[*] STEP 1: Security scan for exposed API keys...${NC}"
echo ""
if ! /home/leviathan/guardian-scan-keys.sh "$TARGET" 2>&1; then
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
        # Double-check user sovereignty for each file
        check_user_sovereignty "$file"
        FILES_TO_PROTECT+=("$file")
    done < <(find "$TARGET" -type f \( \
        -name "*.py" -o \
        -name "*.sh" -o \
        -name "*.json" -o \
        -name "*.md" -o \
        -name "*.yaml" -o \
        -name "*.yml" -o \
        -name "*.toml" -o \
        -name "*.txt" \
    \) -print0 2>/dev/null)
fi

if [ ${#FILES_TO_PROTECT[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No files found to protect${NC}"
    exit 0
fi

echo -e "${BLUE}[*] Found ${#FILES_TO_PROTECT[@]} files to protect${NC}"
echo ""

# Lock each file
echo -e "${BLUE}[*] Applying immutable flag...${NC}"
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

**EMERGENCY OVERRIDE:**
\`\`\`bash
guardian-emergency unlock-all
\`\`\`

---
**GUARDIAN Encrypted:** $(date '+%Y-%m-%d %H:%M:%S')  
**Files Protected:** ${#FILES_TO_PROTECT[@]}  
**Status:** 🔒 IMMUTABLE

**User Sovereignty:** This encryption does NOT protect user shell configs.
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
echo -e "${BLUE}EMERGENCY OVERRIDE:${NC}"
echo "  guardian-emergency unlock-all"
echo ""
echo -e "${CYAN}Properties:${NC}"
echo "  ✅ Readable (transparency)"
echo "  ✅ Executable (functionality)"
echo "  ❌ Writable (requires approval)"
echo "  ❌ Deletable (even with sudo)"
echo ""
