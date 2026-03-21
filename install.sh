#!/bin/bash
#===============================================================================
# GUARDIAN v2.0 - Safe Installation Script
#===============================================================================
# Installs Guardian with USER SOVEREIGNTY protections.
#
# CRITICAL SAFETY FEATURES:
# 1. User files are NEVER protected
# 2. Emergency override installed FIRST
# 3. Recovery instructions created OUTSIDE protected area
# 4. User confirmation before protecting anything
#
# Usage: curl -sSL <repo-url>/install.sh | bash
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#===============================================================================
# USER SOVEREIGNTY CHECK
#===============================================================================

USER_SOVEREIGN_PATTERNS=(
    ".bashrc"
    ".bash_aliases"
    ".bash_profile"
    ".bash_logout"
    ".profile"
    ".zshrc"
    ".zprofile"
    ".zshenv"
    ".zlogin"
    ".ssh"
    ".gnupg"
)

check_user_sovereignty() {
    local file="$1"
    for pattern in "${USER_SOVEREIGN_PATTERNS[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            return 0  # File is user sovereign
        fi
    done
    return 1
}

#===============================================================================
# MAIN INSTALLATION
#===============================================================================

main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        GUARDIAN v2.0 - Safe Installation                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    #---------------------------------------------------------------------------
    # Detect OS
    #---------------------------------------------------------------------------
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${GREEN}✓ Detected Linux${NC}"
        OS="linux"
        LOCK_CMD="chattr +i"
        UNLOCK_CMD="chattr -i"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}⚠ Detected macOS - using chflags instead of chattr${NC}"
        OS="macos"
        LOCK_CMD="chflags schg"
        UNLOCK_CMD="chflags noschg"
    else
        echo -e "${RED}✗ Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
    
    #---------------------------------------------------------------------------
    # STEP 0: CRITICAL - Unlock any user files first
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 0] Ensuring user sovereignty...${NC}"
    
    USER_FILES=(
        "$HOME/.bashrc"
        "$HOME/.bash_aliases"
        "$HOME/.bash_profile"
        "$HOME/.bash_logout"
        "$HOME/.profile"
        "$HOME/.zshrc"
        "$HOME/.zprofile"
        "$HOME/.zshenv"
        "$HOME/.zlogin"
    )
    
    for f in "${USER_FILES[@]}"; do
        if [ -f "$f" ]; then
            if [ "$OS" == "linux" ]; then
                /usr/bin/sudo chattr -i "$f" 2>/dev/null || true
            else
                /usr/bin/sudo chflags noschg "$f" 2>/dev/null || true
            fi
            echo -e "  ${GREEN}✓ User file unlocked: $f${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ User sovereignty ensured${NC}"
    
    #---------------------------------------------------------------------------
    # STEP 1: Create directories
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 1] Creating directories...${NC}"
    
    mkdir -p "$HOME/.guardrails"
    mkdir -p "$HOME/.guardrails/bin"
    mkdir -p "$HOME/.guardrails/approval_queue"
    mkdir -p "$HOME/.guardrails/logs"
    mkdir -p "$HOME/.guardrails/backups"
    mkdir -p "$HOME/.guardian-angel/monitored_builds"
    mkdir -p "$HOME/.guardian-angel/reports"
    
    echo -e "${GREEN}✓ Directories created${NC}"
    
    #---------------------------------------------------------------------------
    # STEP 2: Install EMERGENCY OVERRIDE FIRST
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 2] Installing emergency override (CRITICAL SAFETY)...${NC}"
    
    # Create emergency script in /usr/bin (system path, always accessible)
    /usr/bin/sudo tee /usr/bin/guardian-emergency > /dev/null << 'EMERGENCY_SCRIPT'
