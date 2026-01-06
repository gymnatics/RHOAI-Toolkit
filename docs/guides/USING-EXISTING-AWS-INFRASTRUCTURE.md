# Using Existing AWS Infrastructure

## Overview

The OpenShift installer script now supports using existing AWS infrastructure (VPC, subnets, NAT gateways, etc.) instead of creating new resources. This is useful when:

- You already have VPC and networking set up
- You want to install OpenShift in an existing network environment
- You need to comply with existing network architecture
- You want to save time by reusing infrastructure

---

## How to Use Existing Infrastructure

### During Installation

When you run the installation script, you'll be prompted:

```
╔════════════════════════════════════════════════════════════════╗
║ Network Infrastructure
╚════════════════════════════════════════════════════════════════╝

Do you want to use existing VPC and subnets, or create new ones?

  1) Create new VPC and subnets (recommended for new installations)
  2) Use existing VPC and subnets

Select option [1]:
```

**Select option 2** to use existing infrastructure.

---

## What You Need

### Required Information

1. **VPC ID**: The ID of your existing VPC (e.g., `vpc-0123456789abcdef0`)
2. **Subnet IDs**: Comma-separated list of subnet IDs (both public and private)

### Subnet Requirements

Your subnets must meet these requirements:

#### 1. **Public Subnets** (for load balancers)
- Must have a route to an Internet Gateway
- Should be tagged with: `kubernetes.io/role/elb=1`
- Need auto-assign public IP enabled

#### 2. **Private Subnets** (for OpenShift nodes)
- Must have a route to a NAT Gateway for outbound internet access
- Should be tagged with: `kubernetes.io/role/internal-elb=1`
- Need sufficient IP address space for cluster nodes

#### 3. **Availability Zones**
- Subnets should span multiple availability zones (recommended: 3)
- Each AZ should have both a public and private subnet

#### 4. **IP Address Space**
- Ensure subnets have enough free IP addresses for:
  - Master nodes (3 by default)
  - Worker nodes (3+ by default)
  - Load balancers
  - Additional resources

---

## Step-by-Step Example

### Step 1: Start Installation

```bash
./scripts/openshift-installer-master.sh
# or
./rhoai-toolkit.sh
```

### Step 2: Select "Use Existing VPC"

When prompted for network infrastructure, select option 2.

### Step 3: Enter VPC ID

```
Enter your existing VPC ID (e.g., vpc-0123456789abcdef0)
VPC ID: vpc-0a1b2c3d4e5f6g7h8
```

The script will verify the VPC exists and display its CIDR block:

```
✓ Found VPC: vpc-0a1b2c3d4e5f6g7h8 (CIDR: 10.0.0.0/16)
```

### Step 4: View Available Subnets

The script will display all subnets in your VPC:

```
Available subnets in VPC vpc-0a1b2c3d4e5f6g7h8:
----------------------------------------------------------------------
|  subnet-abc123  |  us-east-2a  |  10.0.1.0/24  |  public-subnet-a  |
|  subnet-def456  |  us-east-2b  |  10.0.2.0/24  |  public-subnet-b  |
|  subnet-ghi789  |  us-east-2c  |  10.0.3.0/24  |  public-subnet-c  |
|  subnet-jkl012  |  us-east-2a  |  10.0.11.0/24 |  private-subnet-a |
|  subnet-mno345  |  us-east-2b  |  10.0.12.0/24 |  private-subnet-b |
|  subnet-pqr678  |  us-east-2c  |  10.0.13.0/24 |  private-subnet-c |
----------------------------------------------------------------------
```

### Step 5: Enter Subnet IDs

Enter the subnet IDs (comma-separated):

```
Subnet IDs (comma-separated): subnet-abc123,subnet-def456,subnet-ghi789,subnet-jkl012,subnet-mno345,subnet-pqr678
```

**Important**: Include both public and private subnets!

### Step 6: Verification

The script will verify each subnet:

```
✓ Verified subnet: subnet-abc123 (us-east-2a, 10.0.1.0/24)
✓ Verified subnet: subnet-def456 (us-east-2b, 10.0.2.0/24)
✓ Verified subnet: subnet-ghi789 (us-east-2c, 10.0.3.0/24)
✓ Verified subnet: subnet-jkl012 (us-east-2a, 10.0.11.0/24)
✓ Verified subnet: subnet-mno345 (us-east-2b, 10.0.12.0/24)
✓ Verified subnet: subnet-pqr678 (us-east-2c, 10.0.13.0/24)
```

### Step 7: Review Summary

```
Summary:
  - VPC: vpc-0a1b2c3d4e5f6g7h8
  - VPC CIDR: 10.0.0.0/16
  - Subnets: 6
    • subnet-abc123
    • subnet-def456
    • subnet-ghi789
    • subnet-jkl012
    • subnet-mno345
    • subnet-pqr678
```

