# GUARDIAN Integration Template for Skill Files

## Copy-Paste This Into Every Skill File

---

## Quick Integration (3 Steps)

### Step 1: Add Protected Files List
Add this to your skill's documentation:

```markdown
## Protected Files

This skill uses GUARDIAN protection. The following files are IMMUTABLE:

- `<YOUR_SKILL_FILE>.py` - Main skill logic
- `<YOUR_SKILL_FILE>.sh` - Shell wrappers
- `skill.json` - Skill configuration
- Any config files in `~/.qwen/skills/<your-skill>/`

**Agents CANNOT modify these files directly.**

To request edits: `guardian-request <filename> '<reason>'`
```

### Step 2: Add Guardian Init to Your Setup Script
Add this to your skill's install/setup script:

```bash
#!/bin/bash
# Add to your skill's install.sh or setup.sh

# Lock skill files with GUARDIAN
echo "🔒 Locking skill files with GUARDIAN..."

# Lock your skill's source files
sudo chattr +i /path/to/your/skill/*.py
sudo chattr +i /path/to/your/skill/*.sh
sudo chattr +i /path/to/your/skill/skill.json

# Add to GUARDIAN protected list (edit guardian script)
echo "Adding skill files to GUARDIAN protection list..."

echo "✅ Skill files protected by GUARDIAN"
echo "   To edit: guardian-request <file> '<reason>'"
```

### Step 3: Add Agent Instructions
Add this to your skill's README:

```markdown
## Editing This Skill

**GUARDIAN Protection Active** 🔒

This skill's source code is protected by the GUARDIAN system.

### For Agents

You CANNOT directly edit skill files. To request changes:

```bash
guardian-request <skill-file> '<detailed reason>'
```

**Example:**
```bash
guardian-request my-skill.py 'Need to add error handling for API timeout cases'
```

**Workflow:**
1. Run `guardian-request` with specific reason
2. User reviews and approves with `guardian-approve <id>`
3. File unlocked for 5 minutes
4. Make your edit
5. File auto-relocks

### For Users

**View pending requests:**
```bash
guardian-pending
```

**Approve a request:**
```bash
guardian-approve <request_id>
```

**Temporarily unlock for manual edit:**
```bash
guardian-temp-unlock <skill-file> [seconds]
```

**Check protection status:**
```bash
guardian status
```
```

---

## Full Context Prompt for Agents

**Copy this entire section into your skill files:**

```markdown
═══════════════════════════════════════════════════════════════════════════
GUARDIAN PROTECTION SYSTEM - INTEGRATED
═══════════════════════════════════════════════════════════════════════════

This skill is protected by the GUARDIAN system. You CANNOT modify skill
files directly, even in YOLO mode.

PROTECTED FILES:
- All .py files in this skill directory
- All .sh files in this skill directory
- skill.json configuration
- Any .md documentation files
- Any config files

ATTEMPTING TO EDIT WITHOUT APPROVAL WILL FAIL:
❌ rm <file>              → "Operation not permitted"
❌ echo > <file>          → "GUARDIAN: Cannot write to protected file"
❌ sudo chattr -i <file>  → "GUARDIAN: Dangerous command detected"
❌ cp <src> <file>        → "GUARDIAN: Cannot overwrite protected file"
❌ python edit <file>     → "GUARDIAN: Cannot modify protected file"

TO REQUEST EDITS:

1. Identify what you need to change and WHY
   - Be specific about the change
   - Explain the benefit/necessity
   - Include context (what problem you're solving)

2. Run guardian-request:
   ```bash
   guardian-request <filename> '<detailed reason>'
   ```

3. Wait for user approval:
   - User runs: guardian-approve <request_id>
   - File unlocked for 5 minutes
   - Make your edit
   - File auto-relocks

4. If urgent, explain to user why approval is needed

EXAMPLE REQUESTS:

Good:
  guardian-request my-skill.py 'Add try/except around API calls to handle
  network failures gracefully. Currently unhandled exceptions crash the skill.'

Bad:
  guardian-request my-skill.py 'fix stuff'  ← Too vague, will be denied

Good:
  guardian-request skill.json 'Update API endpoint from v1 to v2 - v1 is
  deprecated and will be shut down next week.'

Bad:
  guardian-request skill.json 'update config'  ← What config? Why?

APPROVAL PROCESS:

1. Your request creates a pending approval with unique ID
2. User sees: file, agent, reason, timestamp
3. User must type "yes" to approve (interactive confirmation)
4. File unlocked for exactly 5 minutes
5. Make your edit
6. File auto-relocks (no manual action needed)

VIEW PENDING REQUESTS:
  guardian-pending

CHECK STATUS:
  guardian status

VIEW HISTORY:
  guardian-log 20

EMERGENCY (USER ONLY):
  guardian-temp-unlock <file> 600  # Unlock for 10 minutes

WHY THIS EXISTS:

1. Prevents accidental breaks by autonomous agents
2. Requires human review of skill changes
3. Creates audit trail of all modifications
4. Protects against hallucinated "fixes"
5. Ensures context is preserved

═══════════════════════════════════════════════════════════════════════════
```

