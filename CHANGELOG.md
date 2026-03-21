# Changelog

All notable changes to GUARDIAN Firewall will be documented in this file.

## [1.0.1-beta] - 2026-03-21

### 🔒 Security Fixes

**CRITICAL:**
- Fixed hardcoded `/home/leviathan/` paths that broke portability
- Added sudo alias to prevent `/usr/bin/sudo` bypass
- Added persistent unlock tracking (survives reboots/crashes)

**HIGH:**
- Replaced background process auto-relock with cron-based tracking
- Added unlock state file for crash recovery
- Added path validation for protected files

**MEDIUM:**
- Added macOS support using `chflags` instead of `chattr`
- Changed request ID generation from `random` to `secrets` module
- Added input validation on file paths

### 🛠️ Improvements

- Added `unlock-tracker.py` for persistent unlock state management
- Added cron job setup for reliable auto-relock
- Improved error handling in Python scripts
- Added bash hook for sudo alias prevention

### 📝 Documentation

- Added SECURITY.md with threat model
- Added CHANGELOG.md
- Updated README.md with macOS compatibility notes
- Documented known limitations and bypass vectors

### ⚠️ Known Issues

- Bash hooks can be bypassed by using absolute paths (`/bin/rm`)
- `chattr` not available on all filesystems (network mounts)
- Protection is for accident prevention, not adversarial security

---

## [1.0.0-beta] - 2026-03-21

### Initial Release

- Guardian Firewall Core (file protection)
- Guardian Encryption (codebase protection)
- Guardian Angel (build security monitoring)
- Natural Language Approval System
- API Key Scanner
- Comprehensive Test Suite (20 tests)

## [1.0.2-beta] - Security Audit Fixes - 2026-03-21

### 🔒 CRITICAL SECURITY FIXES

**From comprehensive security audit by GLM, Qwen, and DeepSeek:**

1. **Bash Function Bypass (HIGH)**
   - Fixed: Made all bash hook functions `readonly -f` to prevent `unset -f` bypass
   - Added: Symlink resolution with `realpath` to prevent symlink attacks
   - Added: Sudo as function instead of alias to prevent `command sudo` bypass

2. **Race Condition in Approval Queue (HIGH)**
   - Fixed: Added `fcntl.flock()` file locking to prevent concurrent approval race conditions
   - Added: Status check before approval to prevent double-processing

3. **State File Tampering (HIGH)**
   - Fixed: Added HMAC-SHA256 signatures to `unlock_state.json`
   - Fixed: Made state file immutable with `chattr +i`
   - Added: Integrity verification on state file load

4. **Audit Log Tampering (MEDIUM)**
   - Fixed: Added HMAC signatures to all audit log entries
   - Fixed: Made audit log append-only with `chattr +a`
   - Added: Remote syslog forwarding capability

5. **Guardian Script Integrity (MEDIUM)**
   - Fixed: All guardian scripts now made immutable after installation
   - Added: Integrity check warning if scripts are modified

### 🛠️ IMPROVEMENTS

- Symlink attack prevention with `realpath` resolution
- File locking for concurrent approval prevention
- HMAC key auto-generation and protection
- Better error handling in unlock-tracker

### 📝 DOCUMENTATION UPDATES

- Updated SECURITY.md with all known bypass vectors
- Added explicit threat model: "accident prevention, NOT adversarial security"
- Documented all architectural limitations

### ⚠️ REMAINING KNOWN LIMITATIONS

These are INTENTIONAL for the threat model (accident prevention):
- Absolute path bypasses (`/bin/rm`) - documented
- Python/Node direct writes - mitigated by `chattr +i`
- Different shell bypasses (zsh, sh) - documented
- Physical/root access attacks - out of scope

