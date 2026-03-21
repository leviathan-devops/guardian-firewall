#!/bin/bash
#===============================================================================
# GUARDIAN Firewall - Main Installation Script
#===============================================================================
# Installs the complete Guardian protection system on your device
# 
# Usage: curl -sSL <repo-url>/install.sh | bash
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

# Install Guardian Firewall core
echo -e "${BLUE}[*] Installing Guardian Firewall core...${NC}"

if [ -f "$SCRIPT_DIR/src/guardian" ]; then
    cp "$SCRIPT_DIR/src/guardian" ~/.guardrails/guardian
    chmod +x ~/.guardrails/guardian
    ln -sf ~/.guardrails/guardian /usr/local/bin/guardian 2>/dev/null || sudo ln -sf ~/.guardrails/guardian /usr/local/bin/guardian
    echo -e "${GREEN}✓ Guardian core installed${NC}"
fi

if [ -f "$SCRIPT_DIR/src/bash_hooks.sh" ]; then
    cp "$SCRIPT_DIR/src/bash_hooks.sh" ~/.guardrails/bash_hooks.sh
    chmod +x ~/.guardrails/bash_hooks.sh
    echo -e "${GREEN}✓ Bash hooks installed${NC}"
fi

if [ -f "$SCRIPT_DIR/src/bin/sudo" ]; then
    cp "$SCRIPT_DIR/src/bin/sudo" ~/.guardrails/bin/sudo
    chmod +x ~/.guardrails/bin/sudo
    echo -e "${GREEN}✓ Sudo wrapper installed${NC}"
fi

# Install Guardian scripts
echo -e "${BLUE}[*] Installing Guardian scripts...${NC}"

for script in guardian-nlp.py guardian-encrypt.sh guardian-decrypt.sh guardian-scan-keys.sh guardian-angel.py guardian-test.sh; do
    if [ -f "$SCRIPT_DIR/src/$script" ]; then
        cp "$SCRIPT_DIR/src/$script" ~/.guardrails/$script
        chmod +x ~/.guardrails/$script
        ln -sf ~/.guardrails/$script /usr/local/bin/$(basename $script .py) 2>/dev/null || sudo ln -sf ~/.guardrails/$script /usr/local/bin/$(basename $script .py)
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

# Detect and handle macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}⚠ Detected macOS - using chflags instead of chattr${NC}"
    
    # macOS uses chflags for immutability
    if [ -f ~/.qwen/settings.json ]; then
        chflags schg ~/.qwen/settings.json 2>/dev/null && echo -e "${GREEN}✓ Protected ~/.qwen/settings.json (macOS)${NC}" || true
    fi
    
    if [ -f ~/.qwen/config.json ]; then
        chflags schg ~/.qwen/config.json 2>/dev/null && echo -e "${GREEN}✓ Protected ~/.qwen/config.json (macOS)${NC}" || true
    fi
    
    echo -e "${BLUE}Note: Guardian Angel and API scanner fully supported on macOS${NC}"
    OS="macos"
fi

# Protect critical files (Linux only)
if [ "$OS" == "linux" ]; then
    echo -e "${BLUE}[*] Protecting critical configuration files...${NC}"
    
    if [ -f ~/.qwen/settings.json ]; then
        sudo chattr +i ~/.qwen/settings.json 2>/dev/null && echo -e "${GREEN}✓ Protected ~/.qwen/settings.json${NC}" || true
    fi
    
    if [ -f ~/.qwen/config.json ]; then
        sudo chattr +i ~/.qwen/config.json 2>/dev/null && echo -e "${GREEN}✓ Protected ~/.qwen/config.json${NC}" || true
    fi
    
    sudo chattr +i ~/.guardrails/guardian 2>/dev/null || true
    sudo chattr +i ~/.guardrails/bin/sudo 2>/dev/null || true
    
    echo -e "${GREEN}✓ File protection applied${NC}"
fi

# Initialize Guardian Angel
echo -e "${BLUE}[*] Initializing Guardian Angel...${NC}"
mkdir -p ~/.guardian-angel/monitored_builds
mkdir -p ~/.guardian-angel/reports
echo -e "${GREEN}✓ Guardian Angel initialized${NC}"

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
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Restart your terminal or run: source ~/.bashrc"
echo "  2. Verify installation: guardian status"
echo "  3. For coding agents: See skills/guardian-encryption-skill.json"
echo "  4. For build monitoring: See prompts/guardian-angel-integration.txt"
echo ""
echo -e "${BLUE}Documentation: $SCRIPT_DIR/docs/${NC}"
echo ""

# Reload bashrc
if [ -f ~/.bashrc ]; then
    source ~/.bashrc 2>/dev/null || echo -e "${YELLOW}⚠ Please run: source ~/.bashrc${NC}"
fi

# Setup cron job for unlock tracking (relock on schedule)
if command -v crontab &> /dev/null; then
    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -q "unlock-tracker"; then
        # Add cron job to check every minute
        (crontab -l 2>/dev/null; echo "* * * * * python3 $HOME/.guardrails/unlock-tracker.py check") | crontab -
        echo -e "${GREEN}✓ Cron job added for unlock tracking${NC}"
    fi
fi
