#!/bin/bash
################################################################################
# OS Compatibility Library
# 
# Provides cross-platform compatible implementations of common commands
# Automatically detects macOS vs Linux and uses appropriate tools
################################################################################

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Export OS type for use in other scripts
export OS_TYPE=$(detect_os)

################################################################################
# Grep Compatibility Functions
################################################################################

# grep_perl: Portable replacement for grep -P (Perl regex)
# Usage: grep_perl 'pattern' file
# Or: echo "text" | grep_perl 'pattern'
grep_perl() {
    local pattern="$1"
    shift
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: Use grep -E (extended regex) or sed/awk alternatives
        # For simple lookahead/lookbehind, convert to sed
        grep -E "$@"
    else
        # Linux: Use grep -P (Perl regex)
        grep -P "$pattern" "$@"
    fi
}

# grep_extract: Extract text matching a pattern
# Usage: grep_extract "tool-call-parser=" "hermes" "text with tool-call-parser=hermes"
# Returns: hermes
grep_extract() {
    local prefix="$1"
    local text="$2"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: Use sed
        echo "$text" | sed -n "s/.*${prefix}\([a-zA-Z0-9_-]*\).*/\1/p"
    else
        # Linux: Use grep -oP
        echo "$text" | grep -oP "(?<=${prefix})[a-zA-Z0-9_-]+"
    fi
}

################################################################################
# Base64 Compatibility
################################################################################

# base64_encode: Portable base64 encoding without newlines
# Usage: base64_encode "text to encode"
base64_encode() {
    local text="$1"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: base64 without -w flag
        echo -n "$text" | base64
    else
        # Linux: base64 with -w 0 (no line wrapping)
        echo -n "$text" | base64 -w 0
    fi
}

# base64_decode: Portable base64 decoding
# Usage: base64_decode "encoded_text"
base64_decode() {
    local encoded="$1"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: base64 -D
        echo "$encoded" | base64 -D
    else
        # Linux: base64 -d
        echo "$encoded" | base64 -d
    fi
}

################################################################################
# Sed Compatibility
################################################################################

# sed_inplace: In-place file editing that works on both macOS and Linux
# Usage: sed_inplace 's/old/new/g' file.txt
sed_inplace() {
    local pattern="$1"
    local file="$2"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: sed -i requires backup extension (use empty string '')
        sed -i '' "$pattern" "$file"
    else
        # Linux: sed -i works without backup extension
        sed -i "$pattern" "$file"
    fi
}

################################################################################
# Date/Time Compatibility
################################################################################

# date_iso8601: Get current date in ISO 8601 format
# Usage: date_iso8601
date_iso8601() {
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: Different date command syntax
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        # Linux: Standard date command
        date -u --iso-8601=seconds
    fi
}

# date_timestamp: Get Unix timestamp
# Usage: date_timestamp
date_timestamp() {
    if [ "$OS_TYPE" = "macos" ]; then
        date +%s
    else
        date +%s
    fi
}

################################################################################
# Timeout Command Compatibility
################################################################################

# timeout_cmd: Run command with timeout
# Usage: timeout_cmd 30 command args...
timeout_cmd() {
    local duration="$1"
    shift
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: Use gtimeout if available, otherwise use perl
        if command -v gtimeout &> /dev/null; then
            gtimeout "$duration" "$@"
        else
            # Fallback: Use perl-based timeout
            perl -e "alarm $duration; exec @ARGV" "$@"
        fi
    else
        # Linux: Standard timeout command
        timeout "$duration" "$@"
    fi
}

################################################################################
# Readlink Compatibility
################################################################################

# readlink_full: Get full path of a file (resolve symlinks)
# Usage: readlink_full /path/to/file
readlink_full() {
    local path="$1"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: Use greadlink if available, otherwise use perl
        if command -v greadlink &> /dev/null; then
            greadlink -f "$path"
        else
            # Fallback: Use python
            python3 -c "import os; print(os.path.realpath('$path'))"
        fi
    else
        # Linux: readlink -f
        readlink -f "$path"
    fi
}

################################################################################
# Stat Compatibility
################################################################################

# stat_size: Get file size in bytes
# Usage: stat_size /path/to/file
stat_size() {
    local file="$1"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: stat -f %z
        stat -f %z "$file"
    else
        # Linux: stat -c %s
        stat -c %s "$file"
    fi
}

