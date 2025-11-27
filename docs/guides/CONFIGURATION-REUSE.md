# Configuration Reuse Feature

## Overview

The OpenShift installer now saves your configuration preferences and allows you to reuse them for subsequent installations. This eliminates the need to re-enter the same information (domain, instance types, VPC settings, etc.) every time you run the installer.

---

## How It Works

### First Installation

When you run the installer for the first time:

1. You'll be prompted for all configuration details:
   - Cluster name
   - Base domain
   - AWS region
   - Master/Worker instance types
   - VPC settings (new or existing)
   - Pull secret
   - SSH key

2. After configuration, you'll be asked:
   ```
   Save this configuration for future use? [Y/n]:
   ```

3. If you choose **Yes** (default), your configuration is saved to:
   ```
   ~/.openshift-install-config.env
   ```

**Note**: For security, pull secrets and SSH keys are stored separately in their standard locations, not in the configuration file.

---

## Subsequent Installations

When you run the installer again, it will detect your saved configuration:

```
═══════════════════════════════════════════════════════════
  Saved Configuration Found
═══════════════════════════════════════════════════════════

Cluster:
  Name:           openshift-cluster
  Domain:         sandbox3593.opentlc.com
  Region:         us-east-2

Instance Types:
  Master:         m6a.4xlarge (x3)
  Worker:         m6a.4xlarge (x3)

Network:
  VPC:            vpc-0123456789abcdef0 (existing)
  CIDR:           10.0.0.0/16
  Subnets:        6 configured

Saved: 2025-11-27 14:30:00
═══════════════════════════════════════════════════════════

Would you like to use this saved configuration?

  1) Yes - Use saved configuration (quick)
  2) No - Enter new configuration
  3) Edit - Modify specific values

Select option [1]:
```

### Option 1: Use Saved Configuration (Quick)

- Loads all saved settings
- Only prompts for pull secret and SSH key (if not found)
- Fastest way to reinstall with same settings

### Option 2: Enter New Configuration

- Ignores saved configuration
- Prompts for all settings from scratch
- Useful when you want completely different settings

### Option 3: Edit Configuration

- Loads saved configuration
- Allows you to modify specific values interactively
- Keeps unchanged values from saved config

---

## What Gets Saved

### Configuration File (`~/.openshift-install-config.env`)

The following settings are saved:

```bash
# Cluster Configuration
CLUSTER_NAME="openshift-cluster"
BASE_DOMAIN="sandbox3593.opentlc.com"
AWS_REGION="us-east-2"

# Instance Types
MASTER_INSTANCE_TYPE="m6a.4xlarge"
MASTER_REPLICAS="3"
WORKER_INSTANCE_TYPE="m6a.4xlarge"
WORKER_REPLICAS="3"

# Network Configuration
USE_EXISTING_VPC="true"
VPC_ID="vpc-0123456789abcdef0"
VPC_CIDR="10.0.0.0/16"
SUBNET_IDS_STR="subnet-abc subnet-def subnet-ghi..."

# Paths to secrets (not the secrets themselves)
SSH_KEY_PATH="/Users/username/.ssh/id_rsa.pub"
PULL_SECRET_PATH="/Users/username/.openshift/pull-secret.json"
```

### Separate Secure Storage

For security, actual secrets are stored separately:

- **Pull Secret**: `~/.openshift/pull-secret.json` (chmod 600)
- **SSH Keys**: `~/.ssh/` directory (standard SSH permissions)

---

## Use Cases

### 1. Failed Installation Retry

If your installation fails (e.g., DNS propagation issues), you can quickly retry:

```bash
# Clean up failed installation
./scripts/cleanup-all.sh --local-only

# Retry with same configuration
./scripts/openshift-installer-master.sh
# Select option 1 to use saved config
```

### 2. Multiple Clusters with Same Settings

Deploy multiple clusters with identical configuration:

```bash
# First cluster
./scripts/openshift-installer-master.sh
# Configure and save

# Second cluster
./scripts/openshift-installer-master.sh
# Select option 3 to edit
# Change only cluster name
```

### 3. Temporary Environment Testing

Test installations in temporary environments (like OpenTLC):

```bash
# Environment 1
./scripts/openshift-installer-master.sh
# Save configuration

# Environment expires, get new one
# Environment 2
./scripts/openshift-installer-master.sh
# Select option 3 to edit
# Update only VPC ID and subnets
```

---

## Managing Saved Configuration

### View Saved Configuration

```bash
cat ~/.openshift-install-config.env
```

### Clear Saved Configuration

```bash
rm ~/.openshift-install-config.env
```

Or use the configuration manager:

```bash
source lib/utils/config-manager.sh
clear_saved_configuration
```

