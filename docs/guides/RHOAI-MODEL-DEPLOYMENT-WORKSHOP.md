# Red Hat OpenShift AI — Model Deployment Workshop

> A hands-on guide for deploying AI models on Red Hat OpenShift AI (RHOAI) 3.4, enabling tool calling with vLLM, deploying Open WebUI as a full-featured chat interface, and connecting MCP servers for live cluster querying.

**Total time:** ~2 hours

---

## What You'll Learn

By the end of this workshop, you will:

- Create a Data Science project in OpenShift AI
- Deploy an AI model (Qwen3-4B) with tool calling enabled using the vLLM runtime
- Deploy LlamaStack as a unified API layer for inference
- Deploy Open WebUI as a self-hosted chat interface with RAG and MCP support
- Test LLM chat, document-based RAG, and live tool calling against cluster resources
- Understand hardware profiles, model serving, LlamaStack, and agentic AI concepts

### Workshop Structure

| Part | Title | Type | Duration |
|------|-------|------|----------|
| Part 1 | Access OpenShift AI | Hands-on | ~5 min |
| Part 2 | Create Your Project | Hands-on | ~5 min |
| Part 3 | Deploy a Model | Hands-on | ~15 min |
| Part 4 | Wait for Model & Monitor | Hands-on | ~10 min |
| Part 5 | Open Web Terminal, Clone Repo, Set Env Vars | Hands-on | ~5 min |
| Part 6 | Deploy LlamaStack | Hands-on | ~5 min |
| Part 7 | Deploy MCP Server | Hands-on | ~5 min |
| Part 8 | Deploy Open WebUI | Hands-on | ~5 min |
| Part 9 | Configure OpenWebUI | Hands-on | ~10 min |
| Part 10 | Test LLM Chat | Hands-on | ~10 min |
| Part 11 | Test RAG | Hands-on | ~10 min |
| Part 12 | Test Tool Calling | Hands-on | ~10 min |
| Instructor Demo | Observe Tab Metrics | Demo | ~10 min |
| Appendix A | AI Playground (Optional) | Optional | -- |
| Appendix B | Model Catalog | Optional | -- |
| Appendix C | Instructor Setup Checklist | Reference | -- |

---

## Prerequisites

Before starting, make sure the following are ready:

- A running OpenShift 4.20+ cluster with RHOAI 3.4 installed
- At least one GPU node available in the cluster (e.g., NVIDIA L4, L40S, or A100)
- A GPU hardware profile created by your administrator (`gpu-profile`)
- Your login credentials (username and password provided by your instructor)

> **Instructor note:** Use `scripts/install-rhoai-34.sh --skip-rhcl --skip-maas --setup-users --num-users <N>` to create workshop user accounts. RHCL and MaaS are not required for this workshop. See the [RHOAI 3.4 Installation Guide](rhoai-3.4/RHOAI-34-INSTALLATION.md) for full setup details.

---

## Your User Number

Throughout this guide, you'll see `user-XX`. **Replace XX with your assigned number.**

For example, if you are **user 5**, then:

- `user-XX` becomes `user-05`
- Your project name is `user-05`

> Always use two digits: user 5 = `user-05`, user 12 = `user-12`

**Write your user number here:** `user-____`

---

# Part 1: Access OpenShift AI (~5 min)

## Step 1.1: Log into OpenShift AI

1. Open your web browser (Chrome or Firefox recommended)
2. Go to the **OpenShift AI Dashboard URL** provided by your instructor
3. You will be redirected to a login page — select the login provider specified by your instructor (e.g., `workshop-users` or `htpasswd`)
4. Enter your username and password
5. Click **"Log in"**

You should now see the **OpenShift AI Dashboard** with a left sidebar showing menu items like "Projects", "Model catalog", "Gen AI studio", etc.

![OpenShift AI Dashboard](images/landing_page.jpeg)

> Can't log in? Double-check your username and password with your instructor.

> **Tip:** To switch between the **OpenShift AI Dashboard** and the **OpenShift Console** (needed later for the Web Terminal), click the **grid icon** (3x3 squares) in the top-right corner of the header bar, then select **OpenShift Console** or **Red Hat OpenShift AI**. You can also switch via the URL: replace `rh-ai.apps` with `console-openshift-console.apps` (or vice versa).

---

# Part 2: Create Your Project (~5 min)

A "project" (also known as a Kubernetes namespace) is your workspace where you'll deploy models, create workbenches, and run experiments.

## Step 2.1: Create a New Project

1. Click **"Projects"** in the left sidebar

![Projects Page](images/project_page.jpeg)

