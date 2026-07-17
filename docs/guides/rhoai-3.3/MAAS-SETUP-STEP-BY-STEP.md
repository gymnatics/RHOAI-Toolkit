# MaaS Setup Step-by-Step Guide

Complete guide to set up Models-as-a-Service (MaaS) with tier-based rate limiting on RHOAI 3.3.

## Prerequisites

- OpenShift 4.19+
- RHOAI 3.3 operator installed
- Red Hat Connectivity Link (RHCL/Kuadrant) 1.3+ installed
- `oc` CLI logged in with cluster-admin

## Step 1: Create GatewayClass

```bash
oc apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-gateway-controller
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
```

## Step 2: Create maas-default-gateway

```bash
# Get your cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
echo "Cluster domain: $CLUSTER_DOMAIN"

# Create the gateway
cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: maas-default-gateway
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-gateway-controller
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: maas-api.apps.${CLUSTER_DOMAIN}
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF
```

## Step 3: Create TLS Secret (if not exists)

```bash
# Check if secret exists
oc get secret default-gateway-tls -n openshift-ingress

# If not, create a self-signed certificate
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=*.apps.${CLUSTER_DOMAIN}" \
  -addext "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:maas-api.apps.${CLUSTER_DOMAIN}"

oc create secret tls default-gateway-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n openshift-ingress

rm /tmp/tls.key /tmp/tls.crt
```

## Step 4: Verify Gateway is Programmed

```bash
oc get gateway maas-default-gateway -n openshift-ingress

# Expected output:
# NAME                   CLASS                          ADDRESS   PROGRAMMED   AGE
# maas-default-gateway   openshift-gateway-controller   ...       True         ...
```

## Step 5: Enable MaaS in DataScienceCluster

```bash
oc patch datasciencecluster default-dsc --type=merge -p '
{
  "spec": {
    "components": {
      "kserve": {
        "managementState": "Managed",
        "modelsAsService": {
          "managementState": "Managed"
        }
      }
    }
  }
}'
```

## Step 6: Verify MaaS Components

```bash
# Check maas-api is running
oc get pods -n redhat-ods-applications -l app=maas-api

# Check tier-to-group-mapping ConfigMap exists
oc get configmap tier-to-group-mapping -n redhat-ods-applications
```

## Step 7: Deploy a Model with MaaS

```bash
NAMESPACE="maas-demo"
MODEL_NAME="qwen3-4b"

# Create namespace
oc new-project $NAMESPACE 2>/dev/null || oc project $NAMESPACE

# Deploy LLMInferenceService
cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: ${MODEL_NAME}
  namespace: ${NAMESPACE}
  annotations:
    alpha.maas.opendatahub.io/tiers: '["free","premium","enterprise"]'
    security.opendatahub.io/enable-auth: "true"
spec:
  model:
    url: oci://quay.io/modh/qwen3:4b
  router:
    targetUtilization: 90
  template:
    spec:
      containers:
        - name: kserve-container
          resources:
            limits:
              nvidia.com/gpu: "1"
            requests:
              nvidia.com/gpu: "1"
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
EOF

# Wait for model to be ready
echo "Waiting for model to be ready..."
oc wait --for=condition=Ready llminferenceservice/${MODEL_NAME} -n ${NAMESPACE} --timeout=600s
```

## Step 8: Create Tier ServiceAccounts

```bash
NAMESPACE="maas-demo"

# Create ServiceAccounts for each tier
for tier in free premium enterprise; do
  oc create serviceaccount tier-${tier}-sa -n $NAMESPACE 2>/dev/null || echo "SA tier-${tier}-sa exists"
done

# Create Role for model access
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llminferenceservice-access
  namespace: ${NAMESPACE}
rules:
- apiGroups: ["serving.kserve.io"]
  resources: ["llminferenceservices"]
  verbs: ["get"]
EOF

# Create RoleBindings
for tier in free premium enterprise; do
  oc create rolebinding tier-${tier}-sa-access \
    --role=llminferenceservice-access \
    --serviceaccount=${NAMESPACE}:tier-${tier}-sa \
    -n $NAMESPACE 2>/dev/null || echo "RoleBinding exists"
done
```

## Step 9: Fix tier-to-group-mapping ConfigMap

This is critical - Kubernetes TokenReview doesn't return OpenShift groups, so we use SA usernames:

