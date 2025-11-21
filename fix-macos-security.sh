#!/bin/bash

#############################################################################
# Fix macOS Security Warning for OpenShift Installer
# This script removes the quarantine attribute from the openshift-install binary
#############################################################################

echo "Removing quarantine attribute from openshift-install binary..."

# Remove quarantine attribute
xattr -d com.apple.quarantine openshift-install 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Successfully removed quarantine attribute"
    echo ""
    echo "You can now run: ./openshift-install version"
else
    echo "Note: Quarantine attribute may not exist or was already removed"
fi

# Verify the binary is executable
chmod +x openshift-install

echo "✓ Ensured openshift-install is executable"
echo ""
echo "Testing the binary..."
./openshift-install version

echo ""
echo "If you still see a security warning, you can also:"
echo "1. Go to System Settings > Privacy & Security"
echo "2. Scroll down to find the blocked app"
echo "3. Click 'Allow Anyway'"