2. Click the **"Create project"** button (top right)
3. Fill in the form:

   | Field | What to Enter |
   |-------|---------------|
   | **Name** | `user-XX` (use your assigned number, e.g., `user-05`) |
   | **Description** | `My workshop project` (optional) |

4. Click **"Create"**

![Create Project Dialog](images/create_project.jpeg)

You should now see your project `user-XX` with tabs for **Overview**, **Workbenches**, **Pipelines**, **Deployments**, **Connections**, etc.

![Project Overview](images/project_landing.jpeg)

---

# Part 3: Deploy a Model (~15 min)

In this section, you'll deploy the **Qwen3-4B** model using the **vLLM** serving runtime with tool calling enabled. The model is stored as an OCI (container) image, so no S3 storage credentials are needed.

## Step 3.1: Understanding Hardware Profiles (Instructor Demo)

> **This is a brief demo by your instructor** — you don't need to do anything, just watch and learn.

A **hardware profile** defines the compute resources (CPU, memory, GPU) allocated to a model deployment. It also includes tolerations that allow pods to schedule on GPU-tainted nodes.

**What the instructor will show:**

- Navigate to **Settings > Hardware profiles** in the RHOAI dashboard
- The pre-created `gpu-profile` that includes:
  - GPU resource limits (`nvidia.com/gpu`)
  - Node selector for GPU nodes (`nvidia.com/gpu.present: "true"`)
  - Tolerations for GPU node taints

![Hardware Profile](images/Hardware_profile.png)

> **Important:** Only administrators can create or modify hardware profiles. As a workshop participant, you'll **select** the pre-created `gpu-profile` when deploying your model.

---

## Step 3.2: Start the Model Deployment

1. Click **"Projects"** in the left sidebar
2. Click on your project name (`user-XX`)
3. Click the **"Deployments"** tab
4. Click the **"Deploy model"** button

![Deployments Tab](images/deployment_page.jpeg)

---

## Step 3.3: Wizard Step 1 — Model Details

The deployment wizard has 4 steps. The first step asks where the model is stored.

![Wizard Step 1 — Empty](images/Model_deployment_1.jpeg)

Fill in the following:

| Field | What to Select/Enter |
|-------|---------------------|
| **Model location** | `URI` |
| **URI** | `oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b` |
| **Name** | `qwen3-4b` (auto-populated from URI) |
| **Model type** | `Generative AI model (Example, LLM)` |

> **Tip:** Copy the URI exactly as shown. The name field will auto-populate. This pulls the model as an OCI container image — no storage credentials are required.

![Wizard Step 1 — Filled](images/model_deployment-2.jpeg)

Click **"Next"** to proceed.

---

## Step 3.4: Wizard Step 2 — Model Deployment

Configure the deployment settings:

| Field | What to Select/Enter |
|-------|---------------------|
| **Model deployment name** | `qwen3-4b` (auto-populated) |
| **Hardware profile** | Select `GPU Profile (L4 24GB)` or your GPU profile |
| **Deployment resource** | `Automatic selection` or `Manual selection` |
| **Number of replicas** | `1` |

![Wizard Step 2 — Deployment name and hardware profile](images/model_deployment_3.jpeg)

If you choose **Manual selection** for deployment resource, select **vLLM NVIDIA GPU ServingRuntime for KServe** from the dropdown:

![Runtime Selection](images/vllm_runtime.jpeg)

![Wizard Step 2 — Runtime and replicas](images/model_deployment-4.jpeg)

Click **"Next"** to proceed.

---

## Step 3.5: Wizard Step 3 — Advanced Settings

This step configures model availability, access, and tool calling. **Check all four boxes:**

| Setting | What to Do |
|---------|-----------|
| **Publish as AI asset endpoint** | **Check this box** |
| **Make model deployment available through an external route** | **Check this box** |
| **Require token authentication** | **Check this box** |
| **Add custom runtime arguments** | **Check this box** |

After checking **"Add custom runtime arguments"**, add the following arguments. Enter each on its own line in the text box:

```
--enable-auto-tool-choice
--tool-call-parser=hermes
```

![Custom Runtime Arguments](images/vllm-args.png)

![Advanced Settings with Tool Calling](images/model-deployment-6.jpeg)

**What these arguments do:**

| Argument | Purpose |
|----------|---------|
| `--enable-auto-tool-choice` | Allows the model to decide when to use tools |
| `--tool-call-parser=hermes` | Tells vLLM how to parse Qwen's tool call output |

Different model families require different tool call parsers:

| Model Family | Parser |
|---|---|
| Qwen | `hermes` |
| Llama | `llama3_json` |
| Mistral | `mistral` |

Click **"Next"** to proceed.

---

## Step 3.6: Wizard Step 4 — Review and Deploy

Review the configuration summary. Verify the key settings:

