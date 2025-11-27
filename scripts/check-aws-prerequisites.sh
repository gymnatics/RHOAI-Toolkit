#!/bin/bash

################################################################################
# Standalone AWS Prerequisites Checker for OpenShift Installation
#
# Usage:
#   ./scripts/check-aws-prerequisites.sh
#
# This script validates your AWS environment before OpenShift installation:
#   - AWS CLI and credentials
#   - Route53 hosted zones
#   - Service quotas
#   - Existing resources
#   - SSH configuration
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the AWS checks library
if [ -f "$SCRIPT_DIR/lib/utils/aws-checks.sh" ]; then
    source "$SCRIPT_DIR/lib/utils/aws-checks.sh"
else
    echo "ERROR: aws-checks.sh not found at $SCRIPT_DIR/lib/utils/aws-checks.sh"
    exit 1
fi

# Run the checks
check_aws_prerequisites

exit $?

