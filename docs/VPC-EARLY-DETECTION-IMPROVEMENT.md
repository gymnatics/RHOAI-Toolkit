# VPC Early Detection Improvement

## Problem Statement

Currently, the OpenShift installation script asks for VPC preferences **after** collecting all cluster configuration details (cluster name, instance types, domain, etc.). This means:

1. User spends time entering cluster details
2. Only then discovers they need VPC information
3. May need to cancel and restart if they're not prepared

## Proposed Solution

Check for existing VPCs **first**, before prompting for any cluster configuration. This provides better UX:

1. ✅ User knows upfront what infrastructure exists
2. ✅ Can make informed decisions about VPC usage
3. ✅ Can prepare subnet IDs before entering cluster details
4. ✅ Reduces likelihood of canceling mid-configuration

## Implementation Changes

### Current Flow

```
1. Check prerequisites
2. Get pull secret
3. Get SSH key
4. Configure cluster (name, domain, instance types, etc.)
5. Ask: "Create new VPC or use existing?" ← TOO LATE!
6. If existing: prompt for VPC ID and subnets
7. Generate install config
8. Run installation
```

### Improved Flow

```
1. Check prerequisites
2. Detect existing VPCs in AWS ← MOVED TO BEGINNING!
3. Show VPC options and let user decide
4. If existing VPC: pre-select and verify it
5. Get pull secret
6. Get SSH key
7. Configure cluster (with VPC context already known)
8. If existing VPC: just get subnet IDs
9. If new VPC: create it
10. Generate install config
11. Run installation
```

## Key Changes

### 1. New Function: `detect_and_choose_vpc()`

This function runs **early** in the installation flow:

```bash
detect_and_choose_vpc() {
    print_header "Network Infrastructure Pre-Check"
    
    # Prompt for AWS region first (needed for VPC queries)
    prompt_with_default "AWS Region" "us-east-2" AWS_REGION
    
    # Check for existing VPCs
    print_info "Checking for existing VPCs in $AWS_REGION..."
    
    local vpc_list=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0],State]' \
        --output text 2>/dev/null)
    
    if [ -z "$vpc_list" ]; then
        print_info "No existing VPCs found"
        USE_EXISTING_VPC=false
        return 0
    fi
    
    # Display existing VPCs in a nice table
    print_success "Found existing VPCs:"
    # ... display VPCs ...
    
    # Ask user what they want to do
    echo "What would you like to do?"
    echo "  1) Create a NEW VPC (recommended)"
    echo "  2) Use an EXISTING VPC"
    echo "  3) Cancel"
    
    read -p "Select option [1]: " vpc_decision
    
    case $vpc_decision in
        1)
            USE_EXISTING_VPC=false
            ;;
        2)
            USE_EXISTING_VPC=true
            # Pre-select VPC now
            read -p "VPC ID: " VPC_ID
            # Verify and get CIDR
            VPC_CIDR=$(aws ec2 describe-vpcs ...)
            # Show available subnets
            ;;
        3)
            exit 0
            ;;
    esac
}
```

### 2. New Global Variable

```bash
USE_EXISTING_VPC=false  # Track VPC decision early
```

### 3. Modified `configure_cluster()`

Now shows VPC context at the beginning:

```bash
configure_cluster() {
    print_header "Cluster Configuration"
    
    # Show VPC context
    echo "Network Context:"
    if [ "$USE_EXISTING_VPC" = true ]; then
        echo "  • Using existing VPC: $VPC_ID ($VPC_CIDR)"
    else
        echo "  • Will create new VPC"
    fi
    echo "  • Region: $AWS_REGION"
    
    # Now prompt for cluster details
    prompt_with_default "Cluster name" "openshift-cluster" CLUSTER_NAME
    # ... rest of configuration ...
}
```

### 4. Modified Installation Functions

Both `installation_only()` and `full_installation()` now call `detect_and_choose_vpc()` **first**:

