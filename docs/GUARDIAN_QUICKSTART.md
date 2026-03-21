# GUARDIAN - Quick Start Guide

## ✅ System Status: ACTIVE

```
Protected Files: 7 LOCKED
Sudo Wrapper: ACTIVE
Bash Hooks: ACTIVE
Approval System: READY
```

---

## For AGENTS (AI Assistants)

### You CANNOT directly edit protected files anymore.

**Protected Files:**
- `~/.qwen/settings.json`
- `~/.qwen/config.json`
- `~/.qwen/QWEN.md`
- `~/.guardrails/*`
- `~/.bashrc`
- `~/.bash_aliases`
- `~/.profile`

### To Request a File Edit:

```bash
guardian-request <filename> '<reason>'
```

**Example:**
```bash
guardian-request settings.json 'Need to update timeout from 900 to 1800 for long builds'
```

**What Happens:**
1. Request created with unique ID
2. User notified of pending approval
3. User reviews and confirms (or denies)
4. File unlocked for 5 minutes
5. Agent makes edit
6. File auto-relocks

### What Gets BLOCKED:

```bash
rm ~/.qwen/settings.json          # ❌ Blocked
echo "{}" > settings.json         # ❌ Blocked  
sudo chattr -i settings.json      # ❌ Blocked
cp config.json settings.json      # ❌ Blocked
tee settings.json                 # ❌ Blocked
```

---

## For USERS (Human)

### View Pending Requests
```bash
guardian-pending
```

### Approve a Request
```bash
guardian-approve <request_id>
# You will be prompted: "Do you approve this file modification? (yes/no)"
```

### Temporarily Unlock for Manual Edit
```bash
# Unlock for 5 minutes (default)
guardian-temp-unlock settings.json

# Unlock for 10 minutes
guardian-temp-unlock settings.json 600

# Make your edit...
# File auto-relocks after timeout
```

### View Protection Status
```bash
guardian status
```

### View Approval History
```bash
guardian-log      # Last 20 entries
guardian-log 50   # Last 50 entries
```

---

## Emergency Recovery

### If You Get Locked Out
```bash
# Unlock everything (requires sudo)
sudo chattr -i ~/.qwen/* ~/.guardrails/* ~/.bashrc

# Make your changes

# Re-lock
sudo chattr +i ~/.qwen/settings.json ~/.qwen/config.json ~/.guardrails/ ~/.bashrc
```

### If Guardian Breaks
```bash
# Remove all locks
sudo chattr -R -i ~/.qwen ~/.guardrails

# Fix guardian files
# ... make your changes ...

# Re-initialize
guardian init
```

---

## Security Summary

| Protection | How It Works |
|------------|--------------|
| **File Locking** | `chattr +i` makes files immutable at filesystem level |
| **Sudo Wrapper** | Intercepts `sudo chattr -i` and blocks without approval |
| **Bash Hooks** | Overrides rm, cp, mv, cat, tee, echo to protect files |
| **Approval Queue** | All edits require user confirmation with context |
| **Auto-Relock** | Files re-lock automatically after 5 minutes |
| **Self-Protection** | Guardian protects its own files from modification |

---

## Commands Quick Reference

| Command | Description |
|---------|-------------|
| `guardian status` | Show protection status |
| `guardian-request <file> '<reason>'` | Request file edit (agents) |
| `guardian-approve <id>` | Approve request (users) |
| `guardian-pending` | View pending requests |
| `guardian-log [n]` | View approval history |
| `guardian-temp-unlock <file> [sec]` | Temporarily unlock (users) |

---

## Testing (Safe Tests)

```bash
# Test 1: Try to delete protected file
rm ~/.qwen/settings.json
# Expected: "Operation not permitted"

# Test 2: Try to unlock with sudo
sudo chattr -i ~/.qwen/settings.json
# Expected: "🚨 GUARDIAN: Dangerous command detected!"

# Test 3: Request and approve
guardian-request settings.json 'Testing'
guardian-pending
# Then approve with the request ID shown
```

---

## Files and Locations

```
/usr/local/bin/guardian          → Main command
~/.guardrails/guardian           → Guardian script
~/.guardrails/bash_hooks.sh      → Bash interception
~/.guardrails/bin/sudo           → Sudo wrapper
~/.guardrails/approval_queue/    → Pending requests
~/.guardrails/logs/              → Approval logs
~/.guardrails/backups/           → Config backups
```

---

## What Changed in This Session

1. **Created Guardian System** - Unbreakable guardrails
2. **Locked All Config Files** - chattr +i on 7 files
3. **Installed Sudo Wrapper** - Blocks dangerous sudo commands
4. **Installed Bash Hooks** - Blocks dangerous shell commands
5. **Created Approval System** - Requires user confirmation with context
6. **Added Auto-Relock** - Files re-lock after 5 minutes
7. **Created Documentation** - Full docs in GUARDIAN_DOCUMENTATION.md

---

**Full Documentation:** `/home/leviathan/GUARDIAN_DOCUMENTATION.md`

**Status:** ✅ ACTIVE AND PROTECTING
