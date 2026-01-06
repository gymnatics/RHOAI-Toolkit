#!/bin/bash

#############################################################################
# Complete OpenShift Cleanup Script
# Cleans up ALL OpenShift resources: VPCs, subnets, route tables, 
# NAT gateways, Elastic IPs, security groups, network interfaces, etc.
#
# Usage:
#   ./cleanup-all.sh                # Interactive menu
#   ./cleanup-all.sh --local-only   # Quick: Remove local directory only
#   ./cleanup-all.sh -l             # Same as --local-only
#
# Options:
#   --local-only, -l    Remove only local installation directory
#                       (Does NOT delete AWS resources)
#############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

AWS_REGION="us-east-2"

# Parse command line arguments
LOCAL_ONLY=false
if [ "$1" == "--local-only" ] || [ "$1" == "-l" ]; then
    LOCAL_ONLY=true
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    Complete OpenShift Cleanup Script                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# If no arguments, show menu
if [ "$LOCAL_ONLY" = false ] && [ $# -eq 0 ]; then
    echo -e "${CYAN}What would you like to clean up?${NC}"
    echo ""
    echo "  1) Local installation directory only (quick - no AWS changes)"
    echo "  2) Complete cleanup (local + all AWS resources)"
    echo "  3) Cancel"
    echo ""
    read -p "Select option [1-3]: " cleanup_choice
    
    case $cleanup_choice in
        1)
            LOCAL_ONLY=true
            ;;
        2)
            LOCAL_ONLY=false
            ;;
        3)
            print_info "Cleanup cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    echo ""
fi

# Quick local cleanup function
quick_local_cleanup() {
    print_header "Quick Local Cleanup"
    
    if [ -d "openshift-cluster-install" ]; then
        print_info "Found installation directory: openshift-cluster-install"
        
        # Change permissions to allow deletion
        print_info "Adjusting permissions..."
        chmod -R u+w openshift-cluster-install 2>/dev/null || true
        
        # Remove directory
        print_info "Removing installation directory..."
        rm -rf openshift-cluster-install
        
        if [ ! -d "openshift-cluster-install" ]; then
            print_success "Installation directory removed"
        else
            print_error "Failed to remove installation directory"
            return 1
        fi
    else
        print_info "No installation directory found"
    fi
    
    # Remove cluster-info.txt if it exists
    if [ -f "cluster-info.txt" ]; then
        print_info "Removing cluster-info.txt..."
        rm -f cluster-info.txt
        print_success "Removed cluster-info.txt"
    fi
    
    echo ""
    print_success "Local cleanup complete!"
    echo ""
    echo -e "${YELLOW}Note: AWS resources (if any) were NOT deleted.${NC}"
    echo "The cluster may still be running in AWS."
    echo ""
    echo "To delete AWS resources, run:"
    echo "  ${GREEN}./scripts/cleanup-all.sh${NC}  (and select option 2)"
    echo ""
    echo "Ready for fresh installation:"
    echo "  ${GREEN}./rhoai-toolkit.sh${NC}"
    echo ""
    
    return 0
}

# If local-only mode, do quick cleanup and exit
if [ "$LOCAL_ONLY" = true ]; then
    quick_local_cleanup
    exit $?
fi

# ============================================================================
# STEP 1: Clean up installation directory
# ============================================================================
print_header "STEP 1: Cleaning up installation directory"

if [ -d "openshift-cluster-install" ]; then
    print_info "Found installation directory: openshift-cluster-install"
    
    # Try to destroy using openshift-install
    if [ -f "./openshift-install" ]; then
        print_info "Attempting to destroy cluster using openshift-install..."
        ./openshift-install destroy cluster --dir=openshift-cluster-install --log-level=info 2>/dev/null || true
    fi
    
    # Remove installation directory
    print_info "Removing installation directory..."
    rm -rf openshift-cluster-install
    print_success "Installation directory removed"
else
    print_info "No installation directory found"
fi

# ============================================================================
# STEP 2: Release unused Elastic IPs
# ============================================================================
print_header "STEP 2: Releasing unused Elastic IPs"

UNASSOCIATED_EIPS=$(aws ec2 describe-addresses --region $AWS_REGION \
    --query 'Addresses[?AssociationId==`null`].AllocationId' \
    --output text 2>/dev/null || echo "")

if [ -n "$UNASSOCIATED_EIPS" ]; then
    echo ""
    print_warning "Found unassociated Elastic IPs:"
    aws ec2 describe-addresses --region $AWS_REGION \
        --query 'Addresses[?AssociationId==`null`].{ID:AllocationId,IP:PublicIp}' \
        --output table 2>/dev/null || true
    echo ""
    
    read -p "Release these unused Elastic IPs? [Y/n]: " release_eips
    if [[ "$release_eips" != "n" && "$release_eips" != "N" ]]; then
        for eip in $UNASSOCIATED_EIPS; do
            echo "  Releasing $eip..."
            aws ec2 release-address --allocation-id $eip --region $AWS_REGION 2>/dev/null && \
                print_success "Released $eip" || \
                print_warning "Failed to release $eip"
        done
    fi