- **Model location:** URI
- **Location details:** `oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b`
- **Hardware profile:** gpu-profile
- **Deployment resource:** vLLM NVIDIA GPU ServingRuntime for KServe
- **Replicas:** 1
- **AI asset endpoint:** Yes
- **External route:** Yes
- **Token authentication:** Yes
- **Custom runtime arguments:** `--enable-auto-tool-choice`, `--tool-call-parser=hermes`

![Review Page](images/review-model.jpeg)

Click **"Deploy model"** to start the deployment.

---

# Part 4: Wait for Model & Monitor (~10 min)

The model needs a few minutes to pull the container image and start the vLLM server.

## Step 4.1: Monitor Deployment Status

1. After clicking Deploy, you'll be taken to the Deployments tab
2. Watch the status indicator next to `qwen3-4b`:

| Status | What It Means |
|--------|---------------|
| **Starting** | Container image is being pulled and model is loading |
| **Ready** | Model is ready to serve requests |
| **Failed** | Something went wrong (check events) |

![Model Starting](images/model-wait.jpeg)

> This typically takes **3-5 minutes** depending on image cache state and GPU availability. Feel free to stretch!

## Step 4.2: Verify the Model is Running

Once the status shows **Ready** (green), your model is ready.

![Model Ready](images/model-done.png)

1. Click the **question mark icon** next to the model name to see the resource name and type (`InferenceService`)

![Resource Name](images/resource-name.png)

2. Click the **expand arrow** (>) to the left of the model name to see deployment details

![Model Details Expanded](images/token.png)

3. **Copy two things** from the expanded details — you'll need both in Part 5:

   - **Inference endpoint URL** — the external route URL (e.g., `https://qwen3-4b-user-03.apps.cluster...`). Click the copy icon next to it.
   - **Token secret** — click **"Show token"** (or the eye icon) to reveal the authentication token, then copy it.

> **Keep these handy!** You'll paste the URL as `MODEL_URL` and the token as `MODEL_TOKEN` in Part 5.

---

# Part 5: Open Web Terminal, Clone Repo, Set Env Vars (~5 min)

You'll use the OpenShift Web Terminal for all command-line steps. It comes pre-installed with `oc`, `git`, and `sed` — no local CLI tools needed.

## Step 5.1: Open the Web Terminal

Access the **OpenShift Console** by clicking on the **waffle** icon on the top right of the RHOAI platform and select **OpenShift Console**. Click the **`>_`** icon in the top-right masthead of the OpenShift console to open the Web Terminal. This gives you an in-browser terminal with `oc`, `git`, and `sed` pre-installed -- no local CLI tools needed.

## Step 5.2: Clone the Workshop Repository

```bash
git clone https://github.com/gymnatics/Red-Hat-Inference-Workshop.git
```

```bash
cd Red-Hat-Inference-Workshop
```

## Step 5.3: Set Your Environment Variables

Set your namespace (replace `XX` with your assigned number, e.g., `05`):

```bash
export NAMESPACE=user-XX
```

Set your model's external route URL (copy it from the Deployments tab -- click the expand arrow next to your model, find the **Inference endpoint** URL):

```bash
export MODEL_URL=<paste your external model endpoint here>
```

Set your model token (from the same expanded details in the Deployments tab):

```bash
export MODEL_TOKEN=<paste-token-here>
```

---

# Part 6: Deploy LlamaStack (~5 min)

Now you'll deploy **OGX/LlamaStack** — a unified API layer that brings together inference and tool calling under a single Kubernetes-managed endpoint.

## What is OGX/LlamaStack?

LlamaStack is a developer framework for building generative AI applications. On RHOAI, it's managed by the **OGX/LlamaStack Operator** — you deploy a `LlamaStackDistribution` custom resource, and the operator creates and manages the OGX/LlamaStack server for you.

> **What this deploys:**
> - **Secret** — stores the shared model's endpoint URL and your authentication token
> - **ConfigMap** — OGX/LlamaStack's `run.yaml` configuration that tells it where the model is
> - **LlamaStackDistribution** — custom resource that the OGX/LlamaStack Operator uses to deploy and manage a OGX/LlamaStack server pod in your namespace

## Step 6.1: Deploy OGX/LlamaStack

```bash
sed "s|\${NAMESPACE}|$NAMESPACE|g; s|\${MODEL_URL}|$MODEL_URL|g; s|\${MODEL_TOKEN}|$MODEL_TOKEN|g" manifests/llamastack.yaml | oc apply -f -
```

## Step 6.2: Wait for OGX/LlamaStack to Start

Go to **Workloads** on the Openshift Console sidebar and select the **Pods** tab. Open the **Project** Drop-down and select your project and look for the llamastack-workshop pod and wait for it to be **Running 1/1**.

