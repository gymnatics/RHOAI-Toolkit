# Repository Cleanup Summary

**Date:** November 26, 2024  
**Action:** Git history rewrite and sensitive file removal  
**Status:** ✅ Complete

---

## What Happened

On November 25, 2024, your repository underwent a git history rewrite using `git-filter-repo` to remove sensitive files and large binaries from the git history. This cleanup was necessary because sensitive credentials and large binary files had been committed to git, which is a security risk and bloats the repository size.

### Files Removed from Git History

#### 🔒 Sensitive Files (Security Risk)
- `pull-secret.txt` - OpenShift pull secret credentials
- `cluster-info.txt` - Cluster access credentials
- `openshift-cluster-install/` - Installation artifacts with secrets
- Generated MachineSet YAMLs with cluster-specific data

#### 📦 Large Binary Files (Size Reduction)
- `openshift-install` - Binary executable (556MB)
- `openshift-install-4.19.tar.gz` - Archived installer (354MB)

#### 📄 Documentation Files
- `CAI's guide to RHOAI 3.0.pdf` (2.3MB)
- `CAI's guide to RHOAI 3.0.txt`
- `reference-repo/` - Reference git repository

#### 📁 Backup Directories Deleted
- `Openshift-installation-backup` (1.9GB)
- `Openshift-installation-backup-20251125-170101` (950MB)
- `Openshift-installation-fresh` (1.8GB)
- `Openshift-installation-backups-archive-20251126.tar.gz` (3.5GB)

**Total space freed:** ~8.15GB

---

## Current Repository Status

### ✅ What's Clean Now
- **Repository size:** 1.6MB (down from gigabytes!)
- **Git history:** Rewritten with 20 commits preserved
- **Sensitive files:** Completely removed from history
- **Working tree:** Clean, no uncommitted changes

### 📝 What Was Preserved
All your important scripts, configurations, and documentation:
- ✅ All shell scripts (`complete-setup.sh`, `integrated-workflow-v2.sh`, etc.)
- ✅ All YAML manifests in `lib/manifests/`
- ✅ All documentation in `docs/`, `README.md`, etc.
- ✅ All utility scripts in `scripts/`
- ✅ Complete git commit history (with rewritten hashes)

### 🆕 What Was Added
- `scripts/scan-for-secrets.sh` - Security scanning script (recovered from backup)

---

## Important Changes to Workflow

### 🔧 OpenShift Installer Binary

**Before:** The `openshift-install` binary was included in the repository  
**Now:** You need to download it when needed

#### How to Get the Installer

**Option 1: Using the Built-in Menu**
```bash
./scripts/openshift-installer-master.sh
# Select option 4 to download the installer
```

**Option 2: Direct Download**
```bash
# Will automatically detect your platform and download
cd /Users/dayeo/Openshift-installation
curl -L --insecure -o openshift-install-4.19.tar.gz \
  https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.19/openshift-install-mac-arm64.tar.gz
tar -xzf openshift-install-4.19.tar.gz
chmod +x openshift-install
```

**Option 3: From Red Hat Console**
Visit: https://console.redhat.com/openshift/install

### 🔐 Sensitive Files (.gitignore Protection)

Your `.gitignore` file now properly excludes sensitive files:

```gitignore
# Sensitive Files
pull-secret.txt
cluster-info.txt
CAI's guide to RHOAI 3.0.*
*.pem
*.key
id_rsa*
*.kubeconfig
kubeadmin-password

# OpenShift Installer Binaries
openshift-install
*.tar.gz
*.zip

# Installation Artifacts
openshift-cluster-install/
```

**Store sensitive files outside the repository** or ensure they're gitignored.

---

## How to Use the Repository Now

### 🚀 Quick Start

1. **Download the OpenShift Installer** (if needed):
   ```bash
   ./scripts/openshift-installer-master.sh
   # Select option 4
   ```

2. **Run Complete Setup**:
   ```bash
   ./complete-setup.sh
   ```
   
   If you see an error about missing installer, the script will now offer to download it automatically!

3. **Or Use Individual Scripts**:
   ```bash
   # For existing cluster
   ./scripts/setup-llmd.sh
   ./scripts/deploy-llmd-model.sh
   ./scripts/create-hardware-profile.sh
   ```

### 🔍 Checking for Exposed Secrets

#### Manual Scan
Run the security scanner anytime:
```bash
./scripts/scan-for-secrets.sh
```

This will check for:
- AWS Access Keys
- AWS Secret Keys
- OpenShift Pull Secrets
- Private Keys
- Kubeconfig files
- And more...

#### Automatic Pre-Commit Hook (Recommended!)

Install a pre-commit hook that automatically scans before each commit:

```bash
# Install the hook (already installed by default)
./scripts/install-pre-commit-hook.sh --install

# Check status
./scripts/install-pre-commit-hook.sh --status

# Test it
./scripts/install-pre-commit-hook.sh --test
```

**What the pre-commit hook does:**
- ✅ Runs automatically before EVERY commit
- ✅ Scans staged files for sensitive data
- ✅ Blocks commits containing secrets
- ✅ Warns about large files (>5MB)
- ✅ Prevents accidental credential leaks

**The hook checks for:**
1. Sensitive filenames (pull-secret, kubeconfig, *.pem, *.key, etc.)
2. AWS credentials (access keys, secret keys)
3. OpenShift pull secrets
4. Private keys (RSA, EC, SSH, OPENSSH)
5. Passwords and tokens
6. Large files (>5MB)

