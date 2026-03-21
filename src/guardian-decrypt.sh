#!/bin/bash
# GUARDIAN DECRYPT - Remove protection from codebase

if [ -z "$1" ]; then
    echo "Usage: guardian-decrypt <directory-or-file>"
    exit 1
fi

TARGET="$1"

echo "⚠️  Removing GUARDIAN protection from: $TARGET"

if [ -f "$TARGET" ]; then
    sudo chattr -i "$TARGET"
    echo "✓ Decrypted: $TARGET"
else
    find "$TARGET" -type f -exec sudo chattr -i {} \;
    echo "✓ Decrypted all files in: $TARGET"
fi

rm -f "$TARGET/GUARDIAN_ENCRYPTED.md" 2>/dev/null
echo "✅ GUARDIAN protection removed"