This typically takes 1-2 minutes.

## Step 6.3: Verify OGX/LlamaStack is Running

```bash
oc get pods -n $NAMESPACE -l app.kubernetes.io/instance=llamastack-workshop
```

You should see a pod in `Running` state.

> **Tip:** If the pod is in `CrashLoopBackOff`, check the logs: `oc logs -n $NAMESPACE -l app.kubernetes.io/instance=llamastack-workshop`

---

# Part 7: Deploy MCP Server (~5 min)

Now you'll deploy your own **MCP (Model Context Protocol) server** — a Kubernetes-native tool server that lets the LLM query live cluster resources.

> **What this deploys:**
> - **ServiceAccount** — identity for the MCP server pod
> - **RoleBinding** — grants read-only access to resources in your namespace
> - **Deployment** — runs the Kubernetes MCP server
> - **Service** — exposes the MCP server at port 8080

## Step 7.1: Deploy the MCP Server

```bash
sed "s|\${NAMESPACE}|$NAMESPACE|g" manifests/mcp-server.yaml | oc apply -f -
```

## Step 7.2: Wait for It to Start

```bash
oc rollout status deployment/kubernetes-mcp-server -n $NAMESPACE --timeout=60s
```

## Step 7.3: Verify

```bash
oc get pods -n $NAMESPACE -l app=kubernetes-mcp-server
```

You should see a pod in `Running` state.

---

# Part 8: Deploy Open WebUI (~5 min)

Now you'll deploy **Open WebUI** — a self-hosted chat interface (similar to ChatGPT) — along with the **mcpo proxy** that converts MCP tools into OpenAPI endpoints that OpenWebUI can call reliably.

> **What this deploys:**
> - **ConfigMap** — base configuration for OpenWebUI
> - **PersistentVolumeClaim** — 2Gi storage for OpenWebUI data
> - **Deployment** — the Open WebUI container (v0.9.0)
> - **Service + Route** — external HTTPS URL for your browser
> - **mcpo ConfigMap** — tells the mcpo proxy where to find the MCP server
> - **mcpo Deployment + Service** — proxy that converts MCP tools to OpenAPI for OpenWebUI

## Step 8.1: Deploy Open WebUI + mcpo Proxy

Make sure your `NAMESPACE` variable is still set and you're in the workshop repo directory, then deploy:

```bash
sed "s|\${NAMESPACE}|$NAMESPACE|g" manifests/open-webui.yaml | oc apply -f -
```

This single command deploys both Open WebUI and the mcpo proxy.

## Step 8.2: Wait for Open WebUI

```bash
oc rollout status deployment/open-webui -n $NAMESPACE --timeout=120s
```

## Step 8.3: Get Your Workshop URLs

Run the helper script to print all URLs you'll need:

```bash
bash show-urls.sh
```

This prints your OpenWebUI URL, LlamaStack URL, model token, and mcpo tools URL — all ready to copy-paste.

Alternatively, get just the Open WebUI URL:

```bash
echo "https://$(oc get route open-webui -n $NAMESPACE -o jsonpath='{.spec.host}')"
```

## Step 8.4: Access Open WebUI

Open the URL in your browser. If you see a sign-up page, create any account — authentication is disabled for the workshop.

---

# Part 9: Configure OpenWebUI (~10 min)

OpenWebUI needs to know where your LlamaStack instance is (for inference) and where the mcpo proxy is (for tools). You'll add both connections before using the chat.

## Step 9.1: Get Your URLs

Back in the Web Terminal, run:

```bash
echo ""
echo "=== URLs for OpenWebUI Configuration ==="
echo ""
echo "LlamaStack URL (for Connections):"
echo "  http://llamastack-workshop-service.$NAMESPACE.svc.cluster.local:8321/v1"
echo ""
echo "mcpo Tools URL (for Integrations):"
echo "  http://mcpo.$NAMESPACE.svc.cluster.local:8000/kubernetes"
echo ""
```

Copy both URLs — you'll paste them in the next steps.

## Step 9.2: Add Model Connection

1. In OpenWebUI, click your **profile icon** (bottom-left corner)
2. Click **"Admin Panel"**
3. In the left sidebar, click **"Settings"**
4. Click **"Connections"**
5. Click the **"+"** button to add a new connection
6. Fill in:

| Field | Value |
|-------|-------|
| **URL** | Paste the LlamaStack URL from Step 9.1 |
| **Auth** | Select **Bearer**, then paste the **token** you copied from Part 4 Step 4.2 (the same value you used for `MODEL_TOKEN`) |

![OpenWebUI Connection Settings](images/openwebui-connection.png)

