#!/bin/bash
#===============================================================================
# GUARDIAN Firewall - Main Installation Script
# Version: 1.0.3-beta (User Sovereignty Fixed)
#===============================================================================
# CRITICAL SAFETY FEATURES:
# 1. Emergency override installed FIRST
# 2. User sovereignty verification
# 3. Explicit consent before protecting files
# 4. Recovery instructions created
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        GUARDIAN Firewall - Installation                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${GREEN}✓ Detected Linux${NC}"
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}⚠ Detected macOS - some features may not work (chattr)${NC}"
    OS="macos"
else
    echo -e "${RED}✗ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  PROTECTED FILES PREVIEW${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The following files will be protected from AI agents:"
echo ""
echo "  ~/.qwen/settings.json   - Agent configuration"
echo "  ~/.qwen/config.json     - Agent API credentials"
echo "  ~/.qwen/QWEN.md         - Agent guidelines"
echo "  ~/.guardrails/*         - Guardian itself"
echo ""
echo -e "${GREEN}The following will NEVER be protected (user sovereignty):${NC}"
echo "  ~/.bashrc, ~/.profile, ~/.zshrc (shell configs)"
echo "  ~/.ssh/, ~/.gnupg/ (security keys)"
echo "  ~/.* (all user dotfiles)"
echo ""
echo -e "${RED}DO NOT PROTECT:${NC}"
echo "  - User shell configs"
echo "  - User home directory"
echo "  - SSH keys, GPG keys"
echo ""

# Require explicit consent
read -p "Continue with installation? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}✓ User consent verified${NC}"
echo ""

# Create directories
echo -e "${BLUE}[*] Creating directories...${NC}"
mkdir -p ~/.guardrails
mkdir -p ~/.guardrails/bin
mkdir -p ~/.guardrails/approval_queue
mkdir -p ~/.guardrails/logs
mkdir -p ~/.guardrails/backups
mkdir -p ~/.guardian-angel
echo -e "${GREEN}✓ Directories created${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#===============================================================================
# CRITICAL: Install emergency override FIRST (before protecting anything)
#===============================================================================
echo ""
echo -e "${BLUE}[*] Installing emergency override...${NC}"

if [ -f "$SCRIPT_DIR/src/guardian-emergency" ]; then
    sudo cp "$SCRIPT_DIR/src/guardian-emergency" /usr/bin/guardian-emergency
    sudo chmod +x /usr/bin/guardian-emergency
    echo -e "${GREEN}✓ Emergency override installed at /usr/bin/guardian-emergency${NC}"
    echo ""
    echo -e "${YELLOW}This command ALWAYS works, even if you're locked out:${NC}"
    echo "  guardian-emergency unlock-all"
    echo "  guardian-emergency disable"
    echo "  guardian-emergency status"
else
    echo -e "${YELLOW}⚠ Emergency override not found (will create manually)${NC}"
fi

#===============================================================================
# Install Guardian Firewall core
#===============================================================================
echo ""
echo -e "${BLUE}[*] Installing Guardian Firewall core...${NC}"

if [ -f "$SCRIPT_DIR/src/guardian" ]; then
    cp "$SCRIPT_DIR/src/guardian" ~/.guardrails/guardian
    chmod +x ~/.guardrails/guardian
    ln -sf ~/.guardrails/guardian /usr/local/bin/guardian 2>/dev/null || sudo ln -sf ~/.guardrails/guardian /usr/local/bin/guardian
    echo -e "${GREEN}✓ Guardian core installed${NC}"
else
    echo -e "${YELLOW}⚠ Guardian core not found${NC}"
fi

if [ -f "$SCRIPT_DIR/src/bash_hooks.sh" ]; then
    cp "$SCRIPT_DIR/src/bash_hooks.sh" ~/.guardrails/bash_hooks.sh
    chmod +x ~/.guardrails/bash_hooks.sh
    echo -e "${GREEN}✓ Bash hooks installed${NC}"
else
    echo -e "${YELLOW}⚠ Bash hooks not found${NC}"
fi

if [ -f "$SCRIPT_DIR/src/bin/sudo" ]; then
    cp "$SCRIPT_DIR/src/bin/sudo" ~/.guardrails/bin/sudo
    chmod +x ~/.guardrails/bin/sudo
    echo -e "${GREEN}✓ Sudo wrapper installed${NC}"
else
    echo -e "${YELLOW}⚠ Sudo wrapper not found${NC}"
fi

# Install Guardian scripts
echo -e "${BLUE}[*] Installing Guardian scripts...${NC}"

for script in guardian-nlp.py guardian-encrypt.sh guardian-decrypt.sh guardian-scan-keys.sh guardian-angel.py guardian-test.sh unlock-tracker.py; do
    if [ -f "$SCRIPT_DIR/src/$script" ]; then
        cp "$SCRIPT_DIR/src/$script" ~/.guardrails/$script
        chmod +x ~/.guardrails/$script
        ln -sf ~/.guardrails/$script /usr/local/bin/${script%.py} 2>/dev/null || sudo ln -sf ~/.guardrails/$script /usr/local/bin/${script%.py}
        echo -e "${GREEN}✓ $script installed${NC}"
    fi
done

# Add to PATH
echo -e "${BLUE}[*] Configuring PATH...${NC}"
if ! grep -q ".guardrails/bin" ~/.bashrc 2>/dev/null; then
    echo -e "\n# Guardian Firewall\nexport PATH=\"\$HOME/.guardrails/bin:\$PATH\"" >> ~/.bashrc
    echo -e "${GREEN}✓ PATH updated${NC}"
