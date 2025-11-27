# OS Compatibility Layer - Feature Branch

## Overview

This branch (`feature/os-compatibility`) introduces a comprehensive OS compatibility layer that enables all scripts to work seamlessly on both **macOS** and **Linux** systems.

## Problem Statement

The original scripts had several platform-specific issues:

1. **`grep -P`** (Perl regex) is not available on macOS
2. **`base64`** has different flags on macOS (`-D`) vs Linux (`-d`)
3. **`sed -i`** requires different syntax on macOS (needs `''`) vs Linux
4. **Resource calculation** used inline `awk` that failed in heredocs
5. **Various GNU tools** have different behaviors/flags

## Solution

### New OS Compatibility Library

**Location**: `lib/utils/os-compat.sh`

This library provides:
- **Automatic OS detection** (macOS, Linux, or unknown)
- **Cross-platform command wrappers** that use appropriate tools per OS
- **Utility functions** for common operations
- **Portable arithmetic functions** for resource calculations

### Key Features

#### 1. OS Detection
```bash
# Automatically detects OS on script load
source lib/utils/os-compat.sh
echo $OS_TYPE  # Outputs: "macos" or "linux"
```

#### 2. Grep Compatibility
```bash
# Instead of: grep -P 'pattern' (fails on macOS)
# Use: grep_perl 'pattern'
grep_perl 'tool-call-parser=\w+' file.txt

# Extract text after a prefix
parser=$(grep_extract "tool-call-parser=" "text with tool-call-parser=hermes")
# Returns: hermes
```

#### 3. Base64 Compatibility
```bash
# Instead of: echo -n "text" | base64 (different on macOS/Linux)
# Use: base64_encode "text"
encoded=$(base64_encode "my secret string")

# Decode
decoded=$(base64_decode "$encoded")
```

#### 4. Sed In-Place Editing
```bash
# Instead of: sed -i 's/old/new/' file (requires '' on macOS)
# Use: sed_inplace 's/old/new/' file
sed_inplace 's/pattern/replacement/g' myfile.txt
```

#### 5. Resource Calculations
```bash
# Calculate half of a value with minimum
half=$(calc_half 16 1)  # Returns: 8 (minimum 1)

# Parse memory from Kubernetes format
mem=$(parse_memory_gi "16Gi")  # Returns: 16

# Parse CPU (handles both integers and millicores)
cpu=$(parse_cpu "4")     # Returns: 4
cpu=$(parse_cpu "4000m") # Returns: 4
```

#### 6. Date/Time Operations
```bash
# ISO 8601 timestamp
timestamp=$(date_iso8601)

# Unix timestamp
epoch=$(date_timestamp)
```

#### 7. Other Utilities
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

### Updated Scripts

The following scripts have been updated to use the OS compatibility layer:

1. **`lib/functions/model-deployment.sh`**
   - Uses `grep_extract` instead of `grep -P`
   - Uses `base64_encode` for model URI encoding
   - Uses `calc_half`, `parse_memory_gi`, `parse_cpu` for resource calculations

2. **`lib/functions/rhoai.sh`**
   - Uses OS-compatible functions for Kueue ResourceFlavor configuration

3. **`integrated-workflow-v2.sh`**
   - Improved dashboard route creation logic
   - Better error handling

## Changes Summary

### New Files
- **`lib/utils/os-compat.sh`**: Complete OS compatibility library
- **`docs/fixes/MACOS-GREP-AWK-FIX.md`**: Documentation for macOS grep/awk fix
- **`docs/fixes/DASHBOARD-ROUTE-FIX.md`**: Documentation for dashboard route timing issue
- **`OS-COMPATIBILITY-README.md`**: This file

### Modified Files
- **`lib/functions/model-deployment.sh`**: Updated to use OS compatibility functions
- **`lib/functions/rhoai.sh`**: Added ResourceFlavor auto-creation for Unmanaged Kueue
- **`integrated-workflow-v2.sh`**: Improved dashboard wait logic with automatic route creation
- **`docs/TROUBLESHOOTING.md`**: Added dashboard route issue troubleshooting

## Testing

### On macOS
```bash
# 1. Source the library
source lib/utils/os-compat.sh

# 2. Verify OS detection
echo "Detected OS: $OS_TYPE"  # Should show: macos

# 3. Test functions
base64_encode "test string"
calc_half 16
parse_memory_gi "16Gi"

# 4. Run model deployment
./scripts/quick-deploy-model.sh
```