7. Click **Save**
8. The connection should show a **green toggle** — this means OpenWebUI successfully connected and discovered your model

> **Troubleshooting:** If the toggle is red, double-check the URL and token. Make sure the LlamaStack pod is running (`oc get pods -n $NAMESPACE`).

## Step 9.3: Add Tool Server

1. Still in the Admin Panel, click **"Settings"** in the left sidebar
2. Click **"Integrations"**

![OpenWebUI Integrations](images/openwebui-integrations.png)

3. Under **External Tool Servers**, click the **"+"** button

![Add Connection Dialog](images/openwebui-add-connection.png)

4. Fill in the fields:

   | Field | Value |
   |-------|-------|
   | **Type** | Select **OpenAPI** |
   | **Name** | `Kubernetes Tools` |
   | **URL** | Paste the mcpo URL from Step 9.1 |
   | **Auth** | Select **None** |

5. Click **Save**

After saving, you should see the Kubernetes tools listed. Common tools include:

- **pods_list** — List pods in a namespace
- **pods_get** — Get details of a specific pod
- **resources_list** — List any Kubernetes resources
- **pods_log** — Get pod logs
- **namespaces_list** — List namespaces

> If tools don't appear immediately, try refreshing the page.

## Step 9.4: Configure Model

1. In the Admin Panel, click **"Workspace"** in the top menu bar
2. Click **"Models"**
3. Find your model (`qwen3-4b` or `vllm-inference/qwen3-4b`) and click the **edit** (pencil) icon
4. Scroll down to **Function Calling** and set it to **Native**
5. Under **Tools**, enable the Kubernetes tools you want available
6. Click **Save**

---

# Part 10: Test LLM Chat (~10 min)

Now that OpenWebUI is connected to your model via OGX/LlamaStack, test basic chat.

## Step 10.1: Start a Chat

1. Click **"New Chat"**
2. Select the model from the dropdown (look for `qwen3-4b` or `vllm-inference/qwen3-4b`)

## Step 10.2: Try These Prompts

```
What is Kubernetes?
```

```
Write a haiku about cloud computing.
```

```
Write a Python function that calculates the Fibonacci sequence up to n terms.
```

## Step 10.3: Verify the Pipeline

If you receive responses, this confirms the full pipeline is working:

```
You (browser) → Open WebUI → OGX/LlamaStack → vLLM (your model)
```

> **Note:** When calling the OGX/LlamaStack API directly (e.g., via `curl`), the full model ID is `vllm-inference/qwen3-4b`. The OpenWebUI dropdown may show the short name.

---

# Part 11: Test RAG (~10 min)

Open WebUI has built-in RAG (Retrieval-Augmented Generation) that lets you upload documents/websites and ask questions about them — no external infrastructure needed.

## Step 11.1: Upload a Document

1. In the chat sidebar, click the **+** icon (or the paperclip/attachment icon)
2. Upload a document (PDF, text file, or paste text). Suggestion: upload any short document (e.g., a page from Red Hat documentation, a project README, or even this workshop guide)
3. In this example, we will be using a website for the RAG: https://support.apple.com/en-sg/126322

## Step 11.2: Ask Questions About the Document

After upload, try these prompts:

```
What colors does the Maxbook Neo come in?
```

```
What are the key topics covered?
```

```
What year was it introduced?
```

## Step 11.3: Understand How It Works

> **How it works:** OpenWebUI has built-in RAG (Retrieval-Augmented Generation). When you upload a document, it splits it into chunks, generates embeddings using a local model, stores them in a vector database, and retrieves relevant chunks when you ask questions. No external infrastructure needed.

---

# Part 12: Test Tool Calling (~10 min)

Now test the model's ability to use MCP tools to query your cluster in real time.

## Step 12.1: Start a New Chat

1. Start a **New Chat** in OpenWebUI
2. Make sure the model is selected and tools are enabled (look for a tools icon in the chat bar)

## Step 12.2: Try These Prompts

Ask the model questions that require cluster data. Watch how it makes tool calls to the Kubernetes MCP server:

```
What pods are running in my namespace?
```

```
List all namespaces in this cluster.
```

```
Show me the deployments in the admin-workshop namespace.
```

```
What events happened recently in my namespace?
```

## Step 12.3: Observe Tool Calling in Action

The model should make tool calls to the MCP server and return live cluster data. You can see the tool calls in the response (OpenWebUI shows them as expandable sections).

> **What's happening:** The model recognizes that it needs live data, generates a tool call (thanks to `--enable-auto-tool-choice`), OpenWebUI executes the call against the MCP server, and returns the results to the model for a natural language answer.

## Step 12.4: Understand the Architecture

Take a moment to appreciate what you've built:

