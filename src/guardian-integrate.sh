#!/bin/bash
#===============================================================================
# GUARDIAN Integration Script for Skill Files
# Automatically protects your skill's source code
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
    echo -e "${RED}❌ Usage: $0 <skill-directory>${NC}"
    echo ""
    echo "Example: $0 ~/.qwen/skills/my-skill"
    exit 1
fi

SKILL_DIR="$1"

# Verify directory exists
if [ ! -d "$SKILL_DIR" ]; then
    echo -e "${RED}❌ Directory not found: $SKILL_DIR${NC}"
    exit 1
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     GUARDIAN Integration - Skill Protection              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Find all relevant files
echo -e "${BLUE}[*] Finding files to protect...${NC}"

FILES_TO_PROTECT=()

# Python files
while IFS= read -r -d '' file; do
    FILES_TO_PROTECT+=("$file")
    echo "  Found: $file"
done < <(find "$SKILL_DIR" -name "*.py" -type f -print0 2>/dev/null)

# Shell scripts
while IFS= read -r -d '' file; do
    FILES_TO_PROTECT+=("$file")
    echo "  Found: $file"
done < <(find "$SKILL_DIR" -name "*.sh" -type f -print0 2>/dev/null)

# JSON configs
while IFS= read -r -d '' file; do
    FILES_TO_PROTECT+=("$file")
    echo "  Found: $file"
done < <(find "$SKILL_DIR" -name "*.json" -type f -print0 2>/dev/null)

# Markdown docs
while IFS= read -r -d '' file; do
    FILES_TO_PROTECT+=("$file")
    echo "  Found: $file"
done < <(find "$SKILL_DIR" -name "*.md" -type f -print0 2>/dev/null)

if [ ${#FILES_TO_PROTECT[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No files found to protect${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}[*] Locking ${#FILES_TO_PROTECT[@]} files...${NC}"

# Lock each file
for file in "${FILES_TO_PROTECT[@]}"; do
    sudo chattr +i "$file" 2>/dev/null && \
        echo -e "  ${GREEN}✓ LOCKED:${NC} $file" || \
        echo -e "  ${YELLOW}⚠️  FAILED:${NC} $file"
done

echo ""
echo -e "${GREEN}✅ GUARDIAN Integration Complete!${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  ${#FILES_TO_PROTECT[@]} files now PROTECTED${NC}"
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

# Create skill-specific documentation
SKILL_NAME=$(basename "$SKILL_DIR")
DOC_FILE="$SKILL_DIR/GUARDIAN_INFO.md"

cat > "$DOC_FILE" << EOF
# GUARDIAN Protection - $SKILL_NAME

## Protected Files

This skill's source code is protected by the GUARDIAN system.

**Protected:**
$(printf '  - %s\n' "${FILES_TO_PROTECT[@]}")

## For Agents

You CANNOT edit these files directly. To request changes:

\`\`\`bash
guardian-request <filename> '<detailed reason>'
\`\`\`

**Example:**
\`\`\`bash
guardian-request main.py 'Add error handling for API timeout'
\`\`\`

## For Users

**Approve requests:**
\`\`\`bash
guardian-approve <request_id>
\`\`\`

**Temporarily unlock:**
\`\`\`bash
guardian-temp-unlock <filename> [seconds]
\`\`\`

**View pending:**
\`\`\`bash
guardian-pending
\`\`\`

---
*Protected by GUARDIAN on $(date '+%Y-%m-%d %H:%M:%S')*
EOF

echo -e "${GREEN}✓ Created: $DOC_FILE${NC}"
echo ""
