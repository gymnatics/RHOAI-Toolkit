# Archive - Legacy Scripts

This folder contains scripts that are no longer needed for fresh installations but may be useful for troubleshooting or fixing existing installations.

## Scripts

### fix-macos-security.sh
**Status**: ❌ Deprecated

**Purpose**: Removed macOS quarantine attribute from downloaded `openshift-install` binary.

**Why Deprecated**: This functionality is now built into `openshift-installer-master.sh`. The main script automatically handles the quarantine attribute removal, so this standalone script is no longer needed.

**Use Case**: None for fresh installations. Kept for historical reference.

---

### fix-rhcl-operator.sh
**Status**: ⚠️ Legacy (may be useful for troubleshooting)

**Purpose**: Fixes RHCL operator installations that used the incorrect OperatorGroup configuration (OwnNamespace instead of AllNamespaces).

**Why Legacy**: 
- All main scripts now use the correct OperatorGroup configuration
- Fresh installations won't have this issue
- Only needed if you have an existing broken RHCL installation from old scripts

**When to Use**:
- If you have an existing cluster with RHCL operator that shows:
  ```
  Warning: UnsupportedOperatorGroup - OwnNamespace InstallModeType not supported
  ```
- If RHCL operator CSV shows "Failed" status
- If Authorino service is not being created

**How to Use**:
```bash
./archive/fix-rhcl-operator.sh
```

This will:
1. Clean up the broken RHCL installation
2. Recreate with correct AllNamespaces OperatorGroup
3. Wait for operator to be ready
4. Create Kuadrant and Authorino instances

---

## Why These Are Archived

These scripts represent fixes for issues that have been resolved in the main installation scripts:

1. **Integrated Fixes**: The fixes are now part of the main scripts
2. **Prevention**: New installations won't encounter these issues
3. **Historical Value**: Kept for reference and troubleshooting existing installations
4. **Clean Root**: Keeps the main directory focused on current, actively-used scripts

## For Fresh Installations

**Don't use these scripts!** Instead, use:
- `./integrated-workflow.sh` - Includes correct RHCL setup
- `./openshift-installer-master.sh` - Includes macOS security handling

## For Existing Installations

If you have an existing installation with issues:
1. Check `docs/TROUBLESHOOTING.md` first
2. Run diagnostics: `./diagnostics/diagnose-authorino.sh`
3. If you have the specific issues mentioned above, these scripts may help

---

**Last Updated**: November 2025