```
You (browser)
  → Open WebUI (chat interface in your namespace)
    → LlamaStack (unified API layer in your namespace)
      → vLLM model (your deployment with tool calling enabled)
    → Kubernetes MCP Server (in your namespace)
      → OpenShift API (live cluster data)
```

- **LlamaStack** provides the unified API layer — one Kubernetes CR gives you inference under a single endpoint
- **Open WebUI** provides the chat interface and handles MCP tool execution
- **MCP** provides the tools that let the model interact with real infrastructure

---

# Instructor Demo: Observe Tab Metrics (~10 min)

> **This is an instructor-led demo** — participants observe while the instructor walks through the monitoring dashboards.

## What the Instructor Will Show

1. Open the OpenShift Console
2. Navigate to **Observe** → **Dashboards**
3. Show the **vLLM Performance** dashboard (request latency, tokens/s, queue size)
4. Show the **DCGM Exporter** dashboard (GPU utilization, memory, temperature)
5. Discuss how these metrics help with capacity planning and troubleshooting

> **Note:** These dashboards require User Workload Monitoring to be enabled and Grafana dashboards to be deployed. Both are configured by the automated workshop setup.

---

# Congratulations!

You've completed the Model Deployment Workshop!

## What You Accomplished

| Task | Status |
|------|--------|
| Logged into OpenShift AI | Done |
| Created a Data Science project | Done |
| Deployed a model with tool calling enabled | Done |
| Deployed LlamaStack as an API layer | Done |
| Deployed Open WebUI as a chat interface | Done |
| Tested LLM chat | Done |
| Tested RAG with document upload | Done |
| Deployed your own MCP server | Done |
| Connected MCP to OpenWebUI | Done |
| Tested tool calling with live cluster data | Done |

## What's Next?

After this workshop, you can explore:

| Topic | Where to Learn More |
|-------|---------------------|
| **More MCP Tools** | Deploy Weather, GitHub, or custom MCP servers for more tool capabilities. See [MCP Server Setup](MCP-SERVER-SETUP.md) |
| **Models-as-a-Service (MaaS)** | API keys, subscriptions, and rate limiting for multi-tenant model access. See [MaaS Policy Enforcement](MAAS-POLICY-ENFORCEMENT.md) |
| **NeMo Guardrails** | Add safety guardrails to your model responses. See [RHCL + Guardrails Architecture](RHCL-GUARDRAILS-ARCHITECTURE.md) |
| **Model Registry** | Version and manage your models. See [Model Registry](MODEL-REGISTRY.md) |
| **AI Pipelines** | Build automated ML workflows. See the [RHOAI documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4) |
| **LLM Evaluation** | Benchmark your models with LMEval. See the [Demo Environment](DEMO-ENVIRONMENT.md) |

---

# Troubleshooting

## "Model stuck on Pending"

**Cause:** No GPU nodes available, or GPU is occupied by another deployment.

**Fix:**

- Check if GPU nodes exist: look for nodes labeled with `nvidia.com/gpu.present=true`
- Ask your instructor if GPUs are available

## "Model shows Failed status"

**Cause:** Various — could be image pull error, insufficient resources, or configuration issue.

**Fix:**

1. Click on the model name to see deployment details
2. Check the **Events** tab for error messages
3. Common issues:
  - Image pull errors: verify the OCI URI is correct
  - Insufficient GPU memory: the model may need more than available VRAM
  - Missing hardware profile: ensure `gpu-profile` exists

## "OpenWebUI shows no models"

**Cause:** LlamaStack pod is not running, or the connection configuration is wrong.

**Fix:**

1. Check that LlamaStack is running: `oc get pods -n $NAMESPACE -l app.kubernetes.io/instance=llamastack-workshop`
2. In Open WebUI Admin Panel → Settings → Connections, verify the URL and Bearer token are correct
3. Click the refresh icon to re-test the connection
4. Check LlamaStack logs: `oc logs -n $NAMESPACE -l app.kubernetes.io/instance=llamastack-workshop`

## "MCP tools not appearing"

**Cause:** mcpo proxy or MCP server is not running, or the URL is wrong.

**Fix:**

1. Verify both pods are running: `oc get pods -n $NAMESPACE -l app=kubernetes-mcp-server` and `oc get pods -n $NAMESPACE -l app=mcpo`
2. Check the URL matches: `http://mcpo.<your-namespace>.svc.cluster.local:8000/kubernetes`
3. Make sure you selected **OpenAPI** as the type (not MCP/Streamable HTTP)
4. Auth should be set to **None**
5. Try removing and re-adding the tool server connection
6. Refresh the Open WebUI page

## "Tool calls not working"

