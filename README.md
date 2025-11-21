# OpenShift 4.19 Installation on AWS

Complete automation for installing OpenShift on AWS with GPU support (H100, A100, L40S).

---

## 🚀 Quick Start

### Your Environment
- **AWS Account:** REDACTED_AWS_ACCOUNT_ID
- **Route53 Domain:** `example.opentlc.com`
- **OpenShift Version:** 4.19.19
- **Pull Secret:** `pull-secret.txt`

### Three Simple Steps

```bash
# 1. Configure AWS credentials
./openshift-installer-master.sh
# Select: 1 (Configure AWS Credentials)

# 2. Clean up any previous attempts
./cleanup-failed-install.sh

# 3. Install OpenShift
./openshift-installer-master.sh
# Select: 6 (Run Installation Only)
# Base domain: example.opentlc.com
```

**Installation time:** 45-50 minutes

---

## 📋 What's Included

### Scripts
- **`openshift-installer-master.sh`** - All-in-one installation script with menu
- **`cleanup-failed-install.sh`** - Clean up failed installations
- **`setup-route53-domain.sh`** - Route53 domain helper
- **`openshift-install`** - OpenShift 4.19.19 installer binary

### Features
✅ Interactive menu-driven installation  
✅ AWS credential configuration  
✅ Automatic VPC, subnet, and NAT gateway creation  
✅ Multi-AZ support (us-east-2a, b, c)  
✅ GPU instance support (H100, A100, L40S, A10G)  
✅ Pull secret: paste or file path  
✅ SSH key: auto-generate or use existing  

---

## 🎯 Master Script Menu

```
1) Configure AWS Credentials
2) Check Prerequisites & System Status
3) Check AWS Service Quotas & GPU Availability
4) Download/Update OpenShift Installer
5) Run Full Installation (Download + Install)
6) Run Installation Only (Skip Download)
7) View Documentation
8) Exit
```

---

## 📝 Installation Configuration

### AWS Credentials
```
Access Key ID: ***REDACTED_ACCESS_KEY***
Secret Access Key: ***REDACTED_SECRET_KEY***
Region: us-east-2
Output format: json
```

### Recommended Settings

**Standard Cluster:**
- Cluster name: `my-openshift`
- Base domain: `example.opentlc.com`
- Master: `m6i.xlarge` × 3
- Worker: `m6i.2xlarge` × 3
- Cost: ~$50/day

**GPU Cluster (H100):**
- Worker: `p5.48xlarge` × 1
- Cost: ~$2,400/day
- Check availability first (menu option 3)

---

## 🎮 GPU Instance Types

| Instance | GPUs | Type | vCPUs | RAM | Use Case |
|----------|------|------|-------|-----|----------|
| p5.48xlarge | 8 | H100 80GB | 192 | 2TB | ML Training |
| p4d.24xlarge | 8 | A100 40GB | 96 | 1.1TB | ML Training |
| g6e.xlarge | 1 | L40S 48GB | 4 | 16GB | AI Inference |
| g5.xlarge | 1 | A10G 24GB | 4 | 16GB | Graphics |

---

## 🔧 Troubleshooting

### Common Issues

**1. Pull secret paste hangs**
- Use Option 2 (file path) instead
- Path: `~/Openshift-installation/pull-secret.txt`

**2. SSH key generation fails**
- Script auto-generates if missing
- Or provide existing key path

**3. Domain not found error**
- Use: `example.opentlc.com`
- Not: `example.com`

**4. No private subnets error**
- Fixed in current script
- Script creates both public and private subnets

**5. Installation fails**
```bash
# Check logs
tail -f openshift-cluster-install/.openshift_install.log

# Clean up and retry
./cleanup-failed-install.sh
./openshift-installer-master.sh
```

---

## 📊 What Gets Created

### AWS Resources
- VPC with custom CIDR (10.0.0.0/16)
- 3 public subnets (one per AZ)
- 3 private subnets (one per AZ)
- 3 NAT Gateways
- 1 Internet Gateway
- Route tables
- Security groups
- Load balancers
- EC2 instances (masters + workers)
- Route53 DNS records

### Cluster Access
After installation:
- **Console:** `https://console-openshift-console.apps.my-openshift.example.opentlc.com`
- **API:** `https://api.my-openshift.example.opentlc.com:6443`
- **Credentials:** In `openshift-cluster-install/auth/`

```bash
export KUBECONFIG=$PWD/openshift-cluster-install/auth/kubeconfig
oc get nodes
cat openshift-cluster-install/auth/kubeadmin-password
```

---

## 💰 Cost Estimates

### Standard Cluster
- 3× m6i.xlarge masters: ~$18/day
- 3× m6i.2xlarge workers: ~$29/day
- NAT Gateways: ~$3/day
- **Total: ~$50/day**

### With GPU
- 1× p5.48xlarge: ~$2,352/day
- **Total: ~$2,400/day**

💡 **Tip:** Use Spot instances to save up to 90%

---

## 🧹 Cleanup

To destroy the cluster and all AWS resources:

```bash
./openshift-install destroy cluster --dir=openshift-cluster-install
```

Or use the cleanup script:
```bash
./cleanup-failed-install.sh
```

---

## 📚 Additional Resources

- **OpenShift Docs:** https://docs.openshift.com/container-platform/4.19/
- **AWS CLI:** https://docs.aws.amazon.com/cli/
- **Troubleshooting:** See TROUBLESHOOTING.md

---

## ⚠️ Important Notes

1. **AWS Credentials are temporary** - Lab environment only
2. **Don't commit credentials to git** - Will be deleted automatically
3. **Domain is pre-configured** - Use `example.opentlc.com`
4. **Monitor costs** - Destroy cluster when done
5. **Installation takes 45-50 minutes** - Don't interrupt

---

## 🎯 Next Steps After Installation

1. Access web console with kubeadmin credentials
2. Configure identity provider
3. Deploy applications
4. Set up monitoring
5. Configure autoscaling

---

**Ready to install?** Run: `./openshift-installer-master.sh`