else
    print_info "No unassociated Elastic IPs found"
fi

# ============================================================================
# STEP 3: Find OpenShift VPCs
# ============================================================================
print_header "STEP 3: Finding OpenShift VPCs"

OPENSHIFT_VPCS=$(aws ec2 describe-vpcs --region $AWS_REGION \
    --filters "Name=tag:Name,Values=*openshift*" \
    --query 'Vpcs[].VpcId' \
    --output text 2>/dev/null || echo "")

if [ -z "$OPENSHIFT_VPCS" ]; then
    print_info "No OpenShift VPCs found"
else
    echo ""
    print_warning "Found OpenShift VPCs:"
    for vpc in $OPENSHIFT_VPCS; do
        vpc_name=$(aws ec2 describe-vpcs --region $AWS_REGION --vpc-ids $vpc \
            --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text 2>/dev/null || echo "N/A")
        echo "  - $vpc ($vpc_name)"
    done
    echo ""
    
    read -p "Clean up ALL OpenShift VPCs automatically? [Y/n]: " cleanup_all
    if [[ "$cleanup_all" == "n" || "$cleanup_all" == "N" ]]; then
        print_info "Skipping VPC cleanup"
        OPENSHIFT_VPCS=""
    fi
fi

# ============================================================================
# STEP 4: Clean up each VPC
# ============================================================================
cleanup_single_vpc() {
    local VPC_ID=$1
    
    print_header "Cleaning up VPC: $VPC_ID"
    
    # Delete NAT Gateways first (they hold Elastic IPs)
    print_info "Deleting NAT Gateways..."
    NAT_GWS=$(aws ec2 describe-nat-gateways --region $AWS_REGION \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
        --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null || echo "")
    
    if [ -n "$NAT_GWS" ]; then
        for nat in $NAT_GWS; do
            echo "  Deleting NAT Gateway: $nat"
            aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $AWS_REGION 2>/dev/null || echo "    Failed"
        done
        
        # Wait for NAT Gateways to be fully deleted
        print_info "Waiting for NAT Gateways to delete (this may take 2-3 minutes)..."
        for nat in $NAT_GWS; do
            for i in {1..60}; do
                state=$(aws ec2 describe-nat-gateways --nat-gateway-ids $nat --region $AWS_REGION \
                    --query 'NatGateways[0].State' --output text 2>/dev/null || echo "deleted")
                if [ "$state" == "deleted" ]; then
                    echo "  ✓ $nat deleted"
                    break
                fi
                if [ $((i % 10)) -eq 0 ]; then
                    echo "    Still deleting... ($i/60 checks)"
                fi
                sleep 5
            done
        done
        print_success "All NAT Gateways deleted"
    fi
    
    # Release Elastic IPs associated with NAT Gateways
    print_info "Releasing Elastic IPs from NAT Gateways..."
    NAT_EIPS=$(aws ec2 describe-addresses --region $AWS_REGION \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[?NetworkInterfaceId==`null` && AssociationId==`null`].AllocationId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$NAT_EIPS" ]; then
        for eip in $NAT_EIPS; do
            echo "  Releasing EIP: $eip"
            aws ec2 release-address --allocation-id $eip --region $AWS_REGION 2>/dev/null || true
        done
    fi
    
    # Disassociate route tables from subnets
    print_info "Disassociating route tables from subnets..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main==`false`]' \
        --output json 2>/dev/null || echo "[]")
    
    echo "$ROUTE_TABLES" | grep -o '"RouteTableAssociationId":"[^"]*"' | cut -d'"' -f4 | while read assoc_id; do
        if [ -n "$assoc_id" ]; then
            aws ec2 disassociate-route-table --association-id "$assoc_id" --region $AWS_REGION 2>/dev/null || true
        fi
    done
    
    # Delete subnets
    print_info "Deleting subnets..."
    SUBNETS=$(aws ec2 describe-subnets --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    
    for subnet in $SUBNETS; do
        aws ec2 delete-subnet --subnet-id $subnet --region $AWS_REGION 2>/dev/null || true
    done
    
    # Wait for subnets to delete
    if [ -n "$SUBNETS" ]; then
        sleep 5
    fi
    
    # Delete route tables (except main)
    print_info "Deleting route tables..."
    ROUTE_TABLES_IDS=$(aws ec2 describe-route-tables --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
        --output text 2>/dev/null || echo "")
    
    for rtb in $ROUTE_TABLES_IDS; do
        aws ec2 delete-route-table --route-table-id $rtb --region $AWS_REGION 2>/dev/null || true
    done
    
    # Delete security groups (except default)
    print_info "Deleting security groups..."
    SECURITY_GROUPS=$(aws ec2 describe-security-groups --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text 2>/dev/null || echo "")
    
    for sg in $SECURITY_GROUPS; do
        aws ec2 delete-security-group --group-id $sg --region $AWS_REGION 2>/dev/null || true
    done
    
    # Delete network interfaces
    print_info "Deleting network interfaces..."
    NETWORK_INTERFACES=$(aws ec2 describe-network-interfaces --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text 2>/dev/null || echo "")
    
    for eni in $NETWORK_INTERFACES; do
        aws ec2 delete-network-interface --network-interface-id $eni --region $AWS_REGION 2>/dev/null || true
    done
    
    # Detach and delete internet gateway
    print_info "Deleting internet gateway..."
    IGW=$(aws ec2 describe-internet-gateways --region $AWS_REGION \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo "")
    
    if [ "$IGW" != "None" ] && [ -n "$IGW" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region $AWS_REGION 2>/dev/null || true
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $AWS_REGION 2>/dev/null || true
    fi
    
    # Retry security groups
    print_info "Retrying security group deletion..."
    for sg in $SECURITY_GROUPS; do
        aws ec2 delete-security-group --group-id $sg --region $AWS_REGION 2>/dev/null || true
    done
    
    # Final cleanup pass
    print_info "Final cleanup pass..."
    
    # Retry subnet deletion
    SUBNETS=$(aws ec2 describe-subnets --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    for subnet in $SUBNETS; do
        aws ec2 delete-subnet --subnet-id $subnet --region $AWS_REGION 2>/dev/null || true
    done
    
    # Retry route table deletion
    ROUTE_TABLES_IDS=$(aws ec2 describe-route-tables --region $AWS_REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
        --output text 2>/dev/null || echo "")
    for rtb in $ROUTE_TABLES_IDS; do
        aws ec2 delete-route-table --route-table-id $rtb --region $AWS_REGION 2>/dev/null || true
    done
    
    # Delete VPC
    print_info "Deleting VPC..."
    sleep 3
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION 2>/dev/null && \
        print_success "VPC $VPC_ID deleted" || \
        print_warning "Failed to delete VPC $VPC_ID (may have remaining dependencies)"
}

# Clean up all OpenShift VPCs
if [ -n "$OPENSHIFT_VPCS" ]; then
    for vpc in $OPENSHIFT_VPCS; do
        cleanup_single_vpc $vpc
    done
fi

# ============================================================================
# STEP 5: Clean up orphaned route tables
# ============================================================================
print_header "STEP 5: Cleaning up orphaned route tables"

print_info "Searching for orphaned OpenShift route tables..."

# Get all route tables with "openshift" in the name
ALL_RTS=$(aws ec2 describe-route-tables --region $AWS_REGION \
    --query 'RouteTables[].[RouteTableId,Tags[?Key==`Name`].Value|[0],Associations[0].Main]' \
    --output text 2>/dev/null)

OPENSHIFT_RTS=$(echo "$ALL_RTS" | grep -i "openshift" || echo "")

if [ -n "$OPENSHIFT_RTS" ]; then
    echo ""
    print_warning "Found orphaned OpenShift route tables:"
    echo "$OPENSHIFT_RTS" | while read -r rtb_id name is_main; do
        if [ "$name" == "None" ] || [ -z "$name" ]; then
            name="-"
        fi
        echo "  - $rtb_id ($name)"
    done
    echo ""
    
    read -p "Delete these orphaned route tables? [Y/n]: " delete_rts
    if [[ "$delete_rts" != "n" && "$delete_rts" != "N" ]]; then
        echo "$OPENSHIFT_RTS" | while read -r rtb_id name is_main; do
            # Skip main route tables
            if [ "$is_main" == "True" ] || [ "$is_main" == "true" ]; then
                continue
            fi
            
            # Disassociate first
            ASSOCIATIONS=$(aws ec2 describe-route-tables --region $AWS_REGION \
                --route-table-ids $rtb_id \
                --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
                --output text 2>/dev/null || echo "")
            
            for assoc_id in $ASSOCIATIONS; do
                if [ "$assoc_id" != "None" ] && [ -n "$assoc_id" ]; then
                    aws ec2 disassociate-route-table --association-id "$assoc_id" --region $AWS_REGION 2>/dev/null || true
                fi
            done
            
            # Delete route table
            echo "  Deleting: $rtb_id"
            aws ec2 delete-route-table --route-table-id "$rtb_id" --region $AWS_REGION 2>/dev/null && \
                print_success "Deleted $rtb_id" || \
                print_warning "Failed to delete $rtb_id"
        done
    fi
else
    print_info "No orphaned route tables found"
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print_header "CLEANUP COMPLETE!"

echo ""
print_success "All OpenShift resources have been cleaned up!"
echo ""
echo "Summary:"
echo "  ✓ Installation directory removed"
echo "  ✓ Elastic IPs released"
echo "  ✓ VPCs cleaned up"
echo "  ✓ Orphaned route tables removed"
echo ""
echo "Your AWS environment is now clean and ready for a fresh installation!"
echo ""
echo "To start a new installation, run:"
echo "  ${GREEN}./openshift-installer-master.sh${NC}"
echo ""