**Cause:** Tool calling arguments were not added during model deployment, or function calling is not enabled in the chat.

**Fix:**

1. Verify `--enable-auto-tool-choice` was added during model deployment (Step 3.5)
2. Check that the model has `--tool-call-parser=hermes` set
3. In the chat, make sure tools are enabled (look for a tools toggle)
4. Be explicit in your prompt: "Use the available tools to check what pods are running in namespace user-XX"
5. If you missed the arguments, you'll need to redeploy the model with them enabled

## "Playground not loading or no models available"

**Cause:** Model is not registered as an AI asset, or model is not fully ready.

**Fix:**

1. Verify your model shows **Available** status in the Deployments tab
2. Ensure the model is registered as an AI asset endpoint
3. Try refreshing the browser page
4. Wait 1-2 minutes after the model becomes Available

## Still stuck?

Raise your hand! The instructors are here to help.

---

# Quick Reference Card

## Your Info

- **Username:** `_______`
- **Password:** `________`
- **Project name:** `user-____`

## Key URLs

| Resource | URL |
|----------|-----|
| RHOAI Dashboard | `https://rh-ai.apps.<cluster-domain>` |

## Key Terminal Commands

```bash
# Set environment variables
export NAMESPACE=user-XX
export MODEL_URL=https://qwen3-4b-user-XX.apps.<cluster-domain>
export MODEL_TOKEN=<your-token>

# Check your login
oc whoami

# Switch to your project
oc project user-XX

# Deploy LlamaStack
sed "s|\${NAMESPACE}|$NAMESPACE|g; s|\${MODEL_URL}|$MODEL_URL|g; s|\${MODEL_TOKEN}|$MODEL_TOKEN|g" manifests/llamastack.yaml | oc apply -f -

# Deploy MCP Server
sed "s|\${NAMESPACE}|$NAMESPACE|g" manifests/mcp-server.yaml | oc apply -f -

# Deploy Open WebUI + mcpo proxy
sed "s|\${NAMESPACE}|$NAMESPACE|g" manifests/open-webui.yaml | oc apply -f -

# Print all workshop URLs (LlamaStack, mcpo, OpenWebUI, token)
bash show-urls.sh

# Check all pods in your namespace
oc get pods -n user-XX

# Check model status
oc get inferenceservice -n user-XX

# Check GPU availability
oc get nodes -l nvidia.com/gpu.present=true

# View model logs (if troubleshooting)
oc logs -n user-XX -l serving.kserve.io/inferenceservice=qwen3-4b --tail=50

# Delete your project (cleanup)
oc delete project user-XX
```

---

# Appendix A: AI Playground (Optional)

The AI Playground is RHOAI's built-in chat interface. While the workshop uses OpenWebUI for richer features (RAG, MCP tools), the Playground is useful for quick model testing directly from the dashboard.

---

## Step A.1: Verify AI Asset Endpoint

Since you checked **"Publish as AI asset endpoint"** during deployment (Step 3.5), your model should already be registered.

1. Click **"Gen AI studio"** in the left sidebar to expand it
2. Click **"AI asset endpoints"**
3. Make sure your project (`user-XX`) is selected in the **Project** dropdown
4. You should see `qwen3-4b` listed with a **Ready** status

![AI Asset Endpoints](images/ai-asset-endpoint.png)

---

## Step A.2: Create the Playground

1. On the AI asset endpoints page, click **"Add to playground"** next to your model
2. In the **"Configure playground"** dialog, make sure `qwen3-4b` is checked
3. Click **"Create"**

![Configure Playground](images/create-playground.png)

---

## Step A.3: Open the Playground

1. Click **"Gen AI studio"** > **"Playground"** in the left sidebar
2. You should see the Playground interface with your model selected

![Playground Interface](images/open-playground.png)

---

## Step A.4: Chat with Your Model

Type a message in the chat box and press Enter (or click the send button).

![Typing a Message](images/chat-model.png)

Try these prompts to verify your model is working:

```
What is Kubernetes?
```

```
Write a haiku about cloud computing.
```

```
Explain the difference between machine learning and deep learning in simple terms.
```

```
Write a Python function that calculates the Fibonacci sequence up to n terms.
```

![Model Response](images/result.png)

---

## Step A.5: Explore Playground Settings

The Playground offers several configuration options to tune model behavior:

| Setting | What It Does | Suggested Value |
|---------|--------------|-----------------|
| **Temperature** | Controls randomness (0 = deterministic, 1 = creative) | 0.7 |
| **Max tokens** | Maximum length of the response | 256-1024 |
| **Top P** | Nucleus sampling threshold | 0.9 |
| **System prompt** | Sets the model's persona/instructions | (try a custom one!) |

### Try a system prompt

