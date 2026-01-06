# Kubeconfig Management Quick Reference

## Problem: Stuck with Old Cluster Configuration

### Symptoms
```bash
oc whoami
# Shows old/deleted cluster

oc get nodes
# Error: connection refused or timeout
```

### Solution Options

#### Option 1: Quick Fix (Interactive)
```bash
./scripts/manage-kubeconfig.sh
# Select: 2) Clear kubeconfig
# Then: 2) Clear KUBECONFIG and remove the file
```

#### Option 2: Command Line
```bash
# Show what's configured
./scripts/manage-kubeconfig.sh --show

# Clear it
./scripts/manage-kubeconfig.sh --clear

# Or manually
unset KUBECONFIG
rm -f ~/.kube/config
```

#### Option 3: Via Complete Setup
```bash
./rhoai-toolkit.sh
# When it detects existing cluster:
# Select: 3) Clear kubeconfig and install a new cluster
```

---

## Kubeconfig Manager Features

### Show Current Configuration
```bash
./scripts/manage-kubeconfig.sh --show
```
Shows:
- KUBECONFIG environment variable
- File location and status
- Current cluster connection
- User and context info

### Clear Kubeconfig
```bash
./scripts/manage-kubeconfig.sh --clear
```
Options:
1. Clear KUBECONFIG variable only (session)
2. Clear KUBECONFIG and remove file
3. Remove default kubeconfig (~/.kube/config)
4. Clear KUBECONFIG and remove from shell profile

### Logout from Cluster
```bash
./scripts/manage-kubeconfig.sh --logout
```
Removes current context and logs out

### Set Kubeconfig File
```bash
./scripts/manage-kubeconfig.sh --set
```
Sets KUBECONFIG to a specific file

---

## Common Scenarios

### Scenario 1: Switching Clusters
```bash
# Step 1: Check current cluster
./scripts/manage-kubeconfig.sh --show

# Step 2: Logout
./scripts/manage-kubeconfig.sh --logout

# Step 3: Set new kubeconfig
export KUBECONFIG=/path/to/new-cluster/auth/kubeconfig

# Step 4: Verify
oc whoami
```

### Scenario 2: Old Cluster Deleted, Can't Connect
```bash
# Quick fix
./scripts/manage-kubeconfig.sh --clear
# Select option 2

# Then set new cluster
./rhoai-toolkit.sh
```

### Scenario 3: Multiple Clusters
```bash
# Cluster 1
export KUBECONFIG=~/cluster1/auth/kubeconfig
oc get nodes

# Cluster 2
export KUBECONFIG=~/cluster2/auth/kubeconfig
oc get nodes

# Or use the manager
./scripts/manage-kubeconfig.sh --set
```

### Scenario 4: Clean Slate for New Installation
```bash
# Option 1: Complete clear
./scripts/manage-kubeconfig.sh
# Select: 2) Clear kubeconfig
# Then: 4) Clear KUBECONFIG and remove from shell profile

# Option 2: Via complete-setup
./rhoai-toolkit.sh
# It will detect and offer to clear
```

---

## Environment Variable Persistence

### Temporary (Current Session Only)
```bash
export KUBECONFIG=/path/to/kubeconfig
```

### Permanent (Add to Shell Profile)
```bash
# For zsh (macOS default)
echo 'export KUBECONFIG=/path/to/kubeconfig' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'export KUBECONFIG=/path/to/kubeconfig' >> ~/.bashrc
source ~/.bashrc
```

### Check Shell Profile
```bash
# See what's set
cat ~/.zshrc | grep KUBECONFIG
cat ~/.bashrc | grep KUBECONFIG

# Or use the manager
./scripts/manage-kubeconfig.sh
# Select: 2) Clear kubeconfig
# Then: 4) Clear KUBECONFIG and remove from shell profile
```

---

## Troubleshooting

### "Connection refused" or "Unable to connect"
```bash
# Likely old cluster - clear it
./scripts/manage-kubeconfig.sh --clear
```

### "Error from server: Unauthorized"
```bash
# Token expired - logout and login again
./scripts/manage-kubeconfig.sh --logout
oc login <new-cluster-url>
```

### "KUBECONFIG is set but file doesn't exist"
```bash
# Clear the variable
unset KUBECONFIG
# Or
./scripts/manage-kubeconfig.sh --clear
```

### After Installing New Cluster
```bash
# Set to new cluster's kubeconfig
export KUBECONFIG=/path/to/new-cluster-install/auth/kubeconfig

# Or
./scripts/manage-kubeconfig.sh --set
```

---

## Integration with Other Scripts

### rhoai-toolkit.sh
Automatically detects kubeconfig and offers management options

### openshift-installer-master.sh
Will guide you through downloading installer if missing

### integrated-workflow-v2.sh
Can skip OpenShift installation if already logged in

---

## Quick Commands Reference

```bash
# Show current setup
./scripts/manage-kubeconfig.sh --show

# Clear everything
./scripts/manage-kubeconfig.sh --clear

# Logout
./scripts/manage-kubeconfig.sh --logout

# Set new kubeconfig
./scripts/manage-kubeconfig.sh --set

# Full interactive menu
./scripts/manage-kubeconfig.sh

# Check cluster
oc whoami
oc get nodes
oc cluster-info

# Manual clear
unset KUBECONFIG
rm -f ~/.kube/config
```

---

## See Also

- `REPOSITORY-CLEANUP-SUMMARY.md` - Repository cleanup documentation
- `docs/TROUBLESHOOTING.md` - General troubleshooting
- `README.md` - Main documentation
- `scripts/README.md` - All utility scripts