#!/bin/bash
#===============================================================================
# GUARDIAN EMERGENCY OVERRIDE - ALWAYS WORKS
#===============================================================================
# This command is installed in /usr/bin/ so it works even if:
# - ~/.guardrails is corrupted
# - PATH is broken
# - User is locked out of their own files
#
# Uses /usr/bin/sudo directly to bypass any Guardian wrappers.
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case "${1:-}" in
    unlock-all)
        echo -e "${YELLOW}Unlocking all protected files...${NC}"
        
        # Unlock agent files
        for f in "$HOME/.qwen/settings.json" "$HOME/.qwen/config.json" "$HOME/.qwen/QWEN.md"; do
            if [ -f "$f" ]; then
                /usr/bin/sudo chattr -i "$f" 2>/dev/null && \
                    echo -e "${GREEN}  ✓ Unlocked: $f${NC}" || true
            fi
        done
        
        # Unlock guardian files
        for f in "$HOME/.guardrails/guardian" "$HOME/.guardrails/bin/sudo" \
                 "$HOME/.guardrails/guardian-nlp.py" "$HOME/.guardrails/unlock-tracker.py"; do
            if [ -f "$f" ]; then
                /usr/bin/sudo chattr -i "$f" 2>/dev/null && \
                    echo -e "${GREEN}  ✓ Unlocked: $f${NC}" || true
            fi
        done
        
        # CRITICAL: Also unlock any user files that might have been accidentally protected
        for f in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.bash_profile" \
                 "$HOME/.profile" "$HOME/.zshrc" "$HOME/.zprofile"; do
            if [ -f "$f" ]; then
                attrs=$(/usr/bin/lsattr -d "$f" 2>/dev/null | cut -d' ' -f1 || echo "")
                if echo "$attrs" | grep -q 'i'; then
                    /usr/bin/sudo chattr -i "$f" 2>/dev/null && \
                        echo -e "${GREEN}  ✓ RECOVERED user file: $f${NC}" || true
                fi
            fi
        done
        
        echo ""
        echo -e "${GREEN}✅ All files unlocked${NC}"
        ;;
        
    disable)
        echo -e "${RED}Disabling Guardian entirely...${NC}"
        
        /usr/bin/guardian-emergency unlock-all
        
        # Remove bash hooks
        if [ -f "$HOME/.bashrc" ]; then
            /usr/bin/sudo chattr -i "$HOME/.bashrc" 2>/dev/null || true
            sed -i '/guardrails\/bash_hooks/d' "$HOME/.bashrc" 2>/dev/null || true
            sed -i '/Guardian bash hooks/d' "$HOME/.bashrc" 2>/dev/null || true
            sed -i '/Guardian sudo wrapper/d' "$HOME/.bashrc" 2>/dev/null || true
        fi
        
        echo ""
        echo -e "${GREEN}✅ Guardian disabled${NC}"
        echo -e "${YELLOW}Run 'guardian init' to re-enable${NC}"
        ;;
        
    status)
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}             GUARDIAN STATUS CHECK                         ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        echo -e "${BLUE}Protected Files:${NC}"
        for f in "$HOME/.qwen/settings.json" "$HOME/.qwen/config.json"; do
            if [ -f "$f" ]; then
                attrs=$(/usr/bin/lsattr -d "$f" 2>/dev/null | cut -d' ' -f1 || echo "----")
                if echo "$attrs" | grep -q 'i'; then
                    echo -e "  🔒 LOCKED:   $f"
                else
                    echo -e "  🔓 UNLOCKED: $f"
                fi
            fi
        done
        
        echo ""
        echo -e "${BLUE}User Sovereignty Check:${NC}"
        for f in "$HOME/.bashrc" "$HOME/.profile"; do
            if [ -f "$f" ]; then
                attrs=$(/usr/bin/lsattr -d "$f" 2>/dev/null | cut -d' ' -f1 || echo "----")
                if echo "$attrs" | grep -q 'i'; then
                    echo -e "  ${RED}⚠ LOCKED (should not be!): $f${NC}"
                else
                    echo -e "  ${GREEN}✓ User editable: $f${NC}"
                fi
            fi
        done
        ;;
        
    recover-user-files)
        echo -e "${YELLOW}Recovering all user files...${NC}"
        
        USER_FILES=(
            "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.bash_profile"
            "$HOME/.bash_logout" "$HOME/.profile" "$HOME/.zshrc"
            "$HOME/.zprofile" "$HOME/.zshenv" "$HOME/.zlogin"
        )
        
        for f in "${USER_FILES[@]}"; do
            if [ -f "$f" ]; then
                /usr/bin/sudo chattr -i "$f" 2>/dev/null && \
                    echo -e "${GREEN}  ✓ Recovered: $f${NC}" || true
            fi
        done
        
        echo ""
        echo -e "${GREEN}✅ All user files should now be editable${NC}"
        ;;
        
    *)
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║        GUARDIAN EMERGENCY OVERRIDE                       ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Usage: guardian-emergency <command>"
        echo ""
        echo "Commands:"
        echo "  unlock-all         Unlock all protected files"
        echo "  disable            Disable Guardian entirely"
        echo "  status             Check protection status"
        echo "  recover-user-files Force unlock user shell configs"
        echo ""
        echo -e "${GREEN}This command ALWAYS works for the human user.${NC}"
        echo ""
        ;;
esac
EMERGENCY_SCRIPT
    
    /usr/bin/sudo chmod +x /usr/bin/guardian-emergency
    echo -e "${GREEN}✓ Emergency override installed: /usr/bin/guardian-emergency${NC}"
    
    #---------------------------------------------------------------------------
    # STEP 3: Create recovery instructions FIRST
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 3] Creating recovery instructions...${NC}"
    
    RECOVERY_FILE="$HOME/GUARDIAN_RECOVERY_INSTRUCTIONS.txt"
    
    cat > "$RECOVERY_FILE" << 'RECOVERY_EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    GUARDIAN EMERGENCY RECOVERY                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝

⚠️  IF YOU ARE LOCKED OUT OF YOUR OWN FILES, READ THIS ⚠️

═══════════════════════════════════════════════════════════════════════════════
QUICK FIXES
═══════════════════════════════════════════════════════════════════════════════

OPTION 1: Emergency Override Command
─────────────────────────────────────
    guardian-emergency unlock-all

OPTION 2: Recover User Files Only
──────────────────────────────────
    guardian-emergency recover-user-files

OPTION 3: Disable Guardian Entirely
───────────────────────────────────
    guardian-emergency disable

OPTION 4: Manual Override (if above don't work)
───────────────────────────────────────────────
    /usr/bin/sudo chattr -i ~/.qwen/settings.json
    /usr/bin/sudo chattr -i ~/.qwen/config.json
    /usr/bin/sudo chattr -i ~/.guardrails/*

OPTION 5: Recovery from Live USB (last resort)
──────────────────────────────────────────────
1. Boot from a Linux Live USB
2. Mount your drive: sudo mount /dev/sda1 /mnt
3. Unlock files: sudo chattr -i /mnt/home/YOURUSER/.qwen/*
4. Reboot normally

═══════════════════════════════════════════════════════════════════════════════
WHAT GUARDIAN PROTECTS
═══════════════════════════════════════════════════════════════════════════════

Protected (need approval):
    • ~/.qwen/settings.json   - AI agent configuration
    • ~/.qwen/config.json     - AI agent API credentials
    • ~/.qwen/QWEN.md         - AI agent guidelines
    • ~/.guardrails/*         - Guardian system files

NOT Protected (you can always edit):
    • ~/.bashrc, ~/.profile, ~/.zshrc
    • ~/.ssh, ~/.gnupg
    • Everything else

═══════════════════════════════════════════════════════════════════════════════
THIS FILE
═══════════════════════════════════════════════════════════════════════════════

This file is NEVER protected. You can always read and edit it.
Keep it for emergencies.
═══════════════════════════════════════════════════════════════════════════════
RECOVERY_EOF
    
    # Ensure recovery file is NOT protected
    /usr/bin/sudo chattr -i "$RECOVERY_FILE" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Recovery instructions: $RECOVERY_FILE${NC}"
    
    #---------------------------------------------------------------------------
    # STEP 4: Get script directory and install files
    #---------------------------------------------------------------------------
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    echo ""
    echo -e "${BLUE}[STEP 4] Installing Guardian files...${NC}"
    
    # Install guardian core
    if [ -f "$SCRIPT_DIR/src/guardian" ]; then
        cp "$SCRIPT_DIR/src/guardian" "$HOME/.guardrails/guardian"
        chmod +x "$HOME/.guardrails/guardian"
        ln -sf "$HOME/.guardrails/guardian" /usr/local/bin/guardian 2>/dev/null || \
            /usr/bin/sudo ln -sf "$HOME/.guardrails/guardian" /usr/local/bin/guardian
        echo -e "${GREEN}  ✓ guardian${NC}"
    fi
    
    # Install bash hooks
    if [ -f "$SCRIPT_DIR/src/bash_hooks.sh" ]; then
        cp "$SCRIPT_DIR/src/bash_hooks.sh" "$HOME/.guardrails/bash_hooks.sh"
        chmod +x "$HOME/.guardrails/bash_hooks.sh"
        echo -e "${GREEN}  ✓ bash_hooks.sh${NC}"
    fi
    
    # Install sudo wrapper
    if [ -f "$SCRIPT_DIR/src/bin/sudo" ]; then
        cp "$SCRIPT_DIR/src/bin/sudo" "$HOME/.guardrails/bin/sudo"
        chmod +x "$HOME/.guardrails/bin/sudo"
        echo -e "${GREEN}  ✓ sudo wrapper${NC}"
    fi
    
    # Install other scripts
    for script in guardian-nlp.py guardian-encrypt.sh guardian-decrypt.sh \
                  guardian-scan-keys.sh guardian-angel.py guardian-test.sh \
                  unlock-tracker.py; do
        if [ -f "$SCRIPT_DIR/src/$script" ]; then
            cp "$SCRIPT_DIR/src/$script" "$HOME/.guardrails/$script"
            chmod +x "$HOME/.guardrails/$script"
            echo -e "${GREEN}  ✓ $script${NC}"
        fi
    done
    
    #---------------------------------------------------------------------------
    # STEP 5: Configure bashrc
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 5] Configuring bashrc...${NC}"
    
    # Ensure .bashrc is unlocked
    /usr/bin/sudo chattr -i "$HOME/.bashrc" 2>/dev/null || true
    
    # Add PATH
    if ! grep -q ".guardrails/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "\n# Guardian Firewall PATH\nexport PATH=\"\$HOME/.guardrails/bin:\$PATH\"" >> "$HOME/.bashrc"
        echo -e "${GREEN}  ✓ PATH configured${NC}"
    fi
    
    # Add bash hooks source
    if ! grep -q ".guardrails/bash_hooks" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "\n# Guardian bash hooks\nsource \"\$HOME/.guardrails/bash_hooks.sh\"" >> "$HOME/.bashrc"
        echo -e "${GREEN}  ✓ Bash hooks configured${NC}"
    fi
    
    #---------------------------------------------------------------------------
    # STEP 6: USER CONFIRMATION before protecting files
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  PROTECTION PREVIEW${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}The following files WILL be protected from AI agents:${NC}"
    echo "  • ~/.qwen/settings.json"
    echo "  • ~/.qwen/config.json"
    echo "  • ~/.qwen/QWEN.md (if exists)"
    echo ""
    echo -e "${GREEN}The following files will NEVER be protected:${NC}"
    echo "  • ~/.bashrc, ~/.profile, ~/.zshrc"
    echo "  • ~/.ssh, ~/.gnupg"
    echo "  • All other user files"
    echo ""
    echo -e "${CYAN}Emergency override available:${NC}"
    echo "  • guardian-emergency unlock-all"
    echo "  • ~/GUARDIAN_RECOVERY_INSTRUCTIONS.txt"
    echo ""
    
    read -p "Proceed with protection? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo ""
        echo -e "${YELLOW}Installation completed without file protection.${NC}"
        echo -e "${YELLOW}Run 'guardian init' to enable protection later.${NC}"
        exit 0
    fi
    
    #---------------------------------------------------------------------------
    # STEP 7: Protect files (only agent files, NEVER user files)
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 6] Protecting agent files...${NC}"
    
    # Agent files to protect
    AGENT_FILES=(
        "$HOME/.qwen/settings.json"
        "$HOME/.qwen/config.json"
        "$HOME/.qwen/QWEN.md"
    )
    
    for file in "${AGENT_FILES[@]}"; do
        if [ -f "$file" ]; then
            # SAFETY CHECK: Verify file is NOT user sovereign
            if check_user_sovereignty "$file"; then
                echo -e "${RED}  ⚠ SKIPPED (user sovereign): $file${NC}"
                continue
            fi
            
            if [ "$OS" == "linux" ]; then
                /usr/bin/sudo chattr +i "$file" 2>/dev/null && \
                    echo -e "${GREEN}  ✓ Protected: $file${NC}" || \
                    echo -e "${YELLOW}  ⚠ Could not protect: $file${NC}"
            else
                /usr/bin/sudo chflags schg "$file" 2>/dev/null && \
                    echo -e "${GREEN}  ✓ Protected: $file${NC}" || \
                    echo -e "${YELLOW}  ⚠ Could not protect: $file${NC}"
            fi
        fi
    done
    
    #---------------------------------------------------------------------------
    # STEP 8: Setup cron for unlock tracking
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${BLUE}[STEP 7] Setting up unlock tracking...${NC}"
    
    if command -v crontab &> /dev/null; then
        if ! crontab -l 2>/dev/null | grep -q "unlock-tracker"; then
            (crontab -l 2>/dev/null; echo "* * * * * python3 \$HOME/.guardrails/unlock-tracker.py check 2>/dev/null") | crontab -
            echo -e "${GREEN}  ✓ Cron job added${NC}"
        fi
    fi
    
    #---------------------------------------------------------------------------
    # COMPLETE
    #---------------------------------------------------------------------------
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        ✅ GUARDIAN v2.0 Installed Successfully           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Installed Components:${NC}"
    echo "  🔐 Guardian Firewall (core protection)"
    echo "  📝 Natural Language Approval"
    echo "  🔒 Guardian Encryption"
    echo "  🔍 API Key Scanner"
    echo "  👼 Guardian Angel (security monitoring)"
    echo ""
    
    echo -e "${CYAN}Emergency Features:${NC}"
    echo "  • guardian-emergency unlock-all"
    echo "  • guardian-emergency status"
    echo "  • ~/GUARDIAN_RECOVERY_INSTRUCTIONS.txt"
    echo ""
    
    echo -e "${GREEN}User Sovereignty:${NC}"
    echo "  User files (.bashrc, .profile, etc.) are NEVER protected."
    echo "  The human user ALWAYS has final control."
    echo ""
    
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Restart terminal: source ~/.bashrc"
    echo "  2. Check status: guardian status"
    echo "  3. Test emergency: guardian-emergency status"
    echo ""
    
    # Source bashrc
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
}

# Run main
main "$@"