In the system prompt field (if available), enter:

```
You are a helpful assistant that explains technical concepts using simple analogies. Always include a real-world analogy in your answers.
```

Then ask:

```
What is Kubernetes?
```

Notice how the response now includes an analogy!

The Playground's **Configure** panel on the left side lets you adjust the Temperature slider and toggle Streaming. Click the **Prompt** tab to set a system prompt.

---

# Appendix B: Model Catalog

RHOAI 3.4 includes a **Model Catalog** with pre-validated model configurations:

1. Click **"Model catalog"** in the left sidebar
2. Browse available models (Granite, Llama, Qwen, Mistral, etc.)
3. Click on a model to see details, recommended hardware, and deployment instructions
4. Click **"Deploy"** to start a pre-configured deployment

---

# Appendix C: Instructor Setup Checklist

This section is for workshop instructors setting up the environment.

## Pre-workshop Setup

> **GPU Scaling:** Each participant deploys their own model (1 GPU each). For N participants, provision at least N GPU nodes using `scripts/create-gpu-machineset.sh`. A single GPU node can only serve 1-2 model deployments simultaneously. Without enough GPUs, participants will see models stuck in "Pending" status.

### Option A: Automated (Recommended)

Use the RHOAI Toolkit to set up everything:

```bash
./rhoai-toolkit.sh
# Select option 4: Workshop Demo Setup (RHOAI 3.4 + OpenWebUI)
# Select option 1: Complete Workshop Setup
```

This handles RHOAI 3.4 installation, Web Terminal operator, GPU setup, user creation, Grafana dashboards, the shared model with tool calling, the Kubernetes MCP server, and enabling the LlamaStack operator.

### Option B: Manual Steps

1. **Install RHOAI 3.4** (no RHCL/MaaS needed for this workshop):

   ```bash
   ./scripts/install-rhoai-34.sh --skip-rhcl --skip-maas --setup-users --num-users <N> --user-password <password>
   ```

2. **Create GPU hardware profile**:

   ```bash
   oc apply -f lib/manifests/rhoai/hardware-profile-gpu.yaml
   ```

3. **Deploy the shared model with tool calling** in `admin-workshop`:

   ```bash
   oc new-project admin-workshop
   oc apply -f lib/manifests/workshop/workshop-servingruntime.yaml
   oc apply -f lib/manifests/workshop/workshop-inferenceservice.yaml
   oc apply -f lib/manifests/workshop/workshop-model-service.yaml
   oc create route edge qwen3-4b --service=qwen3-4b-external --port=8080 -n admin-workshop
   ```

4. **Enable the LlamaStack operator** (participants deploy LlamaStack in their namespaces):

   ```bash
   oc patch datasciencecluster default-dsc --type merge \
     -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}'
   ```

5. **Deploy the Kubernetes MCP server** in `admin-workshop`:

   ```bash
   export NAMESPACE=admin-workshop CLUSTER_ROLE=view
   export MCP_SERVER_IMAGE=quay.io/redhat-ai-services/kubernetes-mcp-server
   export MCP_SERVER_ARGS='["--port=8080", "--read-only"]'
   envsubst < lib/manifests/mcp/kubernetes-mcp-server.yaml | oc apply -f - -n admin-workshop
   unset NAMESPACE CLUSTER_ROLE MCP_SERVER_IMAGE MCP_SERVER_ARGS
   ```

6. **Verify** everything is running:

   ```bash
   # GPU nodes
   oc get nodes -l nvidia.com/gpu.present=true

   # Hardware profile
   oc get hardwareprofile gpu-profile -n redhat-ods-applications

   # Shared model
   oc get inferenceservice qwen3-4b -n admin-workshop

   # MCP server
   oc get pods -n admin-workshop -l app=kubernetes-mcp-server

   # LlamaStack operator
   oc get csv -n redhat-ods-operator | grep llamastack
   ```

7. **Get model token** to share with participants:

   ```bash
   SA_SECRET=$(oc get secret -n admin-workshop | grep "default-name-qwen3-4b-sa" | head -1 | awk '{print $1}')
   oc get secret "$SA_SECRET" -n admin-workshop -o jsonpath='{.data.token}' | base64 -d
   ```

8. **Test a model deployment** yourself before the workshop to ensure images are cached on nodes.

## Workshop Credentials Template

Provide each participant with:

| Field | Value |
|-------|-------|
| OpenShift AI Dashboard URL | `https://rh-ai.apps.<cluster-domain>` |
| Login provider | `htpasswd` or `workshop-users` |
| Username | `userXX` |
| Password | (your chosen password) |
| User number (for project) | `XX` |

---

**Reference:** [RHOAI 3.4 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4)
