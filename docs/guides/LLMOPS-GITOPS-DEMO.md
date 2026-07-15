# LLMOps GitOps Demo with ArgoCD

Customer demo walkthrough for deploying LLMs on OpenShift AI using GitOps (ArgoCD + Kustomize).

**Source Repo**: [gymnatics/llmops-demo](https://github.com/gymnatics/llmops-demo) (forked from [jingggg-wenn/llmops-demo](https://github.com/jingggg-wenn/llmops-demo))
**Demo Model**: Qwen 2.5 0.5B Instruct (vLLM)
**GPU Requirement**: 2 GPUs minimum (1 per environment)

---

## Cluster Credentials (This Demo)


| Resource         | URL                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------------- |
| ArgoCD UI        | `https://openshift-gitops-server-openshift-gitops.apps.cluster-79fkf.79fkf.sandbox3605.opentlc.com`   |
| ArgoCD Login     | Username: `admin` / Password: `sbHBz0Z9KiTG23XFSoVWQdeOJrMPu6NI`                                      |
| Dev Endpoint     | `https://dev-qwen25-05b-instruct-llmops-dev.apps.cluster-79fkf.79fkf.sandbox3605.opentlc.com`         |
| Staging Endpoint | `https://staging-qwen25-05b-instruct-llmops-staging.apps.cluster-79fkf.79fkf.sandbox3605.opentlc.com` |


---



## Demo Story (What to Tell the Customer)



### Opening (2 min)

> "Today I'm going to show you how we can apply GitOps principles to LLM deployment on OpenShift AI. Instead of manually deploying models or using push-based CI/CD, we use ArgoCD to continuously watch a Git repo and automatically reconcile the cluster state with what's declared in Git. This gives you drift detection, self-healing, easy rollback, and a full audit trail -- all things that matter when you're running AI models in production."



### Key Points to Hit

1. **Git is the single source of truth** -- all model configurations live in Git, not in someone's head or a wiki.
2. **Pull-based, not push-based** -- ArgoCD runs inside the cluster and pulls from Git. No cluster credentials are stored in GitHub.
3. **Environment promotion** -- dev auto-deploys on merge, staging/prod require manual approval. Same pattern enterprises already use for application code.
4. **Kustomize overlays** -- one base model definition, three environment-specific overlays with different CPU/memory/replica counts. DRY, auditable, reviewable.
5. **Drift detection and self-healing** -- if someone manually changes something on the cluster, ArgoCD detects it and can auto-correct.

---



## Demo Flow (Step by Step)



### Step 1: Show the Architecture (2 min)

Open the GitHub repo and walk through the structure:

```
llmops-via-argocd/
├── argocd-apps/          # 3 ArgoCD Application CRs (dev/staging/prod)
├── deploy_model/
│   ├── base/             # Shared: InferenceService + ServingRuntime + Secret
│   └── overlays/
│       ├── dev/          # 1 replica, 2 CPU, 6Gi, auto-sync
│       ├── staging/      # 1-2 replicas, 3 CPU, 8Gi, manual sync
│       └── production/   # 2-3 replicas, 4 CPU, 12Gi, manual sync
└── setup_scripts/        # One-time setup
```

**Talking point**: "Notice how the base defines the model once -- Qwen 2.5 0.5B on vLLM -- and each overlay just patches the resource allocation and replica count. This is the exact same pattern you'd use for any microservice, applied to AI model deployment."

### Step 2: Show ArgoCD Dashboard (3 min)

Open the ArgoCD UI:

```
https://openshift-gitops-server-openshift-gitops.apps.<cluster-domain>
```

Login with admin credentials or click "LOG IN VIA OPENSHIFT".

**Walk through**:

1. **Application List View** -- Show all three environments at a glance:
  - `llmops-dev`: Synced + Healthy (green)
  - `llmops-staging`: Synced + Healthy (green)
  - `llmops-production`: OutOfSync + Missing (yellow/red) -- this is intentional
2. **Click into** `llmops-dev` -- Show the resource tree:
  - Secret (OCI data connection)
  - ServingRuntime (vLLM engine)
  - InferenceService (the actual model deployment)
  - Deployment, ReplicaSet, Pod (auto-created by KServe)
  - Service, Route (auto-created for endpoint)
3. **Click "APP DIFF"** on production -- Show how ArgoCD knows exactly what would change if you synced.

**Talking point**: "Everything you see here is derived from Git. If I delete a pod, ArgoCD will recreate it. If someone manually patches a resource, ArgoCD detects the drift and can auto-heal. This is continuous reconciliation."

### Step 3: Query the Live Model (2 min)

Show the model is actually serving inference:

```bash
# Dev environment
curl -sk "https://dev-qwen25-05b-instruct-llmops-dev.apps.<cluster>/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dev-qwen25-05b-instruct",
    "messages": [{"role": "user", "content": "What is Kubernetes?"}],
    "max_tokens": 100
  }'

# Staging environment
curl -sk "https://staging-qwen25-05b-instruct-llmops-staging.apps.<cluster>/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "staging-qwen25-05b-instruct",
    "messages": [{"role": "user", "content": "Explain GitOps"}],
    "max_tokens": 100
  }'
```

**Talking point**: "Both environments expose a standard OpenAI-compatible API. Any tool or application that speaks the OpenAI format can consume this endpoint -- LangChain, LlamaIndex, custom apps, or even the OpenShift AI Playground."

### Step 4: Demo the GitOps Workflow -- Make a Live Change (5 min)

This is the key demo moment. Show the end-to-end flow of editing code, pushing to Git, and watching ArgoCD auto-deploy.

**Pre-requisite**: ArgoCD must point to a repo you can push to. If using a fork:

```bash
# Fork the original repo (one-time)
gh repo fork jingggg-wenn/llmops-demo --clone=false

# Update ArgoCD apps to point to your fork
for app in llmops-dev llmops-staging llmops-production; do
  oc patch application.argoproj.io $app -n openshift-gitops --type merge \
    --patch '{"spec":{"source":{"repoURL":"https://github.com/YOUR_USER/llmops-demo.git"}}}'
done

# Clone your fork locally
git clone https://github.com/YOUR_USER/llmops-demo.git /tmp/llmops-demo
```

**Option A: Edit on GitHub UI (easiest for live demo)**

1. Open your fork on GitHub: `https://github.com/YOUR_USER/llmops-demo`
2. Navigate to `llmops-via-argocd/deploy_model/overlays/dev/kustomization.yaml`
3. Click the pencil icon to edit
4. Change the CPU limit from `"2"` to `"3"`:
  ```yaml
   - op: replace
     path: /spec/predictor/model/resources/limits/cpu
     value: "3"   # was "2"
  ```
5. Commit directly to `main` with message: "Dev: Increase CPU to 3 cores"
6. Switch to ArgoCD UI, click "REFRESH" on llmops-dev -- it detects the change and auto-syncs
7. Watch the pod roll out with the updated CPU limit

**Option B: Edit locally and push (more realistic)**

```bash
cd /tmp/llmops-demo

# Edit the dev overlay
# Change CPU limit from "2" to "3"
sed -i '' 's/value: "2"  # CPU limit/value: "3"/' \
  llmops-via-argocd/deploy_model/overlays/dev/kustomization.yaml

# Or manually edit the file:
# vim llmops-via-argocd/deploy_model/overlays/dev/kustomization.yaml

# Commit and push
git add -A
git commit -m "Dev: Increase CPU to 3 cores"
git push origin main
```

**After push (both options)**:

- ArgoCD polls every 3 minutes, or click **REFRESH** in the ArgoCD UI for instant detection
- Dev app briefly shows **OutOfSync**, then auto-syncs
- A new pod rolls out with the updated resource limits
- Verify:
  ```bash
  oc get pods -n llmops-dev -w   # watch the rolling update
  oc describe pod -n llmops-dev -l app=dev-qwen25-05b-instruct-predictor | grep -A 2 "Limits"
  ```

**Talking point**: "That's the full loop. A developer changes a configuration file, pushes to Git, and ArgoCD automatically deploys it. No manual `oc apply`, no CI/CD pipeline to maintain, no cluster credentials in GitHub. And notice how staging and production are NOT affected -- they still require manual approval."

### Step 5: Demo Manual Approval (Staging/Production) (2 min)

1. In ArgoCD UI, click on `llmops-production`
2. Show it says "OutOfSync" -- ArgoCD knows there are resources to create but hasn't deployed them
3. Click **"SYNC"** -- explain this is the manual approval gate
4. (Optional) Actually sync it if you have enough GPUs, or just explain: "In production, a team lead or SRE would review the diff and click Sync. This gives you the control you need for production workloads."

**Talking point**: "The key insight is that dev auto-deploys for fast iteration, but staging and production require a human to approve. This is the same approval pattern enterprises already use -- but now it's built into the deployment tool, not bolted on."

### Step 6: Demo Drift Detection (2 min)

Show what happens when someone makes an unauthorized change:

```bash
# Manually change CPU limit (simulating unauthorized change)
oc patch inferenceservice dev-qwen25-05b-instruct -n llmops-dev \
  --type merge \
  --patch '{"spec":{"predictor":{"model":{"resources":{"limits":{"cpu":"10"}}}}}}'
```

Then in ArgoCD UI:

- Dev app immediately shows "OutOfSync"
- Because dev has `selfHeal: true`, ArgoCD will automatically revert the change within seconds
- Show the pod reverting to the Git-declared CPU limit

**Talking point**: "This is drift detection and self-healing. Someone just tried to change the CPU limit directly on the cluster. ArgoCD detected the drift, compared it to Git, and automatically corrected it. Git always wins. This is critical for compliance and security in production AI environments."

### Step 7: Show Rollback Capability (1 min)

In ArgoCD UI:

1. Click **"HISTORY AND ROLLBACK"** tab
2. Show the list of previous sync operations with Git commit SHAs
3. Explain: "If a bad deployment goes out, you can roll back to any previous state with one click. Or you can `git revert` and ArgoCD will automatically sync the reverted state."

---



## Common Customer Questions and Answers

**Q: How does this compare to just using** `oc apply` **or Helm?**

> ArgoCD adds continuous reconciliation, drift detection, visual dashboard, rollback history, and approval gates. `oc apply` is fire-and-forget -- you have no idea if the cluster matches your desired state.

**Q: What if I have multiple clusters?**

> ArgoCD supports multi-cluster. You define each cluster as a destination, and the same Git repo can deploy to dev/staging/prod across different clusters.

**Q: Can I use this with other model serving runtimes (not just vLLM)?**

> Yes. The base Kustomize templates define the ServingRuntime and InferenceService. You can swap vLLM for llm-d, OpenVINO, Caikit-TGIS, or any KServe-compatible runtime by changing the base YAML.

**Q: What about secrets and credentials?**

> The OCI data connection secret in this demo has empty credentials (the model is public on Quay.io). For private models, use Sealed Secrets, External Secrets Operator, or HashiCorp Vault integrated with ArgoCD.

**Q: How fast does ArgoCD detect changes?**

> By default, ArgoCD polls Git every 3 minutes. You can configure webhooks for near-instant detection, or adjust the polling interval.

**Q: What about CI/CD validation before deployment?**

> This is Phase 2 of the demo. You can add OpenShift Pipelines (Tekton) to validate Kustomize builds, lint YAML, run security scans, and block PR merges before ArgoCD ever sees the change.

---



## Prerequisites for Running This Demo

1. OpenShift cluster with RHOAI installed and KServe enabled
2. 2+ GPU nodes (NVIDIA GPU operator deployed)
3. OpenShift GitOps operator installed (ArgoCD)
4. `oc` CLI access with admin privileges



### One-Time Setup Commands

```bash
# Clone the repo
git clone https://github.com/jingggg-wenn/llmops-demo.git
cd llmops-demo/llmops-via-argocd

# Create namespaces and permissions
bash setup_scripts/setup-argocd.sh

# Deploy ArgoCD applications
bash setup_scripts/apply-argocd-apps.sh

# Configure health checks (so ArgoCD understands KServe status)
bash argocd-setup-healthcheck/apply-health-check-via-cr.sh -f

# Configure RBAC (enable OpenShift SSO login)
bash argocd-rbac/apply-rbac-via-cr.sh -f
```

Setup takes approximately 25-35 minutes total (including model pull time).

---

**Created**: July 2026
**Last Tested**: July 10, 2026
**Cluster**: OpenShift 4.x + RHOAI + KServe + OpenShift GitOps v1.21.1