# GUARDIAN Natural Language Approval System

## Overview

GUARDIAN now supports **natural language approval** - users can approve or deny file edit requests by simply responding in plain English within Qwen Code, without running any terminal commands.

---

## How It Works

### For Users (Non-Technical)

**You will see a prompt like this in Qwen Code:**

```
╔══════════════════════════════════════════════════════════╗
║           🔐 GUARDIAN FILE EDIT REQUEST                  ║
╚══════════════════════════════════════════════════════════╝

📁 File to Modify: `~/.qwen/settings.json`

🤖 Agent: code_agent

📝 Reason for Edit:
Need to update timeout from 900 to 1800 seconds to prevent 
streaming timeouts during long build processes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  This file is GUARDIAN encrypted - it cannot be modified 
   without your approval.

✅ To APPROVE, respond with:
   "approved", "yes", "go ahead", "ok"

❌ To DENY, respond with:
   "denied", "no", "reject", "don't do it"

💡 The Qwen Code agent will handle this automatically.
   Just reply naturally in the chat.
```

**You just respond naturally:**

```
yes, go ahead
```

or

```
approved - this is needed for my builds
```

or

```
no, don't change that file
```

**That's it!** The agent handles everything automatically.

---

## What is GUARDIAN?

**GUARDIAN** is a background protection system that:

1. **Prevents accidental changes** to important files
2. **Requires your approval** before any modifications
3. **Logs all changes** for your records
4. **Works silently** - you only see it when approval is needed

**You don't need to know how it works** - just respond "yes" or "no" when asked.

---

## Why This File is Encrypted

Some files are too important to allow automatic changes:

- **Config files** - Settings that control how tools work
- **Skill files** - Custom integrations and architecture
- **Core code** - Critical application logic
- **Security files** - Credentials and authentication

These files are **GUARDIAN encrypted** to ensure:
- You always know what's changing
- Changes can't happen silently
- Accidental "fixes" don't break things
- You have final say over important modifications

---

## Response Examples

### Approving

| Your Response | Result |
|---------------|--------|
| "yes" | ✅ Approved |
| "approved" | ✅ Approved |
| "go ahead" | ✅ Approved |
| "ok" | ✅ Approved |
| "sure" | ✅ Approved |
| "yes, allow the change" | ✅ Approved |
| "approved - this is needed" | ✅ Approved |

### Denying

| Your Response | Result |
|---------------|--------|
| "no" | ❌ Denied |
| "denied" | ❌ Denied |
| "reject" | ❌ Denied |
| "don't do it" | ❌ Denied |
| "keep it locked" | ❌ Denied |
| "no thanks" | ❌ Denied |

### Asking for More Info

| Your Response | Result |
|---------------|--------|
| "Why is this change needed?" | 🤖 Agent explains |
| "What exactly will you change?" | 🤖 Agent details the edit |
| "Is there another way?" | 🤖 Agent suggests alternatives |

---

## What Happens After Approval

1. **File unlocks** for 5 minutes
2. **Agent makes the requested change**
3. **File automatically re-locks** after 5 minutes
4. **Change is logged** in your approval history

**You don't need to do anything** - it's all automatic.

---

## What Happens After Denial

1. **File stays locked** - no changes made
2. **Request is logged** as denied
3. **Agent continues** with alternative approach (if available)

**No harm done** - the file remains protected.

---

## For Developers (Technical Details)

### Commands

```bash
# Create approval request (automatic)
guardian request <file> '<reason>'

# Respond to request (automatic via NLP)
guardian-nlp respond <request_id> '<user_text>'

# View pending requests
guardian-nlp pending

# Manual approve (if needed)
guardian approve <request_id>
```

### API Key Scanner

Before encrypting any codebase, GUARDIAN scans for exposed API keys:

```bash
# Scan for API keys (automatic during encryption)
guardian-scan-keys <directory>

# Blocks encryption if keys found
# Creates report: <directory>/.guardian_key_scan.md
```

**Detected patterns:**
- AWS Access Keys
- GitHub/GitLab Tokens
- OpenAI/DeepSeek API Keys
- Stripe Keys
- Google API Keys
- Generic API key assignments
- Passwords in config
- Private keys

### Files Created

| File | Purpose |
|------|---------|
| `guardian-nlp.py` | Natural language processing |
| `guardian-scan-keys.sh` | API key scanner |
| `~/.guardrails/pending_responses.json` | Pending requests |
| `~/.guardrails/approval_queue/` | Request queue |
| `~/.guardrails/approval_log` | Approval history |

---

## Security Model

### What GUARDIAN Protects

| Threat | Protection |
|--------|------------|
| Accidental agent edits | ✅ Approval required |
| Silent config drift | ✅ Immutable files |
| API key exposure | ✅ Pre-encryption scan |
| Unauthorized changes | ✅ Logged audit trail |
| Bypass attempts | ✅ Multiple layers |

### What GUARDIAN Doesn't Protect

| Threat | Why | Mitigation |
|--------|-----|------------|
| Physical access | You own the machine | Physical security |
| You removing it | Your choice | Don't remove it |
| Social engineering | You approve requests | Review carefully |

---

## Troubleshooting

### "I don't see approval prompts"

Check if GUARDIAN is active:
```bash
guardian status
```

### "Agent says request pending but I don't see it"

View pending requests:
```bash
guardian-nlp pending
```

### "I approved but file is still locked"

Check approval status:
```bash
cat ~/.guardrails/pending_responses.json
```

### "How do I see what was changed?"

View approval log:
```bash
cat ~/.guardrails/approval_log
```

---

## Best Practices

### For Users

1. **Read the reason** - Understand what's being changed
2. **Ask if unsure** - "Why is this needed?"
3. **Approve promptly** - Don't leave requests pending
4. **Review periodically** - Check approval log

### For Agents

1. **Be specific** - Explain exactly what + why
2. **Provide context** - What problem does this solve?
3. **Wait for approval** - Don't assume yes
4. **Edit minimally** - Only change what's needed

---

## Example Flow

```
Agent: I need to update the timeout in settings.json

╔══════════════════════════════════════════════════════════╗
║           🔐 GUARDIAN FILE EDIT REQUEST                  ║
╚══════════════════════════════════════════════════════════╝

📁 File: ~/.qwen/settings.json
🤖 Agent: code_agent
📝 Reason: Update timeout from 900 to 1800 seconds to prevent 
          streaming timeouts during long builds

✅ Respond "approved" or "denied"

You: approved

Agent: ✅ Request approved! Making the change now...
Agent: ✅ Change complete. File re-locked.
```

---

## Summary

**GUARDIAN Natural Language Approval:**

- ✅ No terminal commands needed
- ✅ Just respond "yes" or "no" naturally
- ✅ Explains what, why, and context
- ✅ Automatic approval/denial processing
- ✅ API key scanning before encryption
- ✅ Complete audit trail
- ✅ Works silently in background

**You're in control** - GUARDIAN just makes sure you stay informed.