**Example output when blocking a commit:**
```
╔════════════════════════════════════════════════════════════════╗
║         Pre-Commit Security Check: Scanning for Secrets       ║
╚════════════════════════════════════════════════════════════════╝

Scanning staged files:
  - pull-secret.txt

1. Checking for sensitive filenames...
✗ Found sensitive filename pattern: pull-secret
    pull-secret.txt

✗ COMMIT BLOCKED: Found 1 potential security issue(s)

What to do:
  1. Review the files listed above
  2. Remove any sensitive data
  3. Add sensitive files to .gitignore
  4. Run 'git add' again after fixing
  5. Try committing again

To bypass (NOT RECOMMENDED):
  git commit --no-verify
```

---

## Git Operations Going Forward

### 📤 Pushing to Remote

Since the git history was rewritten, you'll need to force push **once** to update the remote:

```bash
git push --force-with-lease origin main
```

⚠️ **Warning:** Only do this if you're the only user of this repository, or coordinate with your team!

After the initial force push, normal git operations will work:
```bash
git add .
git commit -m "Your message"
git push origin main
```

### 🔄 Checking Repository Status

```bash
# Check current status
git status

# Check if up to date with remote
git fetch origin
git status

# View recent commits
git log --oneline -10
```

### 🌿 Working with Branches

All branches were preserved during the history rewrite:
```bash
# List branches
git branch -a

# Switch branches
git checkout <branch-name>
```

---

## Best Practices Going Forward

### ✅ DO:
- ✅ Keep sensitive files (.txt, .json with credentials) outside the repo
- ✅ Download `openshift-install` binary when needed
- ✅ Use `.gitignore` to prevent committing sensitive files
- ✅ Run `./scripts/scan-for-secrets.sh` before committing
- ✅ Store cluster credentials in `~/.openshift/` or other secure locations

### ❌ DON'T:
- ❌ Commit `pull-secret.txt` or any credentials
- ❌ Commit the `openshift-install` binary (it's large and downloadable)
- ❌ Commit `cluster-info.txt` or kubeconfig files
- ❌ Commit large PDFs or binary files
- ❌ Force push without `--force-with-lease` (less safe)

---

## Managing Kubeconfig

### 🔧 New Utility: Kubeconfig Manager

A dedicated script to manage your kubeconfig files and environment:

```bash
# Interactive menu
./scripts/manage-kubeconfig.sh

# Quick commands
./scripts/manage-kubeconfig.sh --show      # Show current config
./scripts/manage-kubeconfig.sh --clear     # Clear kubeconfig
./scripts/manage-kubeconfig.sh --logout    # Logout from cluster
./scripts/manage-kubeconfig.sh --set       # Set kubeconfig file
```

### Common Scenarios

**Switching Clusters:**
```bash
# Show current cluster
./scripts/manage-kubeconfig.sh --show

# Logout from current cluster
./scripts/manage-kubeconfig.sh --logout

# Clear old kubeconfig
./scripts/manage-kubeconfig.sh --clear
```

**Stuck with Old Cluster:**
```bash
# Option 1: Use the manage script
./scripts/manage-kubeconfig.sh
# Select: 2) Clear kubeconfig
# Then: 2) Clear KUBECONFIG and remove the file

# Option 2: Manual clearing
unset KUBECONFIG
rm -f ~/.kube/config
```

**Setting New Kubeconfig:**
```bash
# After OpenShift installation
export KUBECONFIG=/path/to/new-cluster/auth/kubeconfig

# Or use the manager
./scripts/manage-kubeconfig.sh --set
```

---

## Troubleshooting

### Issue: "openshift-install binary not found"

**Solution 1:** The installer now offers to download automatically
```bash
./complete-setup.sh
# When prompted, select option 1 to download
```

**Solution 2:** Download manually via menu
```bash
./scripts/openshift-installer-master.sh
# Select option 4: Download/Update OpenShift Installer
```

**Solution 3:** Download directly
```bash
curl -L --insecure -o openshift-install-mac-arm64.tar.gz \
  https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.19/openshift-install-mac-arm64.tar.gz
tar -xzf openshift-install-mac-arm64.tar.gz
chmod +x openshift-install
```

### Issue: "AWS credentials not configured"

**Solution:**
```bash
aws configure
# Or
./scripts/diagnose-aws-credentials.sh
./scripts/refresh-aws-credentials.sh
```

### Issue: Scripts asking for files that were removed

These files should NOT be in git. They are created during installation:
- `pull-secret.txt` - Download from: https://console.redhat.com/openshift/install/pull-secret
- `cluster-info.txt` - Generated during OpenShift installation
- SSH keys - Generated via `ssh-keygen` or during installation

---

## Summary

✅ **Repository is now clean and secure**  
✅ **All important files preserved**  
✅ **Git history rewritten (sensitive data removed)**  
✅ **8.15GB of space freed**  
✅ **Workflows updated to handle missing binaries**  
✅ **Security scanning added**  

Your repository is ready to use and safe to share or push to remote repositories!

---

## Quick Reference Commands

```bash
# Check repository status
git status

# Scan for secrets before committing
./scripts/scan-for-secrets.sh

# Download OpenShift installer
./scripts/openshift-installer-master.sh  # Option 4

# Run complete setup
./complete-setup.sh

# View this document
cat REPOSITORY-CLEANUP-SUMMARY.md
```

---

**Questions?** Refer to:
- `README.md` - Main documentation
- `docs/TROUBLESHOOTING.md` - Common issues
- `QUICK-REFERENCE.md` - Command quick reference

