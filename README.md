# GUARDIAN v2.0 - Safe File Protection for AI Agents

## 🔴 What's New in v2.0

**USER SOVEREIGNTY** is now built into the core architecture.

### The Problem with v1.x

```bash
# v1.x could accidentally lock user out of their own device
# If .bashrc was in protected list:
echo "export PATH=..." >> ~/.bashrc
# Result: Operation not permitted
# User locked out! 😱
```

### The Solution in v2.0

```bash
# v2.0 NEVER protects user shell configs
# User sovereignty list:
USER_SOVEREIGN_FILES=(
    ~/.bashrc
    ~/.bash_aliases
    ~/.profile
    ~/.zshrc
    ~/.ssh/
    ~/.gnupg/
)
# These are ALWAYS editable by the human user.
```

---

## Installation

### Quick Install

```bash
# Clone and install
git clone https://github.com/leviathan-devops/guardian-firewall.git
cd guardian-firewall
./install.sh
```

### What the Installer Does

1. **Unlocks all user files first** (safety)
2. **Installs emergency override** to `/usr/bin/guardian-emergency`
3. **Creates recovery instructions** at `~/GUARDIAN_RECOVERY_INSTRUCTIONS.txt`
4. **Asks for confirmation** before protecting anything
5. **Only protects agent files**, never user files

---

## Emergency Override

### If You're Locked Out

```bash
# Option 1: Emergency command
guardian-emergency unlock-all

# Option 2: Recover user files only
guardian-emergency recover-user-files

# Option 3: Disable Guardian entirely
guardian-emergency disable

# Option 4: Manual override
/usr/bin/sudo chattr -i ~/.qwen/settings.json
```

### Why This Always Works

- `guardian-emergency` is in `/usr/bin/` (system path)
- It uses `/usr/bin/sudo` directly (full path bypasses wrappers)
- It's installed BEFORE any files are protected
- The recovery instructions file is NEVER protected

---

## Protected vs. Not Protected

### Protected (Need Approval)

| File | Why Protected |
|------|---------------|
| `~/.qwen/settings.json` | AI agent configuration |
| `~/.qwen/config.json` | AI agent API credentials |
| `~/.qwen/QWEN.md` | AI agent guidelines |
| `~/.guardrails/*` | Guardian system files |

### NOT Protected (User Sovereign)

| File | Why Not Protected |
|------|-------------------|
| `~/.bashrc` | User shell config |
| `~/.profile` | User profile |
| `~/.zshrc` | User zsh config |
| `~/.ssh/*` | User SSH keys |
| `~/.gnupg/*` | User GPG keys |
| All other files | User has control |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    INSTALLATION                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │  1. Unlock user files (safety first)            │    │
│  │  2. Install emergency override to /usr/bin      │    │
│  │  3. Create recovery instructions (unprotected)  │    │
│  │  4. ASK USER before protecting                  │    │
│  │  5. Protect ONLY agent files                    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    RUNTIME PROTECTION                    │
│  ┌─────────────────────────────────────────────────┐    │
│  │  is_protected_file() {                          │    │
│  │    if is_user_sovereign($file): return FALSE    │    │
│  │    if in PROTECTED_FILES: return TRUE           │    │
│  │    return FALSE                                 │    │
│  │  }                                              │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   EMERGENCY RECOVERY                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │  /usr/bin/guardian-emergency                    │    │
│  │  ├── unlock-all          # Unlock everything    │    │
│  │  ├── recover-user-files  # Force unlock user    │    │
│  │  ├── disable             # Disable Guardian     │    │
│  │  └── status              # Check status         │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ~/GUARDIAN_RECOVERY_INSTRUCTIONS.txt                  │
│  └── NEVER protected, always readable                  │
└─────────────────────────────────────────────────────────┘
```

---

## The Golden Rules

These are hardcoded into v2.0:

### Rule 1: USER SOVEREIGNTY
> The human user ALWAYS has final control over their device.

### Rule 2: NO USER FILE PROTECTION
> User shell configs, SSH keys, and home directory are NEVER protected.

### Rule 3: EMERGENCY ALWAYS WORKS
> `/usr/bin/guardian-emergency` MUST work even if everything else fails.

### Rule 4: RECOVERY EXISTS OUTSIDE
> Recovery instructions exist in a file that is NEVER protected.

### Rule 5: INSTALL CONFIRMATION
> User must confirm before ANY files are protected.

---

## Commands

### Guardian Core

```bash
guardian init                 # Initialize protection
guardian status               # Show what's protected
guardian request <file> '<reason>'  # Request edit (agents)
guardian approve <id>         # Approve request (users)
guardian pending              # Show pending requests
guardian temp-unlock <file>   # Temporarily unlock
guardian log                  # View activity log
```

### Emergency

```bash
guardian-emergency unlock-all         # Unlock everything
guardian-emergency recover-user-files # Unlock user configs
guardian-emergency disable            # Disable Guardian
guardian-emergency status             # Check status
```

---

## Migration from v1.x

If you have v1.x installed:

```bash
# 1. Run emergency unlock
guardian-emergency unlock-all

# 2. Check if user files are locked
guardian-emergency status

# 3. If locked, recover them
guardian-emergency recover-user-files

# 4. Install v2.0
./install.sh
```

---

## Testing

After installation, verify user sovereignty:

```bash
# These should ALL work without any approval:
echo "# test" >> ~/.bashrc
echo "# test" >> ~/.profile

# This should be BLOCKED:
echo "test" >> ~/.qwen/settings.json
# Expected: Permission denied or Guardian block
```

---

## Files in This Release

| File | Purpose |
|------|---------|
| `guardian` | Main guardian script |
| `install.sh` | Safe installer |
| `bash_hooks.sh` | Shell hooks |
| `GUARDIAN_RECOVERY_INSTRUCTIONS.txt` | Emergency docs |

---

## What Changed from v1.x

### Removed from Protected List
- `~/.bashrc`
- `~/.bash_aliases`
- `~/.profile`

### Added
- User sovereignty check in `is_protected_file()`
- `guardian-emergency` command in `/usr/bin/`
- Recovery instructions file
- Installation confirmation prompt
- Pre-install user file unlock

---

## Reporting Issues

If Guardian ever locks you out of YOUR OWN files (not agent files):

1. Run `guardian-emergency status` to check
2. Run `guardian-emergency recover-user-files` to fix
3. Report the issue with:
   - What file was locked
   - What command you ran
   - Output of `guardian-emergency status`

This is a bug - user sovereignty violations should never happen.