### Manually Edit Configuration

```bash
nano ~/.openshift-install-config.env
```

**Warning**: Make sure to maintain proper bash variable syntax.

---

## Interactive Edit Mode

When you select **Option 3 (Edit)**, you'll be prompted for each setting:

```
═══════════════════════════════════════════════════════════
  Edit Configuration
═══════════════════════════════════════════════════════════

Press Enter to keep current value, or type new value

Cluster name [openshift-cluster]: my-new-cluster
Base domain [sandbox3593.opentlc.com]: ⏎
AWS region [us-east-2]: us-west-2
Master instance type [m6a.4xlarge]: ⏎
Master replicas [3]: ⏎
Worker instance type [m6a.4xlarge]: m6a.8xlarge
Worker replicas [3]: 5
VPC CIDR [10.0.0.0/16]: ⏎

Configuration updated!
```

In this example:
- Changed cluster name to `my-new-cluster`
- Changed region to `us-west-2`
- Changed worker instance type to `m6a.8xlarge`
- Increased worker replicas to 5
- Kept all other values unchanged

---

## Security Considerations

### What's Safe to Save

✅ **Saved in configuration file**:
- Cluster names
- Domain names
- AWS regions
- Instance types
- VPC IDs and CIDRs
- Subnet IDs
- Paths to secret files

### What's NOT Saved

❌ **NOT saved in configuration file**:
- Pull secret contents
- SSH private keys
- AWS credentials
- Passwords

### File Permissions

The configuration file is created with secure permissions:

```bash
chmod 600 ~/.openshift-install-config.env
```

This means only you (the file owner) can read or write it.

---

## Troubleshooting

### Configuration Not Loading

**Problem**: Saved configuration exists but isn't being offered.

**Solution**:
1. Check if file exists:
   ```bash
   ls -la ~/.openshift-install-config.env
   ```

2. Verify file is readable:
   ```bash
   cat ~/.openshift-install-config.env
   ```

3. Check for syntax errors in the file

### Pull Secret or SSH Key Not Found

**Problem**: Configuration loads but prompts for pull secret/SSH key.

**Solution**:
1. Check if pull secret exists:
   ```bash
   ls -la ~/.openshift/pull-secret.json
   ```

2. Check if SSH key exists:
   ```bash
   ls -la ~/.ssh/id_rsa.pub
   ```

3. If missing, you'll be prompted to provide them again

### VPC No Longer Exists

**Problem**: Saved VPC ID doesn't exist in current AWS account.

**Solution**:
1. Select **Option 3 (Edit)** when prompted
2. The script will detect VPCs in your current AWS account
3. Update the VPC ID to a valid one

### Wrong AWS Region

**Problem**: Saved region doesn't match your current AWS environment.

**Solution**:
1. Select **Option 3 (Edit)** when prompted
2. Change the AWS region
3. Update VPC and subnet IDs if needed

---

## Advanced Usage

### Using Custom Configuration File

You can specify a custom configuration file location:

```bash
export CONFIG_FILE="$HOME/my-custom-config.env"
./scripts/openshift-installer-master.sh
```

### Programmatic Configuration

For automation, you can create a configuration file manually:

```bash
cat > ~/.openshift-install-config.env << 'EOF'
CLUSTER_NAME="automated-cluster"
BASE_DOMAIN="example.com"
AWS_REGION="us-east-1"
MASTER_INSTANCE_TYPE="m6a.4xlarge"
MASTER_REPLICAS="3"
WORKER_INSTANCE_TYPE="m6a.4xlarge"
WORKER_REPLICAS="3"
USE_EXISTING_VPC="false"
VPC_CIDR="10.0.0.0/16"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
PULL_SECRET_PATH="$HOME/.openshift/pull-secret.json"
EOF

chmod 600 ~/.openshift-install-config.env
```

---

## Benefits

### Time Savings

- **First run**: ~5-10 minutes of configuration
- **Subsequent runs with saved config**: ~30 seconds

### Consistency

- Same settings across multiple installations
- Reduces configuration errors
- Easier to maintain standard cluster configurations

### Flexibility

- Quick edits for minor changes
- Full reconfiguration when needed
- Works with both new and existing VPCs

---

## Related Documentation

- [OpenShift Installer Master Script](../scripts/README.md)
- [Using Existing AWS Infrastructure](USING-EXISTING-AWS-INFRASTRUCTURE.md)
- [Cleanup Script Usage](../../scripts/CLEANUP-USAGE.md)
- [VPC Early Detection](../VPC-EARLY-DETECTION-IMPROVEMENT.md)

---

## Feedback

If you encounter issues with configuration reuse or have suggestions for improvement, please update this documentation or create an issue.