```bash
NAMESPACE="maas-demo"

cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: tier-to-group-mapping
  namespace: redhat-ods-applications
  labels:
    app: maas-api
    app.kubernetes.io/component: api
    app.kubernetes.io/name: maas-api
    app.kubernetes.io/part-of: models-as-a-service
    app.opendatahub.io/modelsasservice: "true"
    component: tier-mapping
    platform.opendatahub.io/part-of: modelsasservice
data:
  tiers: |
    - name: enterprise
      displayName: Enterprise Tier
      groups:
        - system:serviceaccount:${NAMESPACE}:tier-enterprise-sa
      level: 2
    - name: premium
      displayName: Premium Tier
      groups:
        - system:serviceaccount:${NAMESPACE}:tier-premium-sa
      level: 1
    - name: free
      displayName: Free Tier
      groups:
        - system:serviceaccount:${NAMESPACE}:tier-free-sa
        - system:authenticated
      level: 0
EOF

# Restart maas-api to pick up changes
oc rollout restart deployment/maas-api -n redhat-ods-applications
oc rollout status deployment/maas-api -n redhat-ods-applications --timeout=120s
```

## Step 10: Apply AuthPolicy with Tier Lookup

Wait for the AuthPolicy to be created by odh-model-controller, then patch it:

```bash
# Wait for AuthPolicy to exist
echo "Waiting for AuthPolicy..."
until oc get authpolicy maas-default-gateway-authn -n openshift-ingress &>/dev/null; do
  sleep 5
  echo "  waiting..."
done
echo "AuthPolicy found!"

# Apply the complete AuthPolicy with tier lookup
cat <<'EOF' | oc apply -f -
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: maas-default-gateway-authn
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/component: llminferenceservice-policies
    app.kubernetes.io/managed-by: odh-model-controller
    app.kubernetes.io/name: llminferenceservice-auth
    app.kubernetes.io/part-of: llminferenceservice
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: maas-default-gateway
  rules:
    authentication:
      kubernetes-user:
        kubernetesTokenReview:
          audiences:
          - https://kubernetes.default.svc
        credentials: {}
        defaults:
          userid:
            expression: auth.identity.user.username
    authorization:
      inference-access:
        kubernetesSubjectAccessReview:
          authorizationGroups:
            expression: auth.identity.user.groups
          resourceAttributes:
            group:
              value: serving.kserve.io
            name:
              expression: request.path.split("/")[2]
            namespace:
              expression: request.path.split("/")[1]
            resource:
              value: llminferenceservices
            verb:
              value: get
          user:
            expression: auth.identity.user.username
        priority: 1
    metadata:
      matchedTier:
        http:
          url: https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/tiers/lookup
          method: POST
          contentType: application/json
          body:
            expression: '{ "groups": auth.identity.user.groups + [auth.identity.user.username] }'
        cache:
          key:
            selector: auth.identity.user.username
          ttl: 300
    response:
      success:
        filters:
          identity:
            json:
              properties:
                tier:
                  expression: auth.metadata.matchedTier["tier"]
                userid:
                  expression: auth.identity.user.username
EOF
```

## Step 11: Apply TokenRateLimitPolicy

```bash
# Delete any conflicting UI-created policies first
oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found

# Apply combined policy
cat <<'EOF' | oc apply -f -
apiVersion: kuadrant.io/v1alpha1
kind: TokenRateLimitPolicy
metadata:
  name: maas-tier-token-rate-limits
  namespace: openshift-ingress
  labels:
    opendatahub.io/dashboard: "true"
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: maas-default-gateway
  limits:
    free-tokens:
      rates:
        - limit: 1000
          window: 1m0s
      when:
        - predicate: 'auth.identity.tier == "free" && !request.path.endsWith("/v1/models")'
      counters:
        - expression: auth.identity.userid
    premium-tokens:
      rates:
        - limit: 5000
          window: 1m0s
      when:
        - predicate: 'auth.identity.tier == "premium" && !request.path.endsWith("/v1/models")'
      counters:
        - expression: auth.identity.userid
    enterprise-tokens:
      rates:
        - limit: 10000
          window: 1m0s
      when:
        - predicate: 'auth.identity.tier == "enterprise" && !request.path.endsWith("/v1/models")'
      counters:
        - expression: auth.identity.userid
EOF
```

## Step 12: Clear Caches