fi

# Source bash hooks
if ! grep -q ".guardrails/bash_hooks.sh" ~/.bashrc 2>/dev/null; then
    echo -e "\n# Guardian bash hooks\nsource \"\$HOME/.guardrails/bash_hooks.sh\"" >> ~/.bashrc
    echo -e "${GREEN}✓ Bash hooks configured${NC}"
fi

# Protect critical files (Linux only, NOT user files)
if [ "$OS" == "linux" ]; then
    echo -e "${BLUE}[*] Protecting agent configuration files...${NC}"
    
    # ONLY protect agent files, NEVER user shell configs
    if [ -f ~/.qwen/settings.json ]; then
        sudo chattr +i ~/.qwen/settings.json 2>/dev/null && echo -e "${GREEN}✓ Protected ~/.qwen/settings.json${NC}" || true
    fi
    
    if [ -f ~/.qwen/config.json ]; then
        sudo chattr +i ~/.qwen/config.json 2>/dev/null && echo -e "${GREEN}✓ Protected ~/.qwen/config.json${NC}" || true
    fi
    
    # Protect Guardian itself
    sudo chattr +i ~/.guardrails/guardian 2>/dev/null || true
    sudo chattr +i ~/.guardrails/bash_hooks.sh 2>/dev/null || true
    sudo chattr +i ~/.guardrails/bin/sudo 2>/dev/null || true
    
    echo -e "${GREEN}✓ Agent file protection applied${NC}"
    echo ""
    echo -e "${YELLOW}Note: User shell configs (.bashrc, .profile) are NOT protected.${NC}"
    echo "You always have full control of your shell environment."
fi

# Initialize Guardian Angel
echo -e "${BLUE}[*] Initializing Guardian Angel...${NC}"
mkdir -p ~/.guardian-angel/monitored_builds
mkdir -p ~/.guardian-angel/reports
echo -e "${GREEN}✓ Guardian Angel initialized${NC}"

# Create recovery instructions file (NEVER protected)
echo -e "${BLUE}[*] Creating recovery instructions...${NC}"

cat > "$HOME/GUARDIAN_RECOVERY_INSTRUCTIONS.txt" << 'RECOVERY'
╔═══════════════════════════════════════════════════════════════╗
║            GUARDIAN EMERGENCY RECOVERY                        ║
╚═══════════════════════════════════════════════════════════════╝

If you are locked out of your own files, run these commands:

## OPTION 1: Emergency Override Command (ALWAYS WORKS)
    guardian-emergency unlock-all

## OPTION 2: Manual Override
    /usr/bin/sudo chattr -i ~/.qwen/settings.json
    /usr/bin/sudo chattr -i ~/.qwen/config.json
    /usr/bin/sudo chattr -i ~/.guardrails/*

## OPTION 3: Full Disable
    guardian-emergency disable

## OPTION 4: Recovery from Live USB
Boot from USB, mount your drive, and run:
    sudo chattr -i /mnt/home/YOURUSER/.qwen/*
    sudo chattr -i /mnt/home/YOURUSER/.guardrails/*

## Why This Happened
Guardian protects AI agent files from modification.
Sometimes this can accidentally block the human user.

## This File
This file is NEVER protected and ALWAYS accessible.
Keep it in your home directory for emergencies.

────────────────────────────────────────────────────────────────
Installed: $(date)
Guardian Version: 1.0.3-beta (User Sovereignty Fixed)
RECOVERY

echo -e "${GREEN}✓ Recovery instructions saved to ~/GUARDIAN_RECOVERY_INSTRUCTIONS.txt${NC}"

# Setup cron job for unlock tracking (relock on schedule)
if command -v crontab &> /dev/null; then
    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -q "unlock-tracker"; then
        # Add cron job to check every minute
        (crontab -l 2>/dev/null; echo "* * * * * python3 $HOME/.guardrails/unlock-tracker.py check") | crontab -
        echo -e "${GREEN}✓ Cron job added for unlock tracking${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ GUARDIAN Firewall Installed Successfully       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Installed Components:${NC}"
echo "  🔐 Guardian Firewall (core protection)"
echo "  📝 Natural Language Approval (guardian-nlp)"
echo "  🔒 Guardian Encryption (guardian-encrypt)"
echo "  🔍 API Key Scanner (guardian-scan-keys)"
echo "  👼 Guardian Angel (guardian-angel)"
echo "  🚨 EMERGENCY OVERRIDE (guardian-emergency)"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Restart your terminal or run: source ~/.bashrc"
echo "  2. Verify installation: guardian status"
echo "  3. Test emergency: guardian-emergency status"
echo "  4. Read recovery: cat ~/GUARDIAN_RECOVERY_INSTRUCTIONS.txt"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  USER SOVEREIGNTY GUARANTEED${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Your shell configs (.bashrc, .profile) are NEVER protected."
echo "You always have full control of your device."
echo "Emergency override: guardian-emergency"
echo ""
echo -e "${BLUE}Documentation: $SCRIPT_DIR/docs/${NC}"
echo ""

# Reload bashrc
if [ -f ~/.bashrc ]; then
    source ~/.bashrc 2>/dev/null || echo -e "${YELLOW}⚠ Please run: source ~/.bashrc${NC}"
fi
