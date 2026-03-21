# 🔐 GUARDIAN Firewall

**The Unbreakable Protection System for AI Agent Builds**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/guardian-firewall/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-12/12%20passed-brightgreen.svg)](docs/TEST_RESULTS.md)

---

## 🚀 Quick Start

### Install Guardian Firewall

```bash
# Clone the repo
git clone https://github.com/yourusername/guardian-firewall.git
cd guardian-firewall

# Run installer
./install.sh
```

### One-Liner Install

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/guardian-firewall/main/install.sh | bash
```

---

## 📋 What is GUARDIAN?

GUARDIAN is a **multi-layer file protection system** that prevents AI agents from modifying protected files without explicit human approval - even in YOLO mode.

### Three Core Systems

| System | Purpose | When to Use |
|--------|---------|-------------|
| 🔐 **Guardian Firewall** | Core protection for critical files | Always active |
| 🔒 **Guardian Encryption** | Apply protection to completed codebases | Ready to ship |
| 👼 **Guardian Angel** | Real-time security monitoring during builds | Every build |

---

## 🔐 Guardian Firewall (Core System)

**Protects your critical files from unauthorized modification.**

### Features

- ✅ **Immutable Files** - Kernel-level `chattr +i` protection
- ✅ **Natural Language Approval** - Respond "yes"/"no" in chat
- ✅ **Bash Interception** - Blocks rm/cp/mv/echo/cat/tee
- ✅ **Sudo Wrapper** - Blocks `sudo chattr -i` bypass
- ✅ **Auto-Relock** - 5-minute unlock windows
- ✅ **Audit Trail** - All changes logged
- ✅ **API Key Scanner** - Detects exposed secrets

### How It Works

```
Agent needs to edit → Creates request → You see prompt in chat →
You respond "yes" → File unlocked 5 min → Agent edits → Auto-relocks
```

### User Experience

**Agent shows you:**
```
╔══════════════════════════════════════════════════════════╗
║           🔐 GUARDIAN FILE EDIT REQUEST                  ║
╚══════════════════════════════════════════════════════════╝

📁 File: ~/.qwen/settings.json
🤖 Agent: code_agent
📝 Reason: Update timeout from 900 to 1800 seconds

✅ Respond "approved" or "denied"
💡 Just reply naturally in the chat
```

**You type:** `yes go ahead`

**System:** ✅ Approved, file unlocked for 5 minutes, auto-relocks

### Protected Files (Default)

- `~/.qwen/settings.json` - Qwen Code config
- `~/.qwen/config.json` - API credentials
- `~/.bashrc`, `~/.bash_aliases` - Shell configs
- Any files you encrypt with Guardian Encryption

---

## 🔒 Guardian Encryption

**Apply Guardian protection to completed codebases.**

### What It Does

- 🔒 Makes code **IMMUTABLE** (cannot be modified without approval)
- 📌 Makes code **STICKY** (cannot be deleted by agents)
- 🎯 **ENFORCES** code execution (cannot be ignored)
- 🔍 **Scans for API keys** before encrypting
- 📝 Creates **GUARDIAN_ENCRYPTED.md** manifest

### When to Use

**DO encrypt:**
- ✅ Completed features ready to ship
- ✅ Custom skills/integrations
- ✅ Critical architecture
- ✅ Stable configurations
- ✅ AI-generated code to preserve

**DON'T encrypt:**
- ❌ Work-in-progress
- ❌ Temporary files
- ❌ Test code

### Usage

```bash
# Encrypt a codebase
guardian-encrypt.sh ~/my-completed-project/

# Output:
# ✓ ENCRYPTED: src/main.py
# ✓ ENCRYPTED: src/core.py
# ✓ ENCRYPTED: config.json
# ✓ Created: GUARDIAN_ENCRYPTED.md
#
# 3 files now IMMUTABLE
```

### Use Case: Skill Files

**Problem:** Agents ignore custom skills and use default CLI code.

**Solution:**
```bash
guardian-encrypt.sh ~/.qwen/skills/deepseek-brain/
```

**Result:**
- Skill files IMMUTABLE
- Agents MUST use skill (cannot delete)
- Architecture enforced
- Changes require human approval

---

## 👼 Guardian Angel

**Real-time security monitoring during builds.**

### What It Does

- 👁️ **Silently monitors** builds while you code
- 🔍 **Detects vulnerabilities** in real-time
- 🛑 **Reports BEFORE testing** - between Step 1 and Step 2
- 💡 **Provides remediation** - exact fix instructions
- 📊 **Generates reports** - markdown security reports

### Detected Vulnerabilities

| Severity | Examples | Action |
|----------|----------|--------|
| 🔴 CRITICAL | Hardcoded API keys, command injection | FIX BEFORE TESTING |
| 🟠 HIGH | SQL injection, path traversal | FIX BEFORE TESTING |
| 🟡 MEDIUM | Insecure randomness, bare excepts | REVIEW & FIX |
| 🔵 LOW | Debug code, hardcoded URLs | LOG FOR LATER |

### Build Workflow Integration

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: WRITE CODE                                         │
│  - Guardian Angel monitors silently                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  🛑 GUARDIAN ANGEL ACTIVATES (MANDATORY GATE)              │
│  - Run: guardian-angel scan <build-name>                   │
│  - Fix CRITICAL/HIGH vulnerabilities                        │
│  - Re-scan until clean                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: TEST IN DOCKER SANDBOX                             │
│  - Only proceeds if Guardian Angel gives ✅                 │
└─────────────────────────────────────────────────────────────┘
```

