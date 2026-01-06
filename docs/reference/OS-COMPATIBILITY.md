# OS Compatibility Layer

## Overview

This repository includes a comprehensive OS compatibility layer that enables all scripts to work seamlessly on both **macOS** and **Linux** systems.

## Problem Statement

The original scripts had several platform-specific issues:

1. **`grep -P`** (Perl regex) is not available on macOS
2. **`base64`** has different flags on macOS (`-D`) vs Linux (`-d`)
3. **`sed -i`** requires different syntax on macOS (needs `''`) vs Linux
4. **Resource calculation** used inline `awk` that failed in heredocs
5. **Various GNU tools** have different behaviors/flags

## Solution

### OS Compatibility Library

**Location**: `lib/utils/os-compat.sh`

This library provides:
- **Automatic OS detection** (macOS, Linux, or unknown)
- **Cross-platform command wrappers** that use appropriate tools per OS
- **Utility functions** for common operations
- **Portable arithmetic functions** for resource calculations

---

## Available Functions

### OS Detection
```bash
source lib/utils/os-compat.sh
echo $OS_TYPE  # Outputs: "macos" or "linux"
```

### Grep Compatibility
```bash
# Instead of: grep -P 'pattern' (fails on macOS)
grep_perl 'tool-call-parser=\w+' file.txt

# Extract text after a prefix
parser=$(grep_extract "tool-call-parser=" "text with tool-call-parser=hermes")
# Returns: hermes
```

### Base64 Compatibility
```bash
# Encode
encoded=$(base64_encode "my secret string")

# Decode
decoded=$(base64_decode "$encoded")
```

### Sed In-Place Editing
```bash
# Instead of: sed -i 's/old/new/' file (requires '' on macOS)
sed_inplace 's/pattern/replacement/g' myfile.txt
```

### Resource Calculations
```bash
# Calculate half of a value with minimum
half=$(calc_half 16 1)  # Returns: 8 (minimum 1)

# Parse memory from Kubernetes format
mem=$(parse_memory_gi "16Gi")  # Returns: 16

# Parse CPU (handles both integers and millicores)
cpu=$(parse_cpu "4")     # Returns: 4
cpu=$(parse_cpu "4000m") # Returns: 4
```

### Date/Time Operations
```bash
# ISO 8601 timestamp
timestamp=$(date_iso8601)

# Unix timestamp
epoch=$(date_timestamp)
```

### Other Utilities
```bash
# Timeout (uses gtimeout on macOS if available)
timeout_cmd 30 long_running_command

# Full path resolution
fullpath=$(readlink_full /path/to/symlink)

# File size
size=$(stat_size /path/to/file)

# Modification time
mtime=$(stat_mtime /path/to/file)
```

---

## Quick Reference

| Old Command | New Function | Notes |
|-------------|--------------|-------|
| `grep -P 'pattern'` | `grep_perl 'pattern'` | Perl regex |
| `echo "text" \| grep -oP '(?<=prefix)\w+'` | `grep_extract "prefix" "text"` | Extract after prefix |
| `echo -n "$text" \| base64` | `base64_encode "$text"` | Base64 encode |
| `echo "$enc" \| base64 -d/-D` | `base64_decode "$enc"` | Base64 decode |
| `sed -i 's/old/new/' file` | `sed_inplace 's/old/new/' file` | In-place edit |
| `date --iso-8601=seconds` | `date_iso8601` | ISO timestamp |
| `timeout 30 cmd` | `timeout_cmd 30 cmd` | Command timeout |
| `readlink -f path` | `readlink_full path` | Full path |
| `stat -c %s file` | `stat_size file` | File size |

---

## macOS Recommendations

For best compatibility on macOS, install GNU coreutils (optional but recommended):

```bash
brew install coreutils
```

This provides:
- `greadlink` (for full path resolution)
- `gtimeout` (for timeout functionality)
- And other GNU tools with `g` prefix

**Note**: The library works **without** these tools by using fallback methods (perl, python), but GNU tools provide better performance.

---

## Usage in Scripts

To use the OS compatibility layer in your scripts:

```bash
# Add at the top of your script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/path/to/lib/utils/os-compat.sh"

# Now use cross-platform functions
if [[ "$OS_TYPE" == "macos" ]]; then
    echo "Running on macOS"
fi

# Use portable functions
encoded=$(base64_encode "my data")
half_cpu=$(calc_half 8 1)
```

---

## Testing

```bash
# Source the library
source lib/utils/os-compat.sh

# Verify OS detection
echo "Detected OS: $OS_TYPE"

# Test functions
base64_encode "test string"
calc_half 16
parse_memory_gi "16Gi"

# Check required tools
check_required_tools
```

---

**Last Updated**: January 2026