```bash
installation_only() {
    # Check installer exists
    # ...
    
    # NEW: Check VPC FIRST
    detect_and_choose_vpc
    
    # Then get other configuration
    get_pull_secret
    get_ssh_key
    configure_cluster
    
    # Handle VPC based on earlier decision
    if [ "$USE_EXISTING_VPC" = true ]; then
        # Just get subnet IDs (VPC already selected)
        # ...
    else
        # Create new VPC
        create_vpc_and_subnets
    fi
    
    # Continue with installation
    # ...
}
```

## Benefits

### 1. Better User Experience

**Before:**
```
User: *enters cluster name*
User: *enters domain*
User: *enters instance types*
Script: "Do you want to use existing VPC?"
User: "Wait, I need to check what VPCs I have... let me cancel"
```

**After:**
```
Script: "Found 3 existing VPCs: vpc-123, vpc-456, vpc-789"
Script: "Do you want to use one of these or create new?"
User: "I'll use vpc-123" *makes informed decision*
Script: "Great! Here are the subnets available..."
User: *continues with confidence*
```

### 2. Informed Decisions

Users can see:
- What VPCs already exist
- VPC CIDRs and names
- Available subnets
- Make decisions with full context

### 3. Time Savings

- No need to cancel and restart
- Can prepare subnet IDs beforehand
- Reduces back-and-forth

### 4. Better Error Prevention

- VPC verification happens early
- Invalid VPC IDs caught before spending time on configuration
- Region mismatch detected upfront

## Implementation Steps

### Option 1: Create New Script (Recommended for Testing)

1. Copy the improved template to a new file
2. Copy all remaining functions from original script
3. Test thoroughly
4. Once validated, replace original

```bash
# Create improved version
cp scripts/openshift-installer-master.sh scripts/openshift-installer-master-improved.sh

# Edit improved version with changes
# Test it
./scripts/openshift-installer-master-improved.sh

# Once validated, replace original
mv scripts/openshift-installer-master.sh scripts/openshift-installer-master-backup.sh
mv scripts/openshift-installer-master-improved.sh scripts/openshift-installer-master.sh
```

### Option 2: Modify Existing Script Directly

1. Add `USE_EXISTING_VPC=false` to global variables
2. Add `detect_and_choose_vpc()` function
3. Modify `configure_cluster()` to show VPC context
4. Modify `installation_only()` to call `detect_and_choose_vpc()` early
5. Modify `full_installation()` to call `detect_and_choose_vpc()` early
6. Remove old VPC prompts from later in the flow

## Example User Flow

### Scenario 1: No Existing VPCs

```
╔════════════════════════════════════════════════════════════════╗
║  Network Infrastructure Pre-Check                              ║
╚════════════════════════════════════════════════════════════════╝

Before we begin, let's check your AWS infrastructure.

[INFO] Which AWS region will you use?
AWS Region [us-east-2]: 

[INFO] Checking for existing VPCs in us-east-2...

[INFO] No existing VPCs found in us-east-2

✓ We'll create a new VPC for your OpenShift cluster

Press any key to continue...

╔════════════════════════════════════════════════════════════════╗
║  Cluster Configuration                                         ║
╚════════════════════════════════════════════════════════════════╝

Network Context:
  • Will create new VPC
  • Region: us-east-2

Cluster name [openshift-cluster]: my-cluster
...
```

### Scenario 2: Existing VPCs Found

