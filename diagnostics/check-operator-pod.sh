#!/bin/bash

echo "Checking all namespaces for RHCL operator pod..."
echo ""

echo "1. Checking openshift-operators namespace:"
oc get pods -n openshift-operators | grep -i rhcl || echo "Not found in openshift-operators"
echo ""

echo "2. Checking kuadrant-system namespace:"
oc get pods -n kuadrant-system | grep -i rhcl || echo "Not found in kuadrant-system"
echo ""

echo "3. Checking for any RHCL-related pods across all namespaces:"
oc get pods -A | grep -i rhcl || echo "No RHCL pods found anywhere"
echo ""

echo "4. Checking RHCL operator subscription details:"
oc get subscription rhcl-operator -n kuadrant-system -o yaml
echo ""

echo "5. Checking install plan:"
oc get installplan -n kuadrant-system
echo ""

echo "6. Checking CSV (ClusterServiceVersion):"
oc get csv -n kuadrant-system | grep rhcl
echo ""

echo "7. Checking operator pod events:"
oc get events -n kuadrant-system --sort-by='.lastTimestamp' | tail -20

