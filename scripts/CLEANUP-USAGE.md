# Cleanup Script Usage Guide

The `cleanup-all.sh` script now supports both quick local cleanup and complete AWS cleanup.

## Quick Usage

### Interactive Menu (Recommended)
```bash
./scripts/cleanup-all.sh
```

You'll see:
```
What would you like to clean up?

  1) Local installation directory only (quick - no AWS changes)
  2) Complete cleanup (local + all AWS resources)
  3) Cancel

Select option [1-3]:
```

### Quick Local Cleanup (Command Line)
```bash
./scripts/cleanup-all.sh --local-only
# or
./scripts/cleanup-all.sh -l
```

This will:
- ✅ Remove `openshift-cluster-install/` directory
- ✅ Remove `cluster-info.txt`
- ✅ Takes only a few seconds
- ⚠️ Does NOT delete AWS resources

### Complete Cleanup (Command Line)
```bash
./scripts/cleanup-all.sh
# Select option 2 from menu
```

This will:
- ✅ Destroy OpenShift cluster (via `openshift-install destroy`)
- ✅ Remove local installation directory
- ✅ Release Elastic IPs
- ✅ Delete NAT Gateways
- ✅ Clean up VPCs, subnets, route tables
- ✅ Remove security groups and network interfaces
- ⏱️ Takes 10-20 minutes

## When to Use Each Option

### Use Local Cleanup (`--local-only`) When:
- ❌ Installation failed before cluster was created
- 🔄 You want to retry installation with same AWS resources
- 🚀 You need to quickly clear local files for fresh install
- 💰 The cluster is already deleted in AWS
- ⚡ You want immediate cleanup (seconds, not minutes)

### Use Complete Cleanup When:
- ✅ Cluster is running and you want to delete everything
- 💰 You want to stop AWS charges
- 🧹 You're done with the environment completely
- 🔄 You want to start completely fresh (new VPC, etc.)

## Examples

### Example 1: Failed Installation
```bash
# Installation failed early, no cluster was created
./scripts/cleanup-all.sh -l
# Quick cleanup, ready to retry immediately
./rhoai-toolkit.sh
```

### Example 2: Decommissioning Cluster
```bash
# Cluster is running, want to delete everything
./scripts/cleanup-all.sh
# Select: 2) Complete cleanup
# Wait 10-20 minutes for full cleanup
```

### Example 3: Just Want Fresh Local Files
```bash
# Cluster might still be running in AWS, just want fresh local install
./scripts/cleanup-all.sh --local-only
# Then install fresh
./rhoai-toolkit.sh
```

## What Gets Deleted

### Local Cleanup Only (`--local-only`)
```
openshift-cluster-install/
├── auth/
│   ├── kubeconfig
│   └── kubeadmin-password
├── tls/
│   └── (various certificates)
├── metadata.json
└── .openshift_install.log

cluster-info.txt
```

### Complete Cleanup
Everything above PLUS:
```
AWS Resources:
├── EC2 Instances (masters, workers)
├── Load Balancers
├── Volumes (EBS)
├── NAT Gateways
├── Elastic IPs
├── Subnets
├── Route Tables
├── Security Groups
├── Internet Gateways
├── VPCs
└── Route53 DNS Records
```

## Tips

1. **Always use local cleanup first** if you're unsure - it's safe and fast
2. **Check AWS Console** before complete cleanup to see what will be deleted
3. **Complete cleanup takes time** - be patient, especially with NAT Gateways
4. **Local cleanup is instant** - perfect for quick retries

## Troubleshooting

### "Permission denied" errors
The script automatically handles permission issues with:
```bash
chmod -R u+w openshift-cluster-install
```

### Script hangs during complete cleanup
This is normal - NAT Gateway deletion takes 2-3 minutes each. Wait 15-20 minutes total.

### Want to cancel during complete cleanup
Press Ctrl+C, then run:
```bash
./scripts/cleanup-all.sh -l  # Clean up local files
# Manually delete AWS resources via console if needed
```

## See Also

- `./scripts/manage-kubeconfig.sh` - Manage kubeconfig files
- `./rhoai-toolkit.sh` - Fresh installation
- `docs/TROUBLESHOOTING.md` - General troubleshooting

