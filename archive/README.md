# Archive - Legacy and Historical Files

This folder contains scripts and documentation that are no longer needed for fresh installations but are kept for historical reference or troubleshooting existing installations.

## Why Files Are Archived

1. **Superseded**: Functionality integrated into `complete-setup.sh`
2. **Implementation Notes**: Development summaries not needed by end users
3. **Historical**: Documentation from feature development
4. **Troubleshooting**: May help fix issues in older installations

---

## Scripts

### fix-macos-security.sh
**Status**: ❌ Deprecated

Removed macOS quarantine attribute from `openshift-install` binary. This functionality is now built into the main installer.

### fix-rhcl-operator.sh
**Status**: ⚠️ Legacy

Fixes RHCL operator installations with incorrect OperatorGroup. Only needed for existing broken installations.

### integrated-workflow-v2.sh
**Status**: ❌ Superseded

Previous version of the workflow script. Use `complete-setup.sh` instead.

### quick-deploy-model.sh
**Status**: ❌ Superseded

Quick model deployment script. Use `complete-setup.sh` → Model Deployment instead.

---

## Documentation

### Implementation Summaries
These document what was implemented during development:

- `CONFIGURATION-REUSE-FEATURE.md` - Config reuse implementation details
- `RHOAI-3.0-FEATURES-SUMMARY.md` - RHOAI 3.0 feature implementation
- `REFACTOR-README.md`, `REFACTOR-SUMMARY.md`, `REFACTORING-COMPLETE.md` - Refactoring notes

### Hardware Profile Documentation
Historical documentation about hardware profile fixes:

- `HARDWARE-PROFILE-FINAL-FIX.md`
- `HARDWARE-PROFILE-GLOBAL-FIX.md`
- `HARDWARE-PROFILE-TROUBLESHOOTING.md`
- `HARDWARE-PROFILE-USAGE.md`
- `RHOAI-3.0-HARDWARE-PROFILE-FIX.md`

### Other Historical Docs
- `CHANGELOG-VPC-EARLY-DETECTION.md` - VPC detection changelog
- `CHANGES-NEEDED.md` - Historical change notes
- `INTERACTIVE-TAINT-FEATURE.md` - Taint feature implementation
- `LLMD-SETUP-COMPLETE.md` - llm-d setup notes
- `VERIFICATION-CHECKLIST.md` - Historical verification checklist

---

## For Fresh Installations

**Don't use archived scripts!** Instead, use:

```bash
./complete-setup.sh
```

This provides all functionality through an interactive menu.

---

## For Troubleshooting

If you have an existing installation with issues:

1. Check [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) first
2. Run diagnostics: `./diagnostics/diagnose-authorino.sh`
3. Check [docs/fixes/](../docs/fixes/) for specific issues
4. These archived files may provide additional context

---

**Last Updated**: January 2026
