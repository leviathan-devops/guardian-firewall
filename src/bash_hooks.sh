# Guardian Bash Hooks v2.0
# Source this in .bashrc to enable file operation interception
#
# CRITICAL: User sovereignty is ALWAYS preserved.
# User shell configs (.bashrc, .profile, etc.) are NEVER intercepted.

GUARDIAN_DIR="$HOME/.guardrails"

# Files that are protected from AI agents
PROTECTED_FILES=(
    "$HOME/.qwen/settings.json"
    "$HOME/.qwen/config.json"
    "$HOME/.qwen/QWEN.md"
)

# Files that are NEVER protected (user sovereignty)
USER_SOVEREIGN_FILES=(
    "$HOME/.bashrc"
    "$HOME/.bash_aliases"
    "$HOME/.bash_profile"
    "$HOME/.bash_logout"
    "$HOME/.profile"
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.zshenv"
    "$HOME/.zlogin"
    "$HOME/.ssh"
    "$HOME/.gnupg"
)

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

# Check if a file is protected
is_protected_file() {
    local file="$1"
    local resolved=""
    
    # Resolve path
    if command -v realpath &>/dev/null; then
        resolved=$(realpath "$file" 2>/dev/null || echo "$file")
    else
        resolved="$file"
    fi
    
    # First check if it's user sovereign (user wins)
    for sovereign in "${USER_SOVEREIGN_FILES[@]}"; do
        if [[ "$resolved" == "$sovereign" ]] || [[ "$resolved" == "$sovereign/"* ]]; then
            return 1  # NOT protected - user sovereign
        fi
    done
    
    # Then check if it's in protected list
    for protected in "${PROTECTED_FILES[@]}"; do
        if [[ "$resolved" == "$protected" ]] || [[ "$resolved" == "$protected/"* ]]; then
            return 0  # IS protected
        fi
    done
    
    return 1  # NOT protected
}

# Check if a file is user sovereign
is_user_sovereign() {
    local file="$1"
    local resolved=""
    
    if command -v realpath &>/dev/null; then
        resolved=$(realpath "$file" 2>/dev/null || echo "$file")
    else
        resolved="$file"
    fi
    
    for sovereign in "${USER_SOVEREIGN_FILES[@]}"; do
        if [[ "$resolved" == "$sovereign" ]] || [[ "$resolved" == "$sovereign/"* ]]; then
            return 0
        fi
    done
    
    return 1
}

#===============================================================================
# COMMAND OVERRIDES
#===============================================================================

# Override rm to protect files
rm() {
    for arg in "$@"; do
        # Skip options
        [[ "$arg" == -* ]] && continue
        
        if is_user_sovereign "$arg"; then
            # User file - let it through
            :
        elif is_protected_file "$arg"; then
            echo "🚨 GUARDIAN: Cannot delete protected file: $arg"
            echo "   This file is protected from AI agent modification."
            echo ""
            echo "   If you are the human user:"
            echo "     guardian-emergency unlock-all"
            echo ""
            echo "   If you are an AI agent:"
            echo "     guardian request $arg 'Need to delete for <reason>'"
            return 1
        fi
    done
    command rm "$@"
}

# Override cp to protect destinations
cp() {
    local args=("$@")
    local last_arg="${args[-1]}"
    
    # Handle multiple destination case (cp file1 file2 dir/)
    if [[ -d "$last_arg" ]]; then
        # Check each source
        for arg in "$@"; do
            [[ "$arg" == -* ]] && continue
            [[ "$arg" == "$last_arg" ]] && continue
            
            if is_protected_file "$arg" && ! is_user_sovereign "$arg"; then
                echo "🚨 GUARDIAN: Protected file copy blocked"
                echo "   Source: $arg"
                return 1
            fi
        done
    else
        # Single file case
        if is_user_sovereign "$last_arg"; then
            # User file - let it through
            :
        elif is_protected_file "$last_arg"; then
            echo "🚨 GUARDIAN: Cannot overwrite protected file: $last_arg"
            echo "   Run: guardian request $last_arg '<reason>'"
            return 1
        fi
    fi
    
    command cp "$@"
}

