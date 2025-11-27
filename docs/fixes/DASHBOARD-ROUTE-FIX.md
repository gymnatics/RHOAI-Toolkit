# RHOAI Dashboard Route Creation Fix

## Problem

On fresh RHOAI 3.0 installations, the dashboard route (`rhods-dashboard`) may not be automatically created even though:
- The dashboard deployment is ready (2/2 replicas)
- The dashboard pods are running and healthy
- The dashboard service exists

This is a timing/orchestration issue where the RHOAI operator doesn't immediately create the route after the dashboard deployment is ready.

## Symptoms

```bash
# Dashboard deployment is ready
$ oc get deployment rhods-dashboard -n redhat-ods-applications
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
rhods-dashboard   2/2     2            2           5m

# Dashboard pods are running
$ oc get pods -n redhat-ods-applications -l app=rhods-dashboard
NAME                              READY   STATUS    RESTARTS   AGE
rhods-dashboard-6c8744b89-ndc8z   4/4     Running   0          5m
rhods-dashboard-6c8744b89-pcfgd   4/4     Running   0          5m

# Dashboard service exists
$ oc get svc rhods-dashboard -n redhat-ods-applications
NAME              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
rhods-dashboard   ClusterIP   172.30.185.161   <none>        8443/TCP,8043/TCP,8143/TCP   5m

# But NO route exists
$ oc get route rhods-dashboard -n redhat-ods-applications
No resources found in redhat-ods-applications namespace.
```

## Root Cause

The RHOAI operator creates the dashboard deployment and service but may delay route creation due to:
1. Internal orchestration timing in fresh clusters
2. Dependency on other components being fully initialized
3. Possible webhook or admission controller delays

## Solution

The fix automatically creates the dashboard route if it doesn't exist after the deployment is ready.

### Implementation

The `integrated-workflow-v2.sh` script now:

1. **Waits for deployment and service** to exist
2. **Waits for pods to be ready** (using `oc wait`)
3. **Checks if route exists**
4. **Creates route if missing** using the standard RHOAI dashboard route spec

### Route Specification

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: rhods-dashboard
  namespace: redhat-ods-applications
  labels:
    app: rhods-dashboard
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: rhods-dashboard
    weight: 100
  wildcardPolicy: None
```

## Manual Fix

If you encounter this issue and need to manually create the route:

```bash
# Export kubeconfig
export KUBECONFIG=/path/to/kubeconfig

# Verify dashboard is ready
oc get deployment rhods-dashboard -n redhat-ods-applications
oc get pods -n redhat-ods-applications -l app=rhods-dashboard
oc get svc rhods-dashboard -n redhat-ods-applications

# Create the route
cat <<'EOF' | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: rhods-dashboard
  namespace: redhat-ods-applications
  labels:
    app: rhods-dashboard
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: rhods-dashboard
    weight: 100
  wildcardPolicy: None
EOF

# Verify route was created
oc get route rhods-dashboard -n redhat-ods-applications

# Get dashboard URL
echo "Dashboard URL: https://$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')"
```

## Verification

After the fix is applied, verify:

```bash
# 1. Check route exists
oc get route rhods-dashboard -n redhat-ods-applications

# 2. Get dashboard URL
DASHBOARD_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')
echo "Dashboard: https://$DASHBOARD_URL"

# 3. Test route connectivity (optional)
curl -k -I "https://$DASHBOARD_URL"
```

Expected output:
```
NAME              HOST/PORT                                                                PATH   SERVICES          PORT    TERMINATION          WILDCARD
rhods-dashboard   rhods-dashboard-redhat-ods-applications.apps.cluster.example.com                rhods-dashboard   https   reencrypt/Redirect   None

Dashboard: https://rhods-dashboard-redhat-ods-applications.apps.cluster.example.com
```

## When This Occurs

This issue is most common in:
- **Fresh RHOAI 3.0 installations** on newly provisioned OpenShift clusters
- **Sandbox/temporary environments** where DNS propagation may be delayed
- **Fast installations** where components come up quickly before full reconciliation

## Related Issues

This fix complements other timing-related fixes:
- **Kuadrant/Authorino Fix**: CRD registration timing issue ([KUADRANT-FRESH-CLUSTER-FIX.md](KUADRANT-FRESH-CLUSTER-FIX.md))
- **RHOAI Webhook Fix**: DSCInitialization timing issue (in `lib/functions/rhoai.sh`)

## Status

✅ **Implemented** in `integrated-workflow-v2.sh` as of Nov 27, 2025

The script now automatically handles this scenario without user intervention.

