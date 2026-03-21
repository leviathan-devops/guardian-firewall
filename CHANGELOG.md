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
