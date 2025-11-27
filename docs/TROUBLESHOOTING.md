# OpenShift Installation Troubleshooting

Quick reference for common issues and solutions.

---

## 🔍 Common Errors

### 1. Pull Secret Issues

**Error:** Script hangs after pasting pull secret

**Solution:**
```bash
# Use file path instead
# When prompted, select Option 2
# Enter: ~/Openshift-installation/pull-secret.txt
```

---

### 2. SSH Key Errors

**Error:** `syntax error near unexpected token '('`

**Solution:** Fixed in current script. If you see this:
```bash
# Re-download the latest script
# Or select Option 1 to generate new key
```

---

### 3. Domain Errors

**Error:** `no public route53 zone found matching name "example.com"`

**Solution:**
```bash
# Use your actual domain: example.opentlc.com
# NOT: example.com
```

---

### 4. Subnet Errors

**Error:** `no private subnets found`

**Solution:** Fixed in current script. The script now creates:
- 3 public subnets
- 3 private subnets
- 3 NAT gateways

If you see this error, you're using an old version:
```bash
# Clean up
./cleanup-failed-install.sh

# Re-run with updated script
./openshift-installer-master.sh
```

---

### 5. AWS Credential Errors

**Error:** `AWS credentials not configured`

**Solution:**
```bash
# Run the master script
./openshift-installer-master.sh

# Select: 1 (Configure AWS Credentials)
# Enter credentials from your environment details
```

---

### 6. Installation Hangs

**Error:** Installation seems stuck

**Check:**
```bash
# View installation logs
tail -f openshift-cluster-install/.openshift_install.log

# Check AWS console for resource creation
# NAT Gateways take 2-3 minutes to become available
```

---

### 7. Quota Exceeded

**Error:** `Service quota exceeded`

**Solution:**
```bash
# Check quotas
./openshift-installer-master.sh
# Select: 3 (Check AWS Service Quotas)

# Request increase at:
# https://console.aws.amazon.com/servicequotas/
```

---

### 8. macOS Security Warning

**Error:** `Apple could not verify "openshift-install"`

**Solution:**
```bash
./fix-macos-security.sh
```

Or manually:
```bash
xattr -rc .
```

---

### 9. Authorino Service Not Created (Fresh Clusters)

**Error:** Installation hangs waiting for Authorino service, timeout after 2 minutes

**Symptoms:**
```bash
Waiting for Authorino service... (120s elapsed)
⚠ Authorino service not ready yet (continuing anyway)
```

**Root Cause:** CRD caching issue on fresh OpenShift clusters (< 1 hour old)

**Solution:** The script now **automatically fixes this** by restarting the Kuadrant operator. You'll see:
```bash
⚠ Authorino service not ready yet
▶ Applying fix for fresh cluster CRD registration issue...
▶ Restarting Kuadrant operator to trigger reconciliation...
✓ Kuadrant is ready
```

**Manual Fix** (if needed):
```bash
# Restart Kuadrant operator
oc delete pod -l control-plane=controller-manager -n kuadrant-system | grep kuadrant-operator

# Wait and verify
sleep 30
oc get svc/authorino-authorino-authorization -n kuadrant-system
```

**More Info:** [KUADRANT-FRESH-CLUSTER-FIX.md](fixes/KUADRANT-FRESH-CLUSTER-FIX.md)

---

## 🧹 Clean Up Failed Installation

### Quick Cleanup
```bash
./cleanup-failed-install.sh
```

### Manual Cleanup
```bash
# Destroy cluster
./openshift-install destroy cluster --dir=openshift-cluster-install

# Remove directory
rm -rf openshift-cluster-install

# Delete VPC manually if needed
aws ec2 describe-vpcs --region us-east-2
aws ec2 delete-vpc --vpc-id vpc-xxxxx --region us-east-2
```

---

## 📋 Verification Steps

### Before Installation
```bash
# 1. Check AWS credentials
aws sts get-caller-identity

# 2. Check Route53 domain
aws route53 list-hosted-zones | grep REDACTED_SANDBOX

# 3. Check installer version
./openshift-install version

# 4. Verify pull secret
cat ~/Openshift-installation/pull-secret.txt | jq .
```

### During Installation
```bash
# Watch logs
tail -f openshift-cluster-install/.openshift_install.log

# Check AWS resources
aws ec2 describe-vpcs --region us-east-2
aws ec2 describe-instances --region us-east-2
```

### After Installation
```bash
# Set kubeconfig
export KUBECONFIG=$PWD/openshift-cluster-install/auth/kubeconfig

# Check cluster
oc get nodes
oc get clusteroperators
oc get clusterversion

# Get console URL
oc whoami --show-console
```

---

## 🔧 Debug Commands

### Check Installation Status
```bash
# View all logs
cat openshift-cluster-install/.openshift_install.log

# Check specific errors
grep -i error openshift-cluster-install/.openshift_install.log
grep -i fatal openshift-cluster-install/.openshift_install.log
```

### Check AWS Resources
```bash
# VPCs
aws ec2 describe-vpcs --region us-east-2

# Subnets
aws ec2 describe-subnets --region us-east-2 \
  --filters "Name=vpc-id,Values=vpc-xxxxx"

# NAT Gateways
aws ec2 describe-nat-gateways --region us-east-2

# Instances
aws ec2 describe-instances --region us-east-2 \
  --filters "Name=tag:Name,Values=*openshift*"
```

### Check Route53
```bash
# List zones
aws route53 list-hosted-zones

# Check records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0xxxxx
```

---

## ⚠️ Known Issues

### Issue: NAT Gateway Creation Slow
**Expected:** NAT Gateways take 2-3 minutes to become available  
**Solution:** Be patient, this is normal

### Issue: Bootstrap Timeout
**Expected:** Bootstrap can take 15-20 minutes  
**Solution:** Wait and monitor logs

### Issue: Cluster Operators Not Ready
**Expected:** Some operators take 5-10 minutes after cluster is up  
**Solution:** Run `oc get co` to check status

---

## 💡 Tips

1. **Always clean up** before retrying
2. **Check logs** for specific errors
3. **Verify domain** is correct (example.opentlc.com)
4. **Use file path** for pull secret (more reliable)
5. **Monitor AWS console** during installation
6. **Don't interrupt** the installation process

---

## 📞 Getting Help

If you're still stuck:

1. Check the installation logs
2. Review AWS console for resource status
3. Verify all prerequisites are met
4. Try cleaning up and starting fresh

---

**Need to start over?**
```bash
./cleanup-failed-install.sh
./openshift-installer-master.sh
```