```bash
# Restart Authorino to clear tier lookup cache
oc rollout restart deployment/authorino -n kuadrant-system
oc rollout status deployment/authorino -n kuadrant-system --timeout=120s

# Restart Limitador to clear rate limit counters
oc rollout restart deployment/limitador-limitador -n kuadrant-system
oc rollout status deployment/limitador-limitador -n kuadrant-system --timeout=120s
```

## Step 13: Verify Setup

```bash
# Check policies are enforced
echo "=== AuthPolicy Status ==="
oc get authpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status'

echo ""
echo "=== TokenRateLimitPolicy Status ==="
oc get tokenratelimitpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status'

echo ""
echo "=== Model Status ==="
oc get llminferenceservice -n maas-demo
```

## Step 14: Test Rate Limiting

```bash
NAMESPACE="maas-demo"
MODEL_NAME="qwen3-4b"
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

# Generate Free tier token
FREE_TOKEN=$(oc create token tier-free-sa -n $NAMESPACE --duration=1h --audience=https://kubernetes.default.svc)

echo "Testing Free tier (1000 tokens/min limit)..."
for i in 1 2 3 4 5; do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    "https://maas-api.apps.${CLUSTER_DOMAIN}/${NAMESPACE}/${MODEL_NAME}/v1/chat/completions" \
    -H "Authorization: Bearer $FREE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"model":"'${MODEL_NAME}'","messages":[{"role":"user","content":"Write a poem"}],"max_tokens":500}')
  echo "Request $i: HTTP $HTTP_CODE"
  if [ "$HTTP_CODE" = "429" ]; then
    echo "  Rate limited! ✓"
    break
  fi
done

echo ""
echo "Testing Premium tier (5000 tokens/min limit)..."
PREMIUM_TOKEN=$(oc create token tier-premium-sa -n $NAMESPACE --duration=1h --audience=https://kubernetes.default.svc)

for i in 1 2 3 4 5; do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    "https://maas-api.apps.${CLUSTER_DOMAIN}/${NAMESPACE}/${MODEL_NAME}/v1/chat/completions" \
    -H "Authorization: Bearer $PREMIUM_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"model":"'${MODEL_NAME}'","messages":[{"role":"user","content":"Write a poem"}],"max_tokens":500}')
  echo "Request $i: HTTP $HTTP_CODE"
done
```

## Expected Results

- **Free tier**: Should get HTTP 429 after ~2-3 requests (1000 tokens/min)
- **Premium tier**: Should allow more requests before rate limiting (5000 tokens/min)
- **Enterprise tier**: Should allow even more (10000 tokens/min)

## Troubleshooting

### Rate limiting not working?

1. **Check AuthPolicy has tier lookup:**
   ```bash
   oc get authpolicy maas-default-gateway-authn -n openshift-ingress \
     -o jsonpath='{.spec.rules.metadata.matchedTier.http.body.expression}'
   # Should show: { "groups": auth.identity.user.groups + [auth.identity.user.username] }
   ```

2. **Check tier resolution:**
   ```bash
   TOKEN=$(oc create token tier-free-sa -n maas-demo --duration=1h --audience=https://kubernetes.default.svc)
   oc exec -n redhat-ods-applications deploy/maas-api -- curl -sk \
     "https://maas-api.redhat-ods-applications.svc.cluster.local:8443/v1/tiers/lookup" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"groups":["system:authenticated","system:serviceaccount:maas-demo:tier-free-sa"]}'
   # Should return: {"tier":"free","displayName":"Free Tier"}
   ```

3. **Reapply all fixes:**
   ```bash
   # Run steps 9-12 again
   ```

### Model not accessible?

1. **Check model is ready:**
   ```bash
   oc get llminferenceservice -n maas-demo
   ```

2. **Check HTTPRoute is attached to gateway:**
   ```bash
   oc get httproute -n maas-demo -o yaml | grep -A5 parentRefs
   # Should show: name: maas-default-gateway
   ```

## Rate Limits Summary

| Tier | Limit | Window | Use Case |
|------|-------|--------|----------|
| Free | 1,000 tokens | 1 minute | Demo/Testing |
| Premium | 5,000 tokens | 1 minute | Regular users |
| Enterprise | 10,000 tokens | 1 minute | Power users |

For production, change `window: 1m0s` to `window: 1h0m0s` and adjust limits accordingly.
