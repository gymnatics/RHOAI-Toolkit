# KServe Deployment Modes: RawDeployment vs Serverless

## What the Reference Repository Uses

The reference repository ([tsailiming/openshift-ai-bootstrap, rhoai-3 branch](https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3)) uses **KServe RawDeployment mode** instead of Kueue-based deployment.

## Two Approaches to Model Deployment in RHOAI 3.0

### 1. **RawDeployment Mode (Reference Repo's Approach)**

#### Configuration

```yaml
# DataScienceCluster
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    kserve:
      managementState: Managed
      rawDeploymentServiceConfig: Headless  # ← Key setting!
    kueue:
      managementState: Removed  # ← Kueue not needed!
```

```yaml
# InferenceService
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment  # ← Key annotation!
    opendatahub.io/hardware-profile-name: nvidia-gpu
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
spec:
  predictor:
    model:
      resources:
        limits:
          nvidia.com/gpu: '1'  # ← Direct resource specification
```

#### How It Works

1. **Direct Kubernetes Deployment**: Models are deployed as standard Kubernetes Deployments
2. **No Serverless**: No Knative Serving, no auto-scaling to zero
3. **No Kueue**: No queue management, no resource quotas
4. **Hardware Profiles**: Used as **annotations only** for UI display
5. **Resource Requests**: Specified directly in the InferenceService YAML
6. **Always Running**: Pods stay running (no scale-to-zero)

#### Advantages

- ✅ Simpler architecture (no Knative, no Kueue)
- ✅ Faster startup (no cold starts)
- ✅ More predictable behavior
- ✅ Better for demos and development
- ✅ Works well for always-on inference workloads

#### Disadvantages

- ❌ No auto-scaling to zero (wastes resources when idle)
- ❌ No queue management (can't handle burst traffic)
- ❌ No resource quotas (can over-provision)
- ❌ Manual scaling required

---

### 2. **Serverless Mode with Kueue (Dashboard/UI Approach)**

#### Configuration

```yaml
# DataScienceCluster
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    kserve:
      managementState: Managed
      # No rawDeploymentServiceConfig (uses Serverless by default)
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged  # ← Kueue enabled!
```

```yaml
# InferenceService (created via Dashboard)
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    # No deploymentMode annotation (defaults to Serverless)
    opendatahub.io/hardware-profile-name: nvidia-gpu
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
  labels:
    kueue.x-k8s.io/queue-name: default  # ← Kueue queue label
spec:
  predictor:
    model:
      # Resources come from HardwareProfile
```

#### How It Works

1. **Knative Serving**: Models are deployed as Knative Services
2. **Auto-scaling**: Can scale to zero when idle, scale up on demand
3. **Kueue Integration**: Queue management, resource quotas, fair sharing
4. **Hardware Profiles**: Used to **inject resources** into the InferenceService
5. **Resource Management**: Kueue manages ClusterQueues and LocalQueues
6. **Dynamic Scaling**: Pods can scale based on traffic

#### Advantages

- ✅ Auto-scaling to zero (saves resources)
- ✅ Queue management (handles burst traffic)
- ✅ Resource quotas (prevents over-provisioning)
- ✅ Fair resource sharing across projects
- ✅ Better for production multi-tenant environments

#### Disadvantages

- ❌ More complex architecture (Knative + Kueue)
- ❌ Cold starts (latency when scaling from zero)
- ❌ More moving parts (more things to troubleshoot)
- ❌ Requires understanding of Kueue concepts

---

## Comparison Table

| Feature | RawDeployment | Serverless + Kueue |
|---------|---------------|-------------------|
| **Deployment Type** | Kubernetes Deployment | Knative Service |
| **Auto-scaling** | Manual only | Automatic (including to zero) |
| **Kueue Required** | No | Yes |
| **Hardware Profiles** | Annotations only | Resource injection |
| **Cold Starts** | No | Yes |
| **Resource Management** | Manual | Kueue-managed |
| **Complexity** | Low | High |
| **Best For** | Demos, dev, always-on | Production, multi-tenant |
| **Dashboard Support** | Limited | Full |

---

## Why the Reference Repo Uses RawDeployment

1. **Simplicity**: Easier to understand and troubleshoot
2. **Demo Focus**: The repo is for demos and testing, not production
3. **No Cold Starts**: Better for interactive demos
4. **Direct Control**: More control over resources and scaling
5. **Fewer Dependencies**: No need for Knative Serving or Kueue

---

## Why RHOAI Dashboard Uses Serverless + Kueue

1. **Production Ready**: Designed for multi-tenant production environments
2. **Resource Efficiency**: Auto-scaling saves costs
3. **Fair Sharing**: Kueue ensures fair resource allocation
4. **Enterprise Features**: Queue management, quotas, priorities
5. **Red Hat Support**: Fully supported by Red Hat

---

## Hardware Profiles in Both Modes

### RawDeployment Mode

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    opendatahub.io/hardware-profile-name: nvidia-gpu  # ← For UI display only
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
spec:
  predictor:
    model:
      resources:  # ← Resources specified directly
        limits:
          cpu: '2'
          memory: 24Gi
          nvidia.com/gpu: '1'
```

**Hardware profiles are used for**:
- UI display and organization
- Metadata and annotations
- **NOT** for resource injection

### Serverless + Kueue Mode

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    opendatahub.io/hardware-profile-name: nvidia-gpu  # ← Profile to use
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
spec:
  predictor:
    model:
      # Resources are INJECTED from the HardwareProfile by the dashboard
```

**Hardware profiles are used for**:
- UI display and organization
- **Resource injection** (CPU, Memory, GPU)
- Scheduling constraints (nodeSelector, tolerations)
- Kueue integration

---

## Which Should You Use?

### Use **RawDeployment** if:
- ✅ You're doing demos or development
- ✅ You want simple, predictable behavior
- ✅ You need models always running (no cold starts)
- ✅ You're comfortable managing resources manually
- ✅ You don't need multi-tenant resource management

### Use **Serverless + Kueue** if:
- ✅ You're deploying to production
- ✅ You need auto-scaling and resource efficiency
- ✅ You have multiple teams/projects sharing resources
- ✅ You want fair resource allocation and quotas
- ✅ You're using the RHOAI Dashboard for deployment

---

## Converting Between Modes

### From Serverless to RawDeployment

1. Set `rawDeploymentServiceConfig: Headless` in DataScienceCluster
2. Set Kueue to `Removed`
3. Add `serving.kserve.io/deploymentMode: RawDeployment` to InferenceService
4. Specify resources directly in InferenceService spec

### From RawDeployment to Serverless

1. Remove `rawDeploymentServiceConfig` from DataScienceCluster
2. Set Kueue to `Unmanaged`
3. Remove `serving.kserve.io/deploymentMode` annotation
4. Let hardware profiles inject resources

---

## Summary

The reference repository uses **RawDeployment mode** because:
- It's simpler for demos
- No Kueue needed
- No cold starts
- Direct resource control

Your setup uses **Serverless + Kueue mode** because:
- You're using the RHOAI Dashboard
- You want production-ready features
- You need resource management
- You want auto-scaling

**Both are valid approaches!** The choice depends on your use case. 🚀

## References

- Reference Repository: [tsailiming/openshift-ai-bootstrap (rhoai-3 branch)](https://github.com/tsailiming/openshift-ai-bootstrap/tree/rhoai-3)
- KServe Documentation: [KServe Deployment Modes](https://kserve.github.io/website/latest/modelserving/v1beta1/serving_runtime/)
- RHOAI Documentation: [Model Serving](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0/html/serving_models/index)