# Override mv to protect destinations
mv() {
    local args=("$@")
    local last_arg="${args[-1]}"
    
    # Check destination
    if is_user_sovereign "$last_arg"; then
        # User file - let it through
        :
    elif is_protected_file "$last_arg"; then
        echo "🚨 GUARDIAN: Cannot overwrite protected file: $last_arg"
        echo "   Run: guardian request $last_arg '<reason>'"
        return 1
    fi
    
    command mv "$@"
}

# Override tee
tee() {
    for arg in "$@"; do
        [[ "$arg" == -* ]] && continue
        
        if is_user_sovereign "$arg"; then
            # User file - let it through
            :
        elif is_protected_file "$arg"; then
            echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
            echo "   Run: guardian request $arg '<reason>'"
            return 1
        fi
    done
    command tee "$@"
}

# Override cat for write operations (cat > file)
cat() {
    # Check for write redirection
    if [[ "$*" == *">"* ]] || [[ "$*" == *">>"* ]]; then
        # Extract file argument (last non-option argument before >)
        for arg in "$@"; do
            [[ "$arg" == -* ]] && continue
            [[ "$arg" == ">" ]] || [[ "$arg" == ">>" ]] && continue
            
            if is_user_sovereign "$arg"; then
                # User file - let it through
                :
            elif is_protected_file "$arg"; then
                echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
                echo "   Run: guardian request $arg '<reason>'"
                return 1
            fi
        done
    fi
    command cat "$@"
}

# Override echo for write operations (echo "text" > file)
echo() {
    if [[ "$*" == *">"* ]] || [[ "$*" == *">>"* ]]; then
        # Extract file argument
        local prev_arg=""
        for arg in "$@"; do
            if [[ "$prev_arg" == ">" ]] || [[ "$prev_arg" == ">>" ]]; then
                if is_user_sovereign "$arg"; then
                    # User file - let it through
                    :
                elif is_protected_file "$arg"; then
                    echo "🚨 GUARDIAN: Cannot write to protected file: $arg"
                    echo "   Run: guardian request $arg '<reason>'"
                    return 1
                fi
            fi
            prev_arg="$arg"
        done
    fi
    command echo "$@"
}

#===============================================================================
# SUDO WRAPPER (optional - intercepts dangerous sudo commands)
#===============================================================================

# Only override sudo if wrapper exists
if [ -f "$GUARDIAN_DIR/bin/sudo" ]; then
    # This creates an alias for sudo
    # Note: Users can bypass with /usr/bin/sudo if needed
    alias sudo="$GUARDIAN_DIR/bin/sudo"
fi

#===============================================================================
# EMERGENCY COMMAND (always available)
#===============================================================================

# Quick emergency function (in case /usr/bin/guardian-emergency isn't available)
guardian-recover() {
    echo "🔓 Unlocking all user files..."
    
    USER_FILES=(
        "$HOME/.bashrc"
        "$HOME/.bash_aliases"
        "$HOME/.bash_profile"
        "$HOME/.profile"
        "$HOME/.zshrc"
    )
    
    for f in "${USER_FILES[@]}"; do
        if [ -f "$f" ]; then
            /usr/bin/sudo chattr -i "$f" 2>/dev/null && \
                echo "  ✓ Unlocked: $f" || true
        fi
    done
    
    echo ""
    echo "✅ User files should now be editable."
    echo "   If still locked, run: guardian-emergency unlock-all"
}

#===============================================================================
# STARTUP MESSAGE
#===============================================================================

# Show guardian status once per session (optional - can be disabled)
if [ -z "$GUARDIAN_QUIET" ] && [ -z "$GUARDIAN_MESSAGE_SHOWN" ]; then
    export GUARDIAN_MESSAGE_SHOWN=1
    
    # Check if any protected files are actually protected
    PROTECTED_COUNT=0
    for f in "${PROTECTED_FILES[@]}"; do
        if [ -f "$f" ]; then
            if command lsattr -d "$f" 2>/dev/null | cut -d' ' -f1 | grep -q 'i'; then
                ((PROTECTED_COUNT++))
            fi
        fi
    done
    
    if [ $PROTECTED_COUNT -gt 0 ]; then
        echo "🔒 Guardian: $PROTECTED_COUNT files protected | guardian status for details"
    fi
fi
