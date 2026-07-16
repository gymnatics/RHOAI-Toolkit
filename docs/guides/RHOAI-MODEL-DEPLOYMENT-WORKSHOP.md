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
| Part 5 | Deploy LlamaStack | Hands-on | ~10 min |
| Part 6 | Deploy Open WebUI | Hands-on | ~5 min |
| Part 7 | Connect Model to OpenWebUI | Hands-on | ~5 min |
| Part 8 | Test LLM Chat | Hands-on | ~10 min |
| Part 9 | Test RAG | Hands-on | ~10 min |
| Part 10 | Deploy MCP Server | Hands-on | ~5 min |
| Part 11 | Connect MCP to OpenWebUI | Hands-on | ~5 min |
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

2. Click the **expand arrow** (>) to the left of the model name to see deployment details including inference endpoints, hardware profile, and token authentication

![Model Details Expanded](images/token.png)

> **Important:** Copy the **authentication token** from the model's expanded details (click the expand arrow next to the model name in the Deployments tab). You'll need this token in Part 5.

---

# Part 5: Deploy LlamaStack (~10 min)

Now you'll deploy **LlamaStack** — a unified API layer that brings together inference and tool calling under a single Kubernetes-managed endpoint.

## What is LlamaStack?

LlamaStack is a developer framework for building generative AI applications. On RHOAI, it's managed by the **LlamaStack Operator** — you deploy a `LlamaStackDistribution` custom resource, and the operator creates and manages the LlamaStack server for you.

> **What this deploys:**
> - **Secret** — stores the shared model's endpoint URL and your authentication token
> - **ConfigMap** — LlamaStack's `run.yaml` configuration that tells it where the model is
> - **LlamaStackDistribution** — custom resource that the LlamaStack Operator uses to deploy and manage a LlamaStack server pod in your namespace

## Step 5.1: Open the Web Terminal

Click the **`>_`** icon in the top-right masthead of the OpenShift console to open the Web Terminal. This gives you an in-browser terminal with `oc`, `git`, and `sed` pre-installed -- no local CLI tools needed.

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

Set the model token (the one you copied from the Deployments tab in Part 4):

```bash
export MODEL_TOKEN=<paste-token-here>
```

## Step 5.4: Deploy LlamaStack

```bash
sed "s/\${NAMESPACE}/$NAMESPACE/g; s/\${MODEL_TOKEN}/$MODEL_TOKEN/g" manifests/llamastack.yaml | oc apply -f -
```

## Step 5.5: Wait for LlamaStack to Start

```bash
oc wait --for=condition=available deployment -l llamastack.io/distribution=llamastack-workshop \
  -n $NAMESPACE --timeout=120s
```

This typically takes 1-2 minutes.

## Step 5.6: Verify LlamaStack is Running

```bash
oc get pods -n $NAMESPACE -l llamastack.io/distribution=llamastack-workshop
```

You should see a pod in `Running` state.

> **Tip:** If the pod is in `CrashLoopBackOff`, check the logs: `oc logs -n $NAMESPACE -l llamastack.io/distribution=llamastack-workshop`

---

# Part 6: Deploy Open WebUI (~10 min)

Now you'll deploy **Open WebUI** — a self-hosted chat interface (similar to ChatGPT).

> **What this deploys:**
> - **ConfigMap** — base configuration for OpenWebUI
> - **PersistentVolumeClaim** — 2Gi storage for OpenWebUI data
> - **Deployment** — the Open WebUI container
> - **Service** — internal cluster access
> - **Route** — external HTTPS URL for your browser

## Step 6.1: Deploy Open WebUI

Make sure your `NAMESPACE` variable is still set and you're in the workshop repo directory, then deploy:

```bash
sed "s/\${NAMESPACE}/$NAMESPACE/g" manifests/open-webui.yaml | oc apply -f -
```

## Step 6.2: Wait for Open WebUI

```bash
oc rollout status deployment/open-webui -n $NAMESPACE --timeout=120s
```

## Step 6.3: Get the Open WebUI URL

```bash
echo "https://$(oc get route open-webui -n $NAMESPACE -o jsonpath='{.spec.host}')"
```

## Step 6.4: Access Open WebUI

Open the URL in your browser. If you see a sign-up page, create any account — authentication is disabled for the workshop.

---

# Part 7: Connect Model to OpenWebUI (~10 min)

OpenWebUI needs to know where your LlamaStack instance is. You'll add it as an external connection with your model token for authentication.

## Step 7.1: Get Your LlamaStack URL

Back in the Web Terminal, run:

```bash
echo "http://llamastack-workshop-service.$NAMESPACE.svc.cluster.local:8321/v1"
```

Copy this URL -- you'll paste it in the next step.

## Step 7.2: Add the Connection in OpenWebUI

1. In OpenWebUI, click your **profile icon** (bottom-left corner)
2. Click **"Admin Panel"**
3. In the left sidebar, click **"Settings"**
4. Click **"Connections"**
5. Click the **"+"** button to add a new connection
6. Fill in:

| Field | Value |
|-------|-------|
| **URL** | Paste the LlamaStack URL from Step 7.1 |
| **Auth** | Select **Bearer**, then paste your **model token** (from Part 4) |

![OpenWebUI Connection Settings](images/openwebui-connection.png)

7. Click **Save**
8. The connection should show a **green toggle** -- this means OpenWebUI successfully connected and discovered your model

> **Troubleshooting:** If the toggle is red, double-check the URL and token. Make sure the LlamaStack pod is running (`oc get pods -n $NAMESPACE`).

---

# Part 8: Test LLM Chat (~10 min)

Now that OpenWebUI is connected to your model via LlamaStack, test basic chat.

