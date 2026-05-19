# AWS Prerequisites Check for OpenShift Installation

## Overview

The AWS prerequisites checker validates your AWS environment before starting an OpenShift installation. This helps catch configuration issues early, saving time and avoiding failed installations.

## What It Checks

### ✅ Critical Checks (Must Pass)

1. **AWS CLI Installation**
   - Verifies AWS CLI is installed
   - Shows installation instructions if missing

2. **AWS Credentials**
   - Validates credentials are configured
   - Shows AWS account ID and user ARN
   - Checks if credentials have proper permissions

3. **AWS Region**
   - Verifies region is configured
   - Tests region accessibility

4. **Route53 Hosted Zones**
   - Lists available public hosted zones
   - Identifies private zones (not suitable for new clusters)
   - Warns about domain naming (no leading dots!)

5. **OpenShift Installer Binary**
   - Checks if `openshift-install` exists
   - Verifies it's executable
   - Shows version information

### ⚠️ Warning Checks (Can Proceed with Caution)

6. **Conflicting Private Hosted Zones**
   - Detects leftover private zones from failed installations
   - Recommends cleanup before proceeding

7. **AWS Service Quotas**
   - Checks VPC quota
   - Checks Elastic IP quota
   - Shows current usage vs limits

8. **SSH Key Configuration**
   - Verifies ssh-agent is running
   - Lists loaded SSH keys
   - Warns if no keys are loaded

9. **Existing OpenShift Resources**
   - Scans for existing OpenShift VPCs
   - Checks for running OpenShift instances
   - Recommends cleanup if found

## Usage

### Standalone Check

Run the checker independently before installation:

```bash
./scripts/check-aws-prerequisites.sh
```

### Integrated with Installation

The checker runs automatically when you use `rhoai-toolkit.sh`:

```bash
./rhoai-toolkit.sh
```

You'll be prompted:
```
Would you like to run AWS prerequisites check?
This will verify:
  • AWS credentials and permissions
  • Route53 hosted zones
  • Service quotas
  • Existing resources
  • SSH keys

Run AWS checks? [Y/n]:
```

## Example Output

```
╔════════════════════════════════════════════════════════════════╗
║         AWS Prerequisites Check for OpenShift Install         ║
╚════════════════════════════════════════════════════════════════╝

✓ AWS CLI installed

Checking AWS Credentials...
✓ AWS credentials valid
  Account: 123456789012
  User: arn:aws:iam::123456789012:user/admin

Checking AWS Region...
✓ Region configured: us-east-2

Checking Route53 Hosted Zones...
✓ Found 1 Route53 hosted zone(s)

Available domains:
  1) sandbox3593.opentlc.com (Public) ✓

Note: Use a PUBLIC hosted zone domain for installation
      Do NOT include leading dot (.) in domain name

Checking for Conflicting Private Hosted Zones...
⚠ Found private hosted zones from previous installations:
  - openshift-cluster.sandbox3593.opentlc.com.

These should be cleaned up before installing:
  ./scripts/cleanup-all.sh

Checking AWS Service Quotas...
✓ VPC quota: 2/5 available
✓ Elastic IP quota: 3/5 available

Checking SSH Key Configuration...
✓ SSH agent running with 1 key(s) loaded

Loaded SSH keys:
  2048 SHA256:abc123... /Users/user/.ssh/id_rsa (RSA)

Checking for Existing OpenShift Resources...
⚠ Found existing OpenShift resources:
  - 1 VPC(s) with 'openshift' in name
  - 3 EC2 instance(s) with 'openshift' in name

These may be from a previous installation.
Clean up before proceeding:
  ./scripts/cleanup-all.sh

Checking OpenShift Installer...
✓ OpenShift installer found
  Version: openshift-install 4.19.19

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Prerequisites Check Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Passed: 5
⚠ Warnings: 4
✗ Failed: 0

⚠️  Some warnings detected. You may proceed, but review the warnings above.

Continue anyway? [y/N]:
```

## Common Issues and Solutions

### Issue: No Route53 Hosted Zones Found

**Error:**
```
✗ No Route53 hosted zones found
```

**Solution:**
- Contact your AWS administrator to create a public hosted zone
- Or create one in AWS Console: Route53 → Hosted zones → Create hosted zone

### Issue: Private Hosted Zone from Previous Install

**Error:**
```
⚠ Found private hosted zones from previous installations:
  - openshift-cluster.sandbox3593.opentlc.com.
```

**Solution:**
```bash
./scripts/cleanup-all.sh
# Select: 2) Complete cleanup
```

### Issue: VPC or Elastic IP Quota Reached

**Error:**
```
✗ VPC quota reached: 5/5
✗ Elastic IP quota reached: 5/5
```

**Solution:**
1. Delete unused VPCs/Elastic IPs
2. Or request quota increase: https://console.aws.amazon.com/servicequotas/

### Issue: SSH Agent Not Running

**Error:**
```
⚠ SSH agent not running or no keys loaded
```

**Solution:**
```bash
# Start ssh-agent
eval $(ssh-agent)

# Add your SSH key
ssh-add ~/.ssh/id_rsa

# Or let the installer generate a new key
```

### Issue: Existing OpenShift Resources

**Error:**
```
⚠ Found existing OpenShift resources:
  - 1 VPC(s) with 'openshift' in name
```

**Solution:**
```bash
# Clean up old resources
./scripts/cleanup-all.sh
```

## Integration Points

The AWS prerequisites check is integrated into:

1. **rhoai-toolkit.sh** - Runs automatically before installation
2. **Standalone script** - Can be run independently for troubleshooting

## Files

- `lib/utils/aws-checks.sh` - Core checking functions
- `scripts/check-aws-prerequisites.sh` - Standalone wrapper script
- `rhoai-toolkit.sh` - Integrated into main setup flow

## Benefits

✅ **Catch issues early** - Before spending 30-45 minutes on installation  
✅ **Clear error messages** - Know exactly what's wrong  
✅ **Actionable solutions** - Get specific commands to fix issues  
✅ **Save time** - Avoid failed installations due to misconfiguration  
✅ **Prevent common mistakes** - Like using domains with leading dots  

## When to Run

- **Before first installation** - Validate your AWS environment
- **After failed installation** - Diagnose what went wrong
- **After environment change** - New AWS account, new credentials, etc.
- **Troubleshooting** - When installation fails unexpectedly

## Skip the Check

If you're confident your environment is correct:

```bash
# In rhoai-toolkit.sh, when prompted:
Run AWS checks? [Y/n]: n
```

Or use the integrated workflow directly:

```bash
./integrated-workflow-v2.sh
```

## See Also

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting guide
- [CLEANUP-USAGE.md](../scripts/CLEANUP-USAGE.md) - Cleanup script usage
- [AWS Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) - AWS CLI configuration

---

**Last Updated**: November 2025  
**Tested With**: AWS CLI 2.x, OpenShift 4.19