# stat_mtime: Get file modification time (Unix timestamp)
# Usage: stat_mtime /path/to/file
stat_mtime() {
    local file="$1"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: stat -f %m
        stat -f %m "$file"
    else
        # Linux: stat -c %Y
        stat -c %Y "$file"
    fi
}

################################################################################
# Find Compatibility
################################################################################

# find_mtime: Find files modified in the last N days
# Usage: find_mtime /path -7  (files modified in last 7 days)
find_mtime() {
    local path="$1"
    local days="$2"
    
    if [ "$OS_TYPE" = "macos" ]; then
        # macOS: find uses -mtime with different behavior
        find "$path" -mtime "$days"
    else
        # Linux: Standard find
        find "$path" -mtime "$days"
    fi
}

################################################################################
# Utilities
################################################################################

# print_os_info: Display detected OS information
print_os_info() {
    echo "Detected OS: $OS_TYPE"
    echo "Kernel: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"
    
    if [ "$OS_TYPE" = "macos" ]; then
        echo "macOS Version: $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    elif [ "$OS_TYPE" = "linux" ]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "Linux Distribution: $NAME $VERSION"
        fi
    fi
}

# check_required_tools: Verify required tools are installed
check_required_tools() {
    local missing_tools=()
    
    # Common tools
    local common_tools=("oc" "kubectl" "jq" "curl" "git")
    
    for tool in "${common_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # macOS-specific recommendations
    if [ "$OS_TYPE" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo "⚠️  Warning: Homebrew not found. Install from https://brew.sh"
        fi
        
        # Check for GNU tools (optional but recommended)
        if ! command -v greadlink &> /dev/null; then
            echo "ℹ️  Optional: Install GNU coreutils for better compatibility: brew install coreutils"
        fi
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "❌ Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Install instructions:"
        if [ "$OS_TYPE" = "macos" ]; then
            echo "  brew install ${missing_tools[*]}"
        elif [ "$OS_TYPE" = "linux" ]; then
            echo "  # Ubuntu/Debian:"
            echo "  sudo apt-get install ${missing_tools[*]}"
            echo ""
            echo "  # RHEL/CentOS/Fedora:"
            echo "  sudo dnf install ${missing_tools[*]}"
        fi
        return 1
    fi
    
    return 0
}

################################################################################
# Arithmetic Compatibility
################################################################################

# calc_half: Calculate half of a number (integer division)
# Usage: calc_half 16
# Returns: 8
calc_half() {
    local value="$1"
    local min="${2:-1}"  # Minimum value, default 1
    
    # Use bash arithmetic (works on all platforms)
    local half=$(( value / 2 ))
    
    # Ensure minimum
    if [ "$half" -lt "$min" ]; then
        echo "$min"
    else
        echo "$half"
    fi
}

# parse_memory_gi: Extract numeric value from memory string like "16Gi"
# Usage: parse_memory_gi "16Gi"
# Returns: 16
parse_memory_gi() {
    local mem_string="$1"
    
    # Use bash regex matching (portable)
    if [[ "$mem_string" =~ ^([0-9]+)Gi$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$mem_string" =~ ^([0-9]+)$ ]]; then
        echo "$1"
    else
        echo "0"
    fi
}

# parse_cpu: Extract numeric value from CPU string
# Usage: parse_cpu "4" or parse_cpu "4000m"
# Returns: 4
parse_cpu() {
    local cpu_string="$1"
    
    # Handle plain numbers
    if [[ "$cpu_string" =~ ^([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    # Handle millicores (e.g., "4000m" = 4 cores)
    elif [[ "$cpu_string" =~ ^([0-9]+)m$ ]]; then
        local millicores="${BASH_REMATCH[1]}"
        echo "$(( millicores / 1000 ))"
    else
        echo "1"
    fi
}

################################################################################
# Export functions for use in other scripts
################################################################################

# Make all functions available to sourcing scripts
export -f detect_os
export -f grep_perl
export -f grep_extract
export -f base64_encode
export -f base64_decode
export -f sed_inplace
export -f date_iso8601
export -f date_timestamp
export -f timeout_cmd
export -f readlink_full
export -f stat_size
export -f stat_mtime
export -f find_mtime
export -f print_os_info
export -f check_required_tools
export -f calc_half
export -f parse_memory_gi
export -f parse_cpu

# Print OS info on first load (can be disabled by setting QUIET=1)
if [ -z "$QUIET" ] && [ -z "$OS_COMPAT_LOADED" ]; then
    # Only print once
    export OS_COMPAT_LOADED=1
fi

