# GUARDIAN File Access Policy

## Important Reality Check

**Agents run as YOU (the same user).** This means:

- File permissions (`chmod`) CANNOT hide files from agents
- They can read ANY file you can read
- They can execute ANY command you can execute

**What GUARDIAN actually protects:**
- ✅ **WRITES** - Blocked by `chattr +i` (immutable flag)
- ✅ **DELETES** - Blocked by `chattr +i` + bash hooks
- ✅ **BYPASSES** - Blocked by sudo wrapper + bash hooks
- ❌ **READS** - NOT blocked (same user, same permissions)

**Why writes are what matter:**
Agents breaking things = agents MODIFYING files. They can read all they want, but they can't CHANGE anything without approval.

---

## Access Tiers (Write Protection)

GUARDIAN uses **3 tiers of WRITE protection** based on file criticality:

---

## Tier 1: WRITE Protected (Readable) 🔒

**Files:** Core configuration and skill source code

**Protection:** `chattr +i` (immutable flag) + bash hooks

**Access:**
- ✅ **READ:** Allowed (agents can view files for builds)
- ❌ **WRITE:** Blocked (requires guardian approval)
- ❌ **DELETE:** Blocked (even with sudo)

**Files in this tier:**
```
~/.qwen/settings.json          # Qwen config
~/.qwen/config.json            # API credentials
~/.qwen/QWEN.md                # Agent guidelines
~/.qwen/skills/*/GUARDIAN_INFO.md
<Your skill source files>      # When integrated
```

**Why:** Agents need to READ configs and skill code to understand the system and debug builds, but should never MODIFY without approval.

---

## Tier 2: WRITE Protected + Self-Protecting (Readable) 🛡️

**Files:** GUARDIAN system core

**Protection:** `chattr +i` + sudo wrapper + bash hooks

**Access:**
- ✅ **READ:** Allowed (transparency - agents can study the system)
- ❌ **WRITE:** Blocked (even guardian itself requires approval)
- ❌ **DELETE:** Blocked (self-protection)
- ✅ **EXECUTE:** Allowed (commands must work)

**Files in this tier:**
```
~/.guardrails/guardian         # Main guardian script
~/.guardrails/bin/sudo         # Sudo wrapper
~/.guardrails/bash_hooks.sh    # Bash interception hooks
~/.guardrails/.session_token   # Session authentication
```

**Why transparency?** Hiding guardian source doesn't help - agents run as you and can read anything. Better to be transparent so agents understand how to work WITH the system.

**Self-protection:** Guardian protects its own files. Even to update guardian, you need to manually unlock with `sudo chattr -i`.

---

## Tier 3: WRITE Protected (Readable) 📖

**Files:** Shell configuration and documentation

**Protection:** `chattr +i` + bash hooks

**Access:**
- ✅ **READ:** Allowed (agents can view environment setup)
- ❌ **WRITE:** Blocked (requires guardian approval)
- ✅ **EXECUTE:** Allowed (bashrc must run)

**Files in this tier:**
```
~/.bashrc                       # Shell configuration
~/.bash_aliases                 # Shell aliases
~/.profile                      # Profile configuration
~/GUARDIAN_*.md                 # Documentation
```

**Why:** Agents need to read shell configs to understand environment, PATH, aliases, but not modify them.

---

## Implementation

### Apply Tier 2 Protection (Hide Guardian Core)

```bash
#!/bin/bash
# Run this to hide guardian core files from agents

# Remove all permissions for guardian core files
sudo chmod 000 ~/.guardrails/guardian
sudo chmod 000 ~/.guardrails/bin/sudo
sudo chmod 000 ~/.guardrails/bash_hooks.sh
sudo chmod 000 ~/.guardrails/.session_token

# Make immutable (even root can't modify without chattr -i)
sudo chattr +i ~/.guardrails/guardian
sudo chattr +i ~/.guardrails/bin/sudo
sudo chattr +i ~/.guardrails/bash_hooks.sh
sudo chattr +i ~/.guardrails/.session_token

# Guardian directory itself - list only
sudo chmod 755 ~/.guardrails
sudo chattr +i ~/.guardrails

echo "✅ Guardian core files hidden"
echo "   Documentation remains readable"
```

### Apply Tier 1 Protection (Config Files)

```bash
#!/bin/bash
# Config files - readable but not writable

# Make immutable
sudo chattr +i ~/.qwen/settings.json
sudo chattr +i ~/.qwen/config.json
sudo chattr +i ~/.qwen/QWEN.md

# Ensure readable
sudo chmod 644 ~/.qwen/settings.json
sudo chmod 644 ~/.qwen/config.json
sudo chmod 644 ~/.qwen/QWEN.md

echo "✅ Config files readable but not writable"
```

### Apply Tier 3 Protection (Shell Configs)

