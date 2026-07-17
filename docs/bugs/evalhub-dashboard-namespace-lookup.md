# Finding: EvalHub CR Must Be Deployed in `redhat-ods-applications` for Dashboard UI

## Summary

The RHOAI Dashboard "Evaluations" page displays **"Evaluations unavailable — To use evaluations, enable the evaluation service using the TrustyAI Operator"** when the EvalHub CR is only deployed in a user project namespace (e.g., `lmeval-demo`). The `eval-hub-ui` sidecar container in the dashboard pod requires the EvalHub CR to exist in `redhat-ods-applications` (the operator namespace). This appears to be by design -- EvalHub is a shared central service, not per-project.

## Environment

| Component | Version |
|---|---|
| RHOAI | 1.3.1 (RHOAI 3.4) |
| OpenShift | 4.20.23 |
| Platform | AWS (us-east-2) |
| Dashboard Config | `disableLMEval: false` |
| TrustyAI | `managementState: Managed` in DSC |

## Steps to Reproduce

1. Deploy RHOAI 3.4 with TrustyAI set to `Managed` in DataScienceCluster
2. Confirm `disableLMEval: false` in `odhdashboardconfig`
3. Create a project namespace (e.g., `lmeval-demo`)
4. Deploy an EvalHub CR in that namespace:
   ```bash
   oc apply -f - <<EOF
   apiVersion: trustyai.opendatahub.io/v1alpha1
   kind: EvalHub
   metadata:
     name: evalhub
     namespace: lmeval-demo
   spec:
     replicas: 1
     database:
       type: sqlite
     providers:
       - lm-evaluation-harness
   EOF
   ```
5. Wait for EvalHub to become `Ready=True`:
   ```
   $ oc get evalhub -n lmeval-demo
   NAME      PHASE   READY   AGE
   evalhub   Ready   True    4h48m
   ```
6. Confirm the pod is running:
   ```
   $ oc get pods -n lmeval-demo -l app=eval-hub
   NAME                       READY   STATUS    RESTARTS   AGE
   evalhub-6f66db8c6c-xwvcg   1/1     Running   0          4h48m
   ```
7. Navigate to Dashboard > Develop & train > Evaluations
8. Select project `lmeval-demo`

## Expected Behavior

The Evaluations page should detect the healthy EvalHub CR in the selected project namespace and show the evaluation UI (job submission, benchmark discovery, results).

## Actual Behavior

The page shows: **"Evaluations unavailable — To use evaluations, enable the evaluation service using the TrustyAI Operator."**

## Root Cause

The `eval-hub-ui` sidecar container in the `rhods-dashboard` deployment only looks for the EvalHub CR **in its own namespace** (`redhat-ods-applications`), not in the user's selected project namespace.

### Evidence

**eval-hub-ui sidecar startup log:**
```
time=2026-06-04T06:43:38.477Z level=INFO msg="Detected dashboard namespace" namespace=redhat-ods-applications
time=2026-06-04T06:43:38.484Z level=INFO msg="starting server" addr=:8543 "TLS enabled"=true
```

**eval-hub-ui sidecar error logs (when user visits Evaluations page with project=lmeval-demo):**
```
time=2026-06-05T14:32:03.067Z level=ERROR msg="EvalHub CR not found in namespace \"redhat-ods-applications\" — operator not configured" method=GET uri="/api/v1/evaluations/collections?namespace=lmeval-demo&limit=200"
```

Note: the request URL includes `namespace=lmeval-demo` as a query parameter, but the sidecar ignores it and only queries `redhat-ods-applications`.

### Dashboard proxy chain

```
Browser → dashboard (rhods-dashboard container)
       → proxy to eval-hub-ui sidecar (:8543)
       → sidecar looks up EvalHub CR in redhat-ods-applications (WRONG)
       → returns "not found" → dashboard shows "Evaluations unavailable"
```

## Solution

Deploy the EvalHub CR in `redhat-ods-applications` (the operator namespace), not in user project namespaces. This is likely the intended deployment pattern -- EvalHub acts as a shared central service:

```bash
cat <<EOF | oc apply -f -
apiVersion: trustyai.opendatahub.io/v1alpha1
kind: EvalHub
metadata:
  name: evalhub
  namespace: redhat-ods-applications
spec:
  replicas: 1
  database:
    type: sqlite
  providers:
    - lm-evaluation-harness
    - garak
    - guidellm
    - lighteval
  collections:
    - leaderboard-v2
    - safety-and-fairness-v1
EOF
```

If the dashboard was already running before deploying the CR, restart it:
```bash
oc rollout restart deployment/rhods-dashboard -n redhat-ods-applications
```

## Documentation Gap

The RHOAI 3.4 documentation does not clearly state that the EvalHub CR must be deployed in `redhat-ods-applications`. Users may naturally deploy it in their project namespace (like other demo resources), leading to a confusing "Evaluations unavailable" message even though the EvalHub backend is healthy.

## Supporting Data

**Dashboard config (verified correct):**
```json
{
    "disableLMEval": false,
    "observabilityDashboard": true
}
```

**DSC TrustyAI config:**
```json
{"managementState": "Managed", "mcpGuardrailsMode": false}
```

**CRDs present:**
```
evalhubs.trustyai.opendatahub.io      2026-06-04T06:13:57Z
lmevaljobs.trustyai.opendatahub.io    2026-06-04T06:13:58Z
```

**EvalHub CR status (in lmeval-demo):**
```yaml
status:
  phase: Ready
  ready: "True"
  readyReplicas: 1
  conditions:
    - type: Ready
      status: "True"
      reason: DeploymentReady
      message: All replicas are ready
  url: https://evalhub.lmeval-demo.svc.cluster.local:8443
```