### On Linux
```bash
# 1. Source the library
source lib/utils/os-compat.sh

# 2. Verify OS detection
echo "Detected OS: $OS_TYPE"  # Should show: linux

# 3. Test functions (same commands as macOS)
base64_encode "test string"
calc_half 16
parse_memory_gi "16Gi"

# 4. Run model deployment
./scripts/quick-deploy-model.sh
```

## Installation

### Prerequisites Check

The OS compatibility library includes a function to check for required tools:

```bash
source lib/utils/os-compat.sh
check_required_tools
```

### macOS Recommendations

For best compatibility on macOS, install GNU coreutils (optional but recommended):

```bash
brew install coreutils
```

This provides:
- `greadlink` (for full path resolution)
- `gtimeout` (for timeout functionality)
- And other GNU tools with `g` prefix

**Note**: The library works **without** these tools by using fallback methods (perl, python), but GNU tools provide better performance and compatibility.

## Benefits

1. ✅ **Write once, run anywhere**: Scripts work on both macOS and Linux
2. ✅ **Consistent behavior**: Same output regardless of OS
3. ✅ **Easy to use**: Simple function calls replace complex OS detection logic
4. ✅ **Maintainable**: All OS-specific logic centralized in one library
5. ✅ **Extensible**: Easy to add new cross-platform functions
6. ✅ **Backward compatible**: Existing scripts continue to work

## Migration Guide

To update existing scripts to use the OS compatibility layer:

### 1. Source the library
```bash
# Add at the top of your script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/path/to/lib/utils/os-compat.sh"
```

### 2. Replace platform-specific commands

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

### 3. Use utility functions for calculations
```bash
# Old way (inline awk in heredoc - breaks on macOS)
cpu_request=$(echo "$cpu_limit" | awk '{print int($1/2) > 0 ? int($1/2) : 1}')

# New way (portable function)
cpu_request=$(calc_half $(parse_cpu "$cpu_limit") 1)
```

## Future Enhancements

Potential additions to the OS compatibility layer:

1. **Network tools**: `nc`, `netstat` compatibility
2. **Process tools**: `ps`, `top` output parsing
3. **Package managers**: Unified interface for `brew`/`apt`/`yum`
4. **Service management**: `systemctl` vs `launchctl`
5. **Docker/Podman**: Container runtime detection and compatibility

## Merging to Main

Before merging this branch to `main`:

1. ✅ All scripts updated to use OS compatibility functions
2. ✅ Documentation updated
3. ✅ Tested on both macOS and Linux
4. ⏳ CI/CD pipeline tests pass (if available)
5. ⏳ User acceptance testing complete

## Rollback Plan

If issues arise after merging:

1. Revert to previous commit:
   ```bash
   git revert HEAD
   ```

2. Or checkout the previous state:
   ```bash
   git checkout main
   ```

3. The library is **additive** - it doesn't modify existing behavior unless explicitly used, so risk is low.

## Support

For issues or questions about the OS compatibility layer:

1. Check documentation in `lib/utils/os-compat.sh` (inline comments)
2. Review `docs/fixes/MACOS-GREP-AWK-FIX.md`
3. Test with `print_os_info` and `check_required_tools`

## Changelog

### Version 1.0 (Nov 27, 2025)

**Added**:
- Complete OS compatibility library (`lib/utils/os-compat.sh`)
- Automatic OS detection
- Cross-platform command wrappers (grep, base64, sed, date, timeout, readlink, stat)
- Resource calculation utilities (calc_half, parse_memory_gi, parse_cpu)
- Tool availability checking

**Fixed**:
- Model deployment failing on macOS with `grep -P` error
- `awk` syntax errors in resource calculation
- Dashboard route not being created on fresh RHOAI 3.0 installs
- Kueue ResourceFlavor not being created when managementState is "Unmanaged"

**Updated**:
- `lib/functions/model-deployment.sh`: Use OS compatibility functions
- `lib/functions/rhoai.sh`: Auto-create ResourceFlavor for Unmanaged Kueue
- `integrated-workflow-v2.sh`: Improved dashboard readiness detection
- `docs/TROUBLESHOOTING.md`: Added new issues and solutions

## Contributors

- Initial implementation: Based on CAI guide for RHOAI 3.0
- OS compatibility layer: Developed to address macOS/Linux differences
- Testing: Verified on macOS 14+ and RHEL 9+

---

**Branch**: `feature/os-compatibility`  
**Status**: Ready for testing and review  
**Target**: `main` branch

