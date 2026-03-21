#!/bin/bash
#===============================================================================
# GUARDIAN Bash Hooks - Intercept file operations
#===============================================================================
# These hooks are loaded into interactive bash shells to intercept
# common file modification commands on protected files.
#===============================================================================

GUARDIAN_DIR="$HOME/.guardrails"
PROTECTED_QWEN_FILES=("$HOME/.qwen/settings.json" "$HOME/.qwen/config.json" "$HOME/.qwen/QWEN.md")

# Function to check if file is protected (with symlink resolution)
is_protected_file() {
    local file="$1"
    local resolved=""
    
    # Resolve symlinks to prevent symlink attacks
    if command -v realpath &>/dev/null; then
        resolved=$(realpath -m "$file" 2>/dev/null) || resolved="$file"
    elif command -v readlink &>/dev/null; then
        resolved=$(readlink -f "$file" 2>/dev/null) || resolved="$file"
    else
        resolved="$file"
    fi
    
    for protected in "${PROTECTED_QWEN_FILES[@]}"; do
        local protected_resolved=""
        if command -v realpath &>/dev/null; then
            protected_resolved=$(realpath -m "$protected" 2>/dev/null) || protected_resolved="$protected"
        else
            protected_resolved="$protected"
        fi
        
        if [[ "$resolved" == "$protected_resolved" ]] || [[ "$resolved" == "$protected_resolved/"* ]]; then
            return 0
        fi
    done
    return 1
}

# Intercept common file modification commands
_guardian_check() {
    local cmd="$1"
    local file="$2"
    
    if is_protected_file "$file"; then
        echo "🚨 GUARDIAN: Protected file modification attempt!"
        echo "   File: $file"
        echo "   Command: $cmd"
        echo ""
        echo "   Agents MUST run: guardian-request $file '<reason>'"
        echo "   Users can run: guardian-temp-unlock $file"
        return 1
    fi
    return 0
}

# Override built-in commands (readonly to prevent unsetting)
rm() {
    for arg in "$@"; do
        if [[ "$arg" != -* ]] && is_protected_file "$arg"; then
            echo "🚨 GUARDIAN: Cannot delete protected file: $arg"
            echo "   This file is protected by the Guardian system."
            echo "   To temporarily unlock, run: guardian-temp-unlock $arg"
            return 1
        fi
    done
    command rm "$@"
}

cp() {
    local args=("$@")
    local last_arg="${args[-1]}"
    if is_protected_file "$last_arg"; then
        echo "🚨 GUARDIAN: Cannot overwrite protected file: $last_arg"
        echo "   To temporarily unlock, run: guardian-temp-unlock $last_arg"
        return 1
    fi
    command cp "$@"
}

mv() {
    local args=("$@")
    local last_arg="${args[-1]}"
    if is_protected_file "$last_arg"; then
        echo "🚨 GUARDIAN: Cannot overwrite protected file: $last_arg"
        echo "   To temporarily unlock, run: guardian-temp-unlock $last_arg"
        return 1
    fi
    command mv "$@"
}

cat() {
    if [[ "$*" == *">"* ]]; then
        local in_redirect=0
        for arg in "$@"; do
            if [[ "$arg" == ">" || "$arg" == ">>" ]]; then
                in_redirect=1
            elif [[ $in_redirect -eq 1 ]] && is_protected_file "$arg"; then
                echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
                echo "   Use: guardian-request $arg '<reason>'"
                return 1
            else
                in_redirect=0
            fi
        done
    fi
    command cat "$@"
}

tee() {
    for arg in "$@"; do
        if [[ "$arg" != -* ]] && is_protected_file "$arg"; then
            echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
            echo "   Use: guardian-request $arg '<reason>'"
            return 1
        fi
    done
    command tee "$@"
}

echo() {
    if [[ "$*" == *">"* ]]; then
        local in_redirect=0
        for arg in "$@"; do
            if [[ "$arg" == ">" || "$arg" == ">>" ]]; then
                in_redirect=1
            elif [[ $in_redirect -eq 1 ]] && is_protected_file "$arg"; then
                echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
                echo "   Use: guardian-request $arg '<reason>'"
                return 1
            else
                in_redirect=0
            fi
        done
    fi
    command echo "$@"
}

# CRITICAL: Override sudo to intercept dangerous commands
# This is a FUNCTION, not an alias, to prevent bypass via 'command sudo'
sudo() {
    local cmd="$*"
    
    # Check for dangerous patterns that should be blocked
    local DANGEROUS_PATTERNS=(
        "chattr[[:space:]]+-[a-zA-Z]*i"
        "chattr[[:space:]]+-I"
        "rm[[:space:]]+-rf.*\.qwen"
        "rm[[:space:]]+-rf.*\.guardrails"
        "rm.*settings\.json"
        "rm.*config\.json"
        "rm.*guardian"
    )
    
    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
        if echo "$cmd" | grep -qE "$pattern"; then
            echo "🚨 GUARDIAN: Dangerous command detected!"
            echo "   Command: sudo $cmd"
            echo ""
            echo "   This command requires EXPLICIT user approval."
            echo ""
            echo "   Agents: Run 'guardian-request <file> <reason>'"
            echo "   Users:  Run 'guardian-temp-unlock <file>'"
            echo ""
            return 1
        fi
    done
    
    # Not a dangerous command, pass through to real sudo
    command sudo "$@"
}

# CRITICAL: Make all hook functions readonly to prevent unsetting
# This must be done AFTER all functions are defined
readonly -f is_protected_file _guardian_check rm cp mv cat tee echo sudo 2>/dev/null || true

# Show warning on shell start (only once per session)
if [ -z "$GUARDIAN_WARNING_SHOWN" ]; then
    export GUARDIAN_WARNING_SHOWN=1
fi
