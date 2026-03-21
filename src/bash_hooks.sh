# Guardian Bash Hooks
# Source this in .bashrc to enable file operation interception

GUARDIAN_DIR="$HOME/.guardrails"
PROTECTED_QWEN_FILES=("$HOME/.qwen/settings.json" "$HOME/.qwen/config.json" "$HOME/.qwen/QWEN.md" "$HOME/.guardrails/")

# Function to check if file is protected
is_protected_file() {
    local file="$1"
    for protected in "${PROTECTED_QWEN_FILES[@]}"; do
        if [[ "$file" == "$protected" ]] || [[ "$file" == "$protected"* ]]; then
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

# Override rm to protect files
rm() {
    for arg in "$@"; do
        if is_protected_file "$arg"; then
            echo "🚨 GUARDIAN: Cannot delete protected file: $arg"
            echo "   This file is protected by the Guardian system."
            echo "   To temporarily unlock, run: guardian-temp-unlock $arg"
            return 1
        fi
    done
    command rm "$@"
}

# Override cp to protect destinations
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

# Override mv to protect destinations
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

# Override cat redirection
cat() {
    if [[ "$*" == *">"* ]]; then
        for arg in "$@"; do
            if [[ "$arg" == ">" ]] || [[ "$arg" == ">>" ]]; then
                : # Next arg will be the file
            elif is_protected_file "$arg" && [[ "${args[-2]}" == ">" || "${args[-2]}" == ">>" ]]; then
                echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
                echo "   Use: guardian-request $arg '<reason>'"
                return 1
            fi
        done
    fi
    command cat "$@"
}

# Override tee
tee() {
    for arg in "$@"; do
        if is_protected_file "$arg"; then
            echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
            echo "   Use: guardian-request $arg '<reason>'"
            return 1
        fi
    done
    command tee "$@"
}

# Override echo with redirection
echo() {
    if [[ "$*" == *">"* ]]; then
        for arg in "$@"; do
            if is_protected_file "$arg" && [[ "$*" == *"> $arg"* || "$*" == *">>$arg"* ]]; then
                echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
                echo "   Use: guardian-request $arg '<reason>'"
                return 1
            fi
        done
    fi
    command echo "$@"
}

# Show warning on shell start (only once per session)
if [ -z "$GUARDIAN_WARNING_SHOWN" ]; then
    export GUARDIAN_WARNING_SHOWN=1
    # Silent - guardian is active but doesn't spam the user
fi

# CRITICAL: Alias sudo to prevent bypass via /usr/bin/sudo
# This must be sourced in .bashrc AFTER any agent modifications
if [ -f "$GUARDIAN_DIR/bin/sudo" ]; then
    alias sudo="$GUARDIAN_DIR/bin/sudo"
fi

# Also protect against direct /usr/bin/sudo calls
# by checking in real-path resolution
_guardian_realpath() {
    local path="$1"
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    elif command -v readlink &>/dev/null; then
        readlink -f "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}