---

## Automated Guardian Integration Script

**Create this file: `guardian-integrate.sh`**

```bash
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
```

**Usage:**
```bash
chmod +x guardian-integrate.sh
./guardian-integrate.sh ~/.qwen/skills/your-skill-name
```

---

## Add to Skill's `__init__.py` or Main File

**Add this docstring at the top:**

```python
"""
═══════════════════════════════════════════════════════════════════════════
GUARDIAN PROTECTED SKILL
═══════════════════════════════════════════════════════════════════════════

This skill's source code is IMMUTABLE. You CANNOT modify it directly.

TO EDIT THIS SKILL:

1. Run: guardian-request <this-file> '<detailed reason>'
2. User approves: guardian-approve <request_id>
3. File unlocked for 5 minutes
4. Make your edit
5. File auto-relocks

ATTEMPTING DIRECT EDITS WILL FAIL:
- rm, cp, mv, echo >, cat >, tee: BLOCKED
- sudo chattr -i: BLOCKED
- Python file writes: BLOCKED

This protection prevents accidental breaks by autonomous agents.

═══════════════════════════════════════════════════════════════════════════
"""
```

---

## Add to skill.json

**Add this field:**

```json
{
  "name": "your-skill",
  "version": "1.0.0",
  "guardian_protected": true,
  "guardian_info": "This skill is protected. Run: guardian-request <file> '<reason>'"
}
```

---

## Quick Reference Card

**Print this or keep it handy:**

```
╔══════════════════════════════════════════════════════════════════════════╗
║              GUARDIAN PROTECTION - QUICK REFERENCE                       ║
╚══════════════════════════════════════════════════════════════════════════╝

FOR AGENTS:
  Need to edit skill files?
  → guardian-request <file> '<reason>'
  → Wait for user approval
  → Edit within 5 minutes
  → Auto-relock

FOR USERS:
  See pending requests?
  → guardian-pending
  
  Want to approve?
  → guardian-approve <id>
  → Type "yes" when prompted
  
  Want to edit yourself?
  → guardian-temp-unlock <file> [seconds]

PROTECTED:
  ✓ Skill source code (.py, .sh)
  ✓ Configuration (skill.json)
  ✓ Documentation (.md)
  ✓ Config files

BLOCKED:
  ✗ rm, cp, mv, echo, cat, tee
  ✗ sudo chattr -i
  ✗ Python file writes
  ✗ Any direct modification

AUDIT:
  View history: guardian-log 20
  Check status: guardian status

═══════════════════════════════════════════════════════════════════════════
```

---

## Testing Your Integration

**After integrating GUARDIAN, test it:**

```bash
# Test 1: Try to delete skill file
rm ~/.qwen/skills/your-skill/main.py
# Expected: "Operation not permitted"

# Test 2: Try to overwrite
echo "# hacked" > ~/.qwen/skills/your-skill/main.py
# Expected: "GUARDIAN: Cannot write to protected file"

# Test 3: Request and approve
guardian-request ~/.qwen/skills/your-skill/main.py 'Testing protection'
guardian-pending
guardian-approve <request_id>
# Should unlock for 5 minutes
```

---

## Summary

**To protect any skill:**

1. **Run the integration script:**
   ```bash
   ./guardian-integrate.sh ~/.qwen/skills/your-skill
   ```

2. **Add the context prompt to your skill's main file** (docstring or header comment)

3. **Add GUARDIAN_INFO.md to your skill directory** (auto-created by script)

4. **Test the protection** (try to delete/modify files)

**Result:** Your skill's source code is now IMMUTABLE. Agents must request approval with context before any edits.

---

**Full GUARDIAN Documentation:** `~/GUARDIAN_DOCUMENTATION.md`  
**Quick Start:** `~/GUARDIAN_QUICKSTART.md`  
**Build Process:** `~/IDEA_TO_PRODUCT_BUILD_WORKFLOW.md`