### Step 8: Continue Installation

The installation will proceed using your existing infrastructure!

---

## Prerequisites Checklist

Before using existing infrastructure, ensure:

### ✅ VPC Configuration
- [ ] VPC exists in the target AWS region
- [ ] DNS hostnames enabled
- [ ] DNS resolution enabled

### ✅ Internet Gateway
- [ ] Internet Gateway attached to VPC
- [ ] Public route table has route to IGW (0.0.0.0/0 → igw-xxx)

### ✅ NAT Gateway(s)
- [ ] NAT Gateway(s) in public subnet(s)
- [ ] Elastic IP(s) allocated for NAT Gateway(s)
- [ ] Private route tables have route to NAT (0.0.0.0/0 → nat-xxx)

### ✅ Subnets
- [ ] At least 3 public subnets (across different AZs)
- [ ] At least 3 private subnets (across different AZs)
- [ ] Public subnets have `kubernetes.io/role/elb=1` tag
- [ ] Private subnets have `kubernetes.io/role/internal-elb=1` tag
- [ ] Sufficient free IP addresses in each subnet

### ✅ Route Tables
- [ ] Public subnets associated with public route table
- [ ] Private subnets associated with private route table(s)
- [ ] Routes configured correctly

### ✅ Security Groups
- [ ] Default security group allows necessary traffic
- [ ] No overly restrictive rules that would block OpenShift

---

## Common Issues

### Issue 1: "VPC not found"

**Cause**: VPC ID is incorrect or in a different region

**Solution**:
```bash
# List VPCs in your region
aws ec2 describe-vpcs --region us-east-2

# Verify VPC ID
aws ec2 describe-vpcs --vpc-ids vpc-xxx --region us-east-2
```

### Issue 2: "Subnet not found"

**Cause**: Subnet ID is incorrect or not in the specified VPC

**Solution**:
```bash
# List subnets in VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxx" \
  --region us-east-2 \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table
```

### Issue 3: Installation fails with network errors

**Cause**: Missing NAT Gateway or incorrect routing

**Solution**:
```bash
# Check NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-xxx" \
  --region us-east-2

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-xxx" \
  --region us-east-2
```

### Issue 4: Insufficient IP addresses

**Cause**: Subnets are too small or already have many resources

**Solution**:
- Use larger subnets (/20 or larger recommended)
- Or create new subnets with more IP space
- Check available IPs:
```bash
aws ec2 describe-subnets \
  --subnet-ids subnet-xxx \
  --query 'Subnets[0].AvailableIpAddressCount'
```

---

## Recommended VPC Architecture

### Example Setup (3 AZs)

```
VPC: 10.0.0.0/16

Public Subnets (for load balancers):
  - us-east-2a: 10.0.0.0/20   (subnet-pub-a)
  - us-east-2b: 10.0.16.0/20  (subnet-pub-b)
  - us-east-2c: 10.0.32.0/20  (subnet-pub-c)

Private Subnets (for OpenShift nodes):
  - us-east-2a: 10.0.128.0/20 (subnet-priv-a)
  - us-east-2b: 10.0.144.0/20 (subnet-priv-b)
  - us-east-2c: 10.0.160.0/20 (subnet-priv-c)

Internet Gateway: igw-xxx
NAT Gateways:
  - us-east-2a: nat-xxx-a (in subnet-pub-a)
  - us-east-2b: nat-xxx-b (in subnet-pub-b)
  - us-east-2c: nat-xxx-c (in subnet-pub-c)
```

### Subnet Sizing Guide

| Cluster Size | Recommended Subnet Size | Available IPs |
|--------------|------------------------|---------------|
| Small (3-10 nodes) | /24 | ~250 |
| Medium (10-50 nodes) | /22 | ~1000 |
| Large (50-100 nodes) | /20 | ~4000 |
| Very Large (100+ nodes) | /19 or larger | ~8000+ |

---

## Advantages of Using Existing Infrastructure

1. **Cost Savings**: Reuse existing NAT Gateways, Elastic IPs
2. **Consistency**: Maintain existing network architecture
3. **Compliance**: Meet organizational networking requirements
4. **Speed**: Skip VPC creation time
5. **Integration**: Easier integration with existing resources

---

## When to Create New Infrastructure

Consider creating new infrastructure when:

- This is your first OpenShift cluster
- You want isolated networking for OpenShift
- You're testing/learning and want a clean environment
- You don't have existing VPC setup

---

## Related Documentation

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [OpenShift on AWS Requirements](https://docs.openshift.com/container-platform/latest/installing/installing_aws/installing-aws-vpc.html)
- [cleanup-all.sh](../scripts/cleanup-all.sh) - Clean up created resources

---

**Last Updated**: November 2025  
**OpenShift Version**: 4.19+  
**Feature**: Use existing AWS infrastructure