## Step 8.1: Start a Chat

1. Click **"New Chat"**
2. Select the model from the dropdown (look for `qwen3-4b` or `vllm-inference/qwen3-4b`)

## Step 8.2: Try These Prompts

```
What is Kubernetes?
```

```
Write a haiku about cloud computing.
```

```
Write a Python function that calculates the Fibonacci sequence up to n terms.
```

## Step 8.3: Verify the Pipeline

If you receive responses, this confirms the full pipeline is working:

```
You (browser) → Open WebUI → LlamaStack → vLLM (your model)
```

> **Note:** When calling the LlamaStack API directly (e.g., via `curl`), the full model ID is `vllm-inference/qwen3-4b`. The OpenWebUI dropdown may show the short name.

---

# Part 9: Test RAG (~10 min)

Open WebUI has built-in RAG (Retrieval-Augmented Generation) that lets you upload documents and ask questions about them — no external infrastructure needed.

## Step 9.1: Upload a Document

1. In the chat sidebar, click the **+** icon (or the paperclip/attachment icon)
2. Upload a document (PDF, text file, or paste text). Suggestion: upload any short document (e.g., a page from Red Hat documentation, a project README, or even this workshop guide)

## Step 9.2: Ask Questions About the Document

After upload, try these prompts:

```
Summarize this document.
```

```
What are the key topics covered?
```

```
What prerequisites are mentioned?
```

## Step 9.3: Understand How It Works

> **How it works:** OpenWebUI has built-in RAG (Retrieval-Augmented Generation). When you upload a document, it splits it into chunks, generates embeddings using a local model, stores them in a vector database, and retrieves relevant chunks when you ask questions. No external infrastructure needed.

---

# Part 10: Deploy MCP Server (~5 min)

Now you'll deploy your own **MCP (Model Context Protocol) server** that provides tools for querying the OpenShift cluster.

> **What this deploys:**
> - **ServiceAccount** — identity for the MCP server with cluster read access
> - **ClusterRoleBinding** — grants the `view` ClusterRole (read-only access to cluster resources)
> - **Deployment** — runs the Kubernetes MCP server container
> - **Service** — exposes the MCP server at port 8080 within the cluster
>
> The MCP server provides tools that let the LLM query live cluster data: listing pods, namespaces, deployments, services, and viewing logs.

## Step 10.1: Deploy the MCP Server

```bash
sed "s/\${NAMESPACE}/$NAMESPACE/g" manifests/mcp-server.yaml | oc apply -f -
```

## Step 10.2: Wait for the MCP Server

```bash
oc rollout status deployment/kubernetes-mcp-server -n $NAMESPACE --timeout=60s
```

## Step 10.3: Verify the MCP Server

```bash
oc get pods -n $NAMESPACE -l app=kubernetes-mcp-server
```

You should see a pod in `Running` state.

---

# Part 11: Connect MCP to OpenWebUI (~5 min)

This is a UI-only step in Open WebUI to connect the MCP server you just deployed.

## Step 11.1: Open Admin Settings

1. In Open WebUI, click your **profile icon** (bottom-left) → **Admin Panel**
2. Go to **Settings** → **Tools**

## Step 11.2: Add the MCP Connection

1. Click **"+ Add Connection"**
2. Configure:

   | Field | Value |
   |-------|-------|
   | **Type** | **MCP (Streamable HTTP)** |
   | **URL** | `http://kubernetes-mcp-server.<your-namespace>.svc.cluster.local:8080/mcp` |

   Replace `<your-namespace>` with your actual namespace (e.g., `user-05`).

3. Click **Save**

## Step 11.3: Verify Tools Are Available

After saving, you should see the Kubernetes tools listed. Common tools include:

- **list_pods** — List pods in a namespace
- **get_pod** — Get details of a specific pod
- **list_deployments** — List deployments
- **list_services** — List services
- **get_logs** — Get pod logs
- **list_namespaces** — List cluster namespaces

> If tools don't appear immediately, try refreshing the page.

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

1. Check that LlamaStack is running: `oc get pods -n $NAMESPACE -l llamastack.io/distribution=llamastack-workshop`
2. Verify the `OPENAI_API_BASE_URLS` in the Open WebUI ConfigMap points to your LlamaStack service
3. In Open WebUI Settings → Connections, click the refresh icon to re-test
4. Check LlamaStack logs: `oc logs -n $NAMESPACE -l llamastack.io/distribution=llamastack-workshop`

## "MCP tools not appearing"

**Cause:** MCP server URL is wrong, or the server is not running.

**Fix:**

1. Verify the MCP server is running: `oc get pods -n $NAMESPACE -l app=kubernetes-mcp-server`
2. Check the URL matches: `http://kubernetes-mcp-server.<your-namespace>.svc.cluster.local:8080/mcp`
3. Make sure you selected **MCP (Streamable HTTP)** as the type (not OpenAPI)
4. Try removing and re-adding the MCP server connection
5. Refresh the Open WebUI page

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
export MODEL_TOKEN=<your-token>

# Check your login
oc whoami

# Switch to your project
oc project user-XX

# Deploy LlamaStack
sed "s/\${NAMESPACE}/$NAMESPACE/g; s/\${MODEL_TOKEN}/$MODEL_TOKEN/g" manifests/llamastack.yaml | oc apply -f -

# Deploy Open WebUI
sed "s/\${NAMESPACE}/$NAMESPACE/g" manifests/open-webui.yaml | oc apply -f -

# Deploy MCP Server
sed "s/\${NAMESPACE}/$NAMESPACE/g" manifests/mcp-server.yaml | oc apply -f -

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