```
╔════════════════════════════════════════════════════════════════╗
║  Network Infrastructure Pre-Check                              ║
╚════════════════════════════════════════════════════════════════╝

Before we begin, let's check your AWS infrastructure.

[INFO] Which AWS region will you use?
AWS Region [us-east-2]: 

[INFO] Checking for existing VPCs in us-east-2...

[SUCCESS] Found 2 existing VPC(s) in us-east-2:

┌────────────────────────────────────────────────────────────────────┐
│ VPC ID              │ CIDR Block      │ Name          │ State    │
├────────────────────────────────────────────────────────────────────┤
│ vpc-0123456789abcde │ 10.0.0.0/16     │ prod-vpc      │ available│
│ vpc-abcdef123456789 │ 172.16.0.0/16   │ dev-vpc       │ available│
└────────────────────────────────────────────────────────────────────┘

What would you like to do?

  1) Create a NEW VPC for OpenShift (recommended)
  2) Use an EXISTING VPC from the list above
  3) Cancel and exit

Select option [1]: 2

[SUCCESS] Will use an existing VPC

[INFO] Enter the VPC ID you want to use (e.g., vpc-0123456789abcdef0)
VPC ID: vpc-0123456789abcde

[INFO] Verifying VPC...
[SUCCESS] Verified VPC: vpc-0123456789abcde (CIDR: 10.0.0.0/16)

[INFO] Available subnets in VPC vpc-0123456789abcde:
┌─────────────────────────────────────────────────────────────┐
│ subnet-111 │ us-east-2a │ 10.0.1.0/24  │ public-subnet-a │
│ subnet-222 │ us-east-2b │ 10.0.2.0/24  │ public-subnet-b │
│ subnet-333 │ us-east-2c │ 10.0.3.0/24  │ public-subnet-c │
│ subnet-444 │ us-east-2a │ 10.0.11.0/24 │ private-subnet-a│
│ subnet-555 │ us-east-2b │ 10.0.12.0/24 │ private-subnet-b│
│ subnet-666 │ us-east-2c │ 10.0.13.0/24 │ private-subnet-c│
└─────────────────────────────────────────────────────────────┘

⚠ You'll need to provide subnet IDs later during configuration

[SUCCESS] Network infrastructure decision recorded

Summary:
  • Using existing VPC: vpc-0123456789abcde
  • VPC CIDR: 10.0.0.0/16
  • Region: us-east-2

Press any key to continue...

╔════════════════════════════════════════════════════════════════╗
║  Cluster Configuration                                         ║
╚════════════════════════════════════════════════════════════════╝

Network Context:
  • Using existing VPC: vpc-0123456789abcde (10.0.0.0/16)
  • Region: us-east-2

Cluster name [openshift-cluster]: my-cluster
...
```

## Testing Checklist

- [ ] Test with no existing VPCs (should offer to create new)
- [ ] Test with existing VPCs (should display list)
- [ ] Test selecting existing VPC (should verify and show subnets)
- [ ] Test creating new VPC (should work as before)
- [ ] Test canceling during VPC selection
- [ ] Test invalid VPC ID (should show error)
- [ ] Test VPC in different region (should show error)
- [ ] Test full installation flow with existing VPC
- [ ] Test full installation flow with new VPC
- [ ] Verify install-config.yaml is generated correctly for both cases

## Rollback Plan

If issues arise:

```bash
# Restore original script
mv scripts/openshift-installer-master-backup.sh scripts/openshift-installer-master.sh
```

## Future Enhancements

1. **Auto-select best VPC**: Analyze VPCs and recommend the best one based on:
   - Available IP space
   - Existing subnets
   - Tags/naming conventions

2. **Subnet validation**: Check that selected subnets meet OpenShift requirements:
   - At least 3 availability zones
   - Both public and private subnets
   - Sufficient IP addresses

3. **VPC health check**: Verify VPC has:
   - Internet Gateway (for public subnets)
   - NAT Gateways (for private subnets)
   - Proper route tables

4. **Save VPC preferences**: Remember user's VPC choice for future installations

## Related Documentation

- [Using Existing AWS Infrastructure](../docs/guides/USING-EXISTING-AWS-INFRASTRUCTURE.md)
- [OpenShift Installation Guide](../README.md)
- [Troubleshooting](../docs/TROUBLESHOOTING.md)

---

**Status**: Proposed  
**Priority**: Medium  
**Effort**: ~2-3 hours  
**Impact**: High (better UX)