```bash
#!/bin/bash
# Shell configs - readable and executable but not writable

# Make immutable
sudo chattr +i ~/.bashrc
sudo chattr +i ~/.bash_aliases
sudo chattr +i ~/.profile

# Ensure readable and executable
sudo chmod 644 ~/.bashrc
sudo chmod 644 ~/.bash_aliases
sudo chmod 644 ~/.profile

echo "✅ Shell configs readable but not writable"
```

---

## Agent Capabilities by Tier

**Important:** Agents run as YOU, so they can READ all files. Protection is about WRITES.

| Action | Tier 1 (Config) | Tier 2 (Guardian) | Tier 3 (Shell) |
|--------|-----------------|-------------------|----------------|
| Read file content | ✅ Yes | ✅ Yes | ✅ Yes |
| View with cat | ✅ Yes | ✅ Yes | ✅ Yes |
| Edit with guardian-request | ✅ Yes | ⚠️ Manual unlock | ✅ Yes |
| Direct write (echo, cat) | ❌ No | ❌ No | ❌ No |
| Delete | ❌ No | ❌ No | ❌ No |
| Copy | ✅ Yes | ✅ Yes | ✅ Yes |
| Execute (if script) | N/A | ✅ Yes | ✅ Yes |
| Bypass with sudo | ❌ No | ❌ No | ❌ No |

**Key:** 
- ✅ = Allowed
- ❌ = Blocked
- ⚠️ = Requires manual `sudo chattr -i` first

---

## User Override

**Users can always access all files (you own them):**

```bash
# Read any file (you're the owner)
cat ~/.guardrails/guardian
cat ~/.qwen/settings.json

# Temporarily unlock for editing (user only)
sudo chattr -i ~/.qwen/settings.json
# ... make your changes ...
sudo chattr +i ~/.qwen/settings.json

# Or use guardian-temp-unlock for approval workflow
guardian-temp-unlock ~/.qwen/settings.json 300

# To update guardian itself (manual process)
sudo chattr -i ~/.guardrails/guardian
# ... edit guardian ...
sudo chattr +i ~/.guardrails/guardian
```

---

## Why This Design?

### Transparency for All Files (All Tiers)

**Agents run as YOU, so they can read everything anyway.** File permissions don't hide files from the same user.

**What actually matters:**
- ✅ **Write protection** - Prevents accidental/modification breaks
- ✅ **Bash hooks** - Prevents rm/cp/mv/echo bypasses
- ✅ **Sudo wrapper** - Prevents `sudo chattr -i` bypass
- ✅ **Approval workflow** - Requires human review with context

**Why transparency is better:**
- Agents can study guardian to understand how to work WITH it
- No cat-and-mouse games trying to hide things
- Clear documentation of what's protected and why
- Agents can read configs to debug issues

### Shell Configs Readable (Tier 3)

Agents need to **read** `.bashrc` to:
- Understand PATH setup
- Know available aliases
- Debug shell behavior
- See guardian hooks are present

---

## Quick Setup

**Apply all tiers:**
```bash
# All files - make immutable (write protection)
sudo chattr +i ~/.qwen/settings.json ~/.qwen/config.json ~/.qwen/QWEN.md
sudo chattr +i ~/.guardrails/guardian ~/.guardrails/bin/sudo ~/.guardrails/bash_hooks.sh
sudo chattr +i ~/.bashrc ~/.bash_aliases ~/.profile

# Guardian files - owner read+execute only (optional, for transparency)
sudo chmod 700 ~/.guardrails/guardian ~/.guardrails/bin/sudo ~/.guardrails/bash_hooks.sh
sudo chmod 600 ~/.guardrails/.session_token

# Config files - readable by all
sudo chmod 644 ~/.qwen/settings.json ~/.qwen/config.json ~/.qwen/QWEN.md

# Shell configs - readable by all
sudo chmod 644 ~/.bashrc ~/.bash_aliases ~/.profile

echo "✅ All tiers applied"
```

---

## Testing

**Test Tier 1 (Config - Readable):**
```bash
cat ~/.qwen/settings.json  # ✅ Should work
echo "{}" > ~/.qwen/settings.json  # ❌ Should fail
```

**Test Tier 2 (Guardian - Hidden):**
```bash
cat ~/.guardrails/guardian  # ❌ Permission denied
sudo cat ~/.guardrails/guardian  # ✅ Works (user with sudo)
```

**Test Tier 3 (Shell - Readable):**
```bash
cat ~/.bashrc  # ✅ Should work
echo "alias" >> ~/.bashrc  # ❌ Should fail
```

---

## Recommendation

**Default:** Apply all 3 tiers as documented above.

**If you prefer full transparency:** Keep guardian core readable (Tier 1 instead of Tier 2).

**If you prefer maximum security:** Apply Tier 2 to all guardian files.

**Current default:** Tier 1 for configs, Tier 2 for guardian core, Tier 3 for shell.

---

**Status:** Ready to apply  
**Last Updated:** 2026-03-21
