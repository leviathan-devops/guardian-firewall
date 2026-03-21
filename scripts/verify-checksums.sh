#!/bin/bash
# Verify download integrity

echo "GUARDIAN Firewall - Checksum Verification"
echo "========================================="

# Generate SHA256 checksums
sha256sum src/* > CHECKSUMS.sha256
echo "✅ Checksums generated: CHECKSUMS.sha256"

# To verify:
# sha256sum -c CHECKSUMS.sha256
