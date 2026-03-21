# 🔐 Security Information

## ⚠️ IMPORTANT: Security Audit Status

**This software has NOT undergone independent security auditing.**

GUARDIAN Firewall is provided as-is for personal and internal use. Before using in production environments or for protecting critical infrastructure, you should:

1. **Conduct a security audit** with qualified professionals
2. **Review the source code** for your specific use case
3. **Test thoroughly** in a staging environment
4. **Understand the limitations** documented below

## Threat Model

### What GUARDIAN Protects Against

| Threat | Protection Layer | Effectiveness |
|--------|-----------------|---------------|
| Accidental file modification | `chattr +i` + bash hooks | HIGH |
| Accidental file deletion | `chattr +i` | HIGH |
| `sudo chattr -i` bypass | Sudo wrapper | HIGH |
| API key exposure | Pre-encryption scanner | HIGH |
| Unauthorized code changes | Approval workflow | HIGH |

### What GUARDIAN Does NOT Protect Against

| Threat | Why | Mitigation |
|--------|-----|------------|
| Physical access to machine | Kernel-level access bypasses all | Physical security |
| Root user intentionally removing protection | Owner can remove own locks | Don't remove it |
| Social engineering approval requests | User approves malicious requests | Review carefully |
| Kernel module attacks | Beyond userspace protection | Kernel hardening |
| Compromised build pipeline | Guardian monitors but doesn't control | Pipeline security |

## Security Architecture

### Layer 1: Kernel Immutability
- Uses `chattr +i` (Linux ext4 filesystem feature)
- Even root cannot modify without `chattr -i`
- Intercepted by sudo wrapper

### Layer 2: Bash Interception
- Overrides rm, cp, mv, cat, tee, echo
- Checks file paths against protected list
- Blocks operations on protected files

### Layer 3: Sudo Wrapper
- Installed before /usr/bin/sudo in PATH
- Intercepts dangerous patterns
- Passes safe commands through

### Layer 4: Approval Workflow
- All changes require explicit approval
- Natural language processing for user intent
- Audit trail of all requests

### Layer 5: API Key Scanning
- Detects 15+ types of exposed secrets
- Blocks encryption until keys removed
- Generates security reports

## Known Limitations

1. **Linux-only**: `chattr` requires ext4/xfs filesystem
2. **Same-user protection**: Agents running as same user can read all files
3. **No encryption**: Files are immutable but not encrypted
4. **No network security**: Does not protect against network attacks

## Incident Response

If you discover a security vulnerability:

1. **Document** the issue thoroughly
2. **Report** to the maintainer
3. **Do not** disclose publicly until fixed
4. **Provide** reproduction steps if possible

## Version Security

| Version | Security Status | Notes |
|---------|----------------|-------|
| 1.0.0-beta | ⚠️ Not audited | Internal use only |

## Recommendations for Production Use

1. **Security audit** before protecting critical systems
2. **Staging testing** in non-production environment
3. **Backup strategy** for protected files
4. **Access control** for machines running Guardian
5. **Monitoring** for Guardian approval requests
6. **Documentation** of protected files and why

---

**Use at your own risk. No warranty provided.**