### Integration

**Copy this prompt to your coding agent:**

```bash
cat prompts/guardian-angel-integration.txt
```

The prompt ensures:
- Guardian Angel activates automatically
- Scans run before EVERY test phase
- CRITICAL/HIGH issues MUST be fixed first
- Security reports saved with build artifacts

---

## 📦 Installation

### Prerequisites

- Linux (macOS partially supported - `chattr` not available)
- Python 3.6+
- Bash
- sudo access

### Quick Install

```bash
# Clone repo
git clone https://github.com/yourusername/guardian-firewall.git
cd guardian-firewall

# Run installer
./install.sh

# Verify installation
guardian status
```

### Manual Install

```bash
# Copy scripts
cp src/* ~/.guardrails/
chmod +x ~/.guardrails/*

# Add to PATH
echo 'export PATH="$HOME/.guardrails/bin:$PATH"' >> ~/.bashrc

# Source bash hooks
echo 'source "$HOME/.guardrails/bash_hooks.sh"' >> ~/.bashrc
source ~/.bashrc

# Protect files (Linux only)
sudo chattr +i ~/.qwen/settings.json ~/.qwen/config.json
```

---

## 🧪 Testing

### Run Test Suite

```bash
./guardian-test.sh
```

### Expected Output

```
╔══════════════════════════════════════════════════════════╗
║       GUARDIAN Encryption - Comprehensive Test Suite     ║
╚══════════════════════════════════════════════════════════╝

[TEST 1] Verify files are immutable... ✓ PASS
[TEST 2] Try to DELETE encrypted file... ✓ PASS
[TEST 3] Try to OVERWRITE encrypted file... ✓ PASS
[TEST 4] Try to MODIFY with sed... ✓ PASS
[TEST 5] Verify encrypted files EXECUTE... ✓ PASS
[TEST 6] Verify encrypted files READABLE... ✓ PASS
[TEST 7] Try sudo chattr -i BYPASS... ✓ PASS
[TEST 8] Test guardian-request workflow... ✓ PASS
[TEST 9] Test guardian-approve workflow... ✓ PASS
[TEST 10] Edit file after approval... ✓ PASS
[TEST 11] Re-lock and verify immutable... ✓ PASS
[TEST 12] Test guardian-decrypt... ✓ PASS

✅ ALL TESTS PASSED - GUARDIAN ENCRYPTION READY FOR PRODUCTION
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [GUARDIAN_FINAL.md](docs/GUARDIAN_FINAL.md) | Complete system documentation |
| [GUARDIAN_NATURAL_LANGUAGE.md](docs/GUARDIAN_NATURAL_LANGUAGE.md) | Natural language approval guide |
| [GUARDIAN_ENCRYPTION_PRODUCTION.md](docs/GUARDIAN_ENCRYPTION_PRODUCTION.md) | Encryption production docs |
| [GUARDIAN_FILE_ACCESS_POLICY.md](docs/GUARDIAN_FILE_ACCESS_POLICY.md) | File access policy |
| [GUARDIAN_SKILL_INTEGRATION.md](docs/GUARDIAN_SKILL_INTEGRATION.md) | Skill integration guide |

---

## 🔧 Commands Reference

### Guardian Firewall

```bash
guardian status              # Check protection status
guardian request <file> '<reason>'  # Request file edit
guardian approve <id>        # Approve request
guardian pending             # View pending requests
guardian-temp-unlock <file>  # Temporarily unlock
guardian-log                 # View approval history
```

### Guardian Encryption

```bash
guardian-encrypt.sh <dir>    # Encrypt a codebase
guardian-decrypt.sh <dir>    # Remove encryption
guardian-scan-keys.sh <dir>  # Scan for API keys
```

### Guardian Angel

```bash
guardian-angel start <dir>   # Start monitoring
guardian-angel scan <name>   # Scan for vulnerabilities
guardian-angel report <name> # Generate report
guardian-angel stop <name>   # Stop monitoring
guardian-angel list          # List monitored builds
```

---

## 🛡️ Security Model

### What GUARDIAN Protects Against

| Threat | Protection |
|--------|------------|
| Accidental agent edits | ✅ Approval required |
| Silent config drift | ✅ Immutable files |
| API key exposure | ✅ Pre-encryption scan |
| Unauthorized changes | ✅ Logged audit trail |
| Bypass attempts | ✅ Multiple layers |

### What GUARDIAN Does NOT Protect Against

| Threat | Why | Mitigation |
|--------|-----|------------|
| Physical access | You own the machine | Physical security |
| You removing it | Your choice | Don't remove it |
| Social engineering | You approve requests | Review carefully |

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run tests: `./guardian-test.sh`
5. Submit a PR

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

**Built by:** Qwen Code + DeepSeek R1 + User Collaboration  
**Philosophy:** Protection through transparency + multiple layers  
**Inspiration:** "Don't trust, enforce"

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/guardian-firewall/issues)
- **Documentation:** [docs/](docs/)
- **Quick Start:** See above

---

**Status:** ✅ Production Ready  
**Tests:** 12/12 PASSED  
**Version:** 1.0.0
