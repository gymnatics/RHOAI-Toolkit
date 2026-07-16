# Red Hat OpenShift AI — Model Deployment Workshop

> A hands-on guide for deploying AI models on Red Hat OpenShift AI (RHOAI) 3.4, testing them with the AI Playground, deploying Open WebUI as a chat interface, and enabling tool calling via MCP servers.

**Total time:** ~2.5 hours

---

## What You'll Learn

By the end of this workshop, you will:

- Create a Data Science project in OpenShift AI
- Deploy an AI model (Qwen3-4B) using the vLLM runtime via the dashboard
- Enable the AI Playground and chat with your model
- Deploy LlamaStack as a unified API layer for inference and tool calling
- Deploy Open WebUI as a self-hosted chat interface
- Connect Open WebUI to LlamaStack and add an MCP server for live cluster querying
- Understand hardware profiles, model serving, LlamaStack, and agentic AI concepts

### Workshop Structure


| Part                                    | Type           | Duration |
| --------------------------------------- | -------------- | -------- |
| Part 1: Access OpenShift AI             | Hands-on       | ~10 min  |
| Part 2: Create Your Project             | Hands-on       | ~5 min   |
| Part 3: Deploy a Model                  | Hands-on       | ~15 min  |
| Part 4: Wait for Model & Monitor        | Hands-on       | ~10 min  |
| Part 5: Test with AI Playground         | Hands-on       | ~15 min  |
| Part 6: Deploy LlamaStack               | Hands-on       | ~10 min  |
| Part 7: Deploy Open WebUI               | Hands-on       | ~10 min  |
| Part 8: Connect OpenWebUI + Add MCP     | Hands-on       | ~10 min  |
| Part 9: Test Tool Calling with MCP      | Hands-on       | ~10 min  |
| Appendix: Good to Know                  | Optional       | —        |


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

# Part 1: Access OpenShift AI (10 min)

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

# Part 2: Create Your Project (5 min)

A "project" (also known as a Kubernetes namespace) is your workspace where you'll deploy models, create workbenches, and run experiments.

## Step 2.1: Create a New Project

1. Click **"Projects"** in the left sidebar

![Projects Page](images/project_page.jpeg)

2. Click the **"Create project"** button (top right)
3. Fill in the form:

   | Field           | What to Enter                                         |
   | --------------- | ----------------------------------------------------- |
   | **Name**        | `user-XX` (use your assigned number, e.g., `user-05`) |
   | **Description** | `My workshop project` (optional)                      |

4. Click **"Create"**

![Create Project Dialog](images/create_project.jpeg)

You should now see your project `user-XX` with tabs for **Overview**, **Workbenches**, **Pipelines**, **Deployments**, **Connections**, etc.

![Project Overview](images/project_landing.jpeg)

---

# Part 3: Deploy a Model (15 min)

In this section, you'll deploy the **Qwen3-4B** model using the **vLLM** serving runtime. The model is stored as an OCI (container) image, so no S3 storage credentials are needed.

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

| Field              | What to Select/Enter                                          |
| ------------------ | ------------------------------------------------------------- |
| **Model location** | `URI`                                                         |
| **URI**            | `oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b` |
| **Name**           | `qwen3-4b` (auto-populated from URI)                         |
| **Model type**     | `Generative AI model (Example, LLM)`                         |

> **Tip:** Copy the URI exactly as shown. The name field will auto-populate. This pulls the model as an OCI container image — no storage credentials are required.

![Wizard Step 1 — Filled](images/model_deployment-2.jpeg)

Click **"Next"** to proceed.

---

## Step 3.4: Wizard Step 2 — Model Deployment

Configure the deployment settings:

| Field                      | What to Select/Enter                        |
| -------------------------- | ------------------------------------------- |
| **Model deployment name**  | `qwen3-4b` (auto-populated)                |
| **Hardware profile**       | Select `GPU Profile (L4 24GB)` or your GPU profile |
| **Deployment resource**    | `Automatic selection` or `Manual selection` |
| **Number of replicas**     | `1`                                         |

![Wizard Step 2 — Deployment name and hardware profile](images/model_deployment_3.jpeg)

If you choose **Manual selection** for deployment resource, select **vLLM NVIDIA GPU ServingRuntime for KServe** from the dropdown:

![Runtime Selection](images/vllm_runtime.jpeg)

![Wizard Step 2 — Runtime and replicas](images/model_deployment-4.jpeg)

Click **"Next"** to proceed.

---

## Step 3.5: Wizard Step 3 — Advanced Settings

This step configures model availability and access. **You must check "Publish as AI asset endpoint"** to use the AI Playground later.

| Setting                           | What to Do                        |
| --------------------------------- | --------------------------------- |
| **Publish as AI asset endpoint**  | **Check this box** (required for Playground) |
| **Make model deployment available through an external route** | Leave unchecked (optional) |
| **Require token authentication**  | Leave unchecked (optional) |
| **Add custom runtime arguments**  | Leave unchecked (for now) |

![Advanced Settings](images/model_deployment-5.jpeg)

> **Important:** If you skip checking "Publish as AI asset endpoint", your model will not appear in the Playground.

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

![Review Page](images/review-model.jpeg)

Click **"Deploy model"** to start the deployment.

---

# Part 4: Wait for Model & Monitor (10 min)

The model needs a few minutes to pull the container image and start the vLLM server.

## Step 4.1: Monitor Deployment Status

1. After clicking Deploy, you'll be taken to the Deployments tab
2. Watch the status indicator next to `qwen3-4b`:

| Status       | What It Means                                        |
| ------------ | ---------------------------------------------------- |
| **Starting** | Container image is being pulled and model is loading |
| **Ready**    | Model is ready to serve requests                     |
| **Failed**   | Something went wrong (check events)                  |

![Model Starting](images/model-wait.jpeg)

> This typically takes **3–5 minutes** depending on image cache state and GPU availability. Feel free to stretch!

## Step 4.2: Verify the Model is Running

Once the status shows **Ready** (green), your model is ready.

![Model Ready](images/model-done.png)

1. Click the **question mark icon** next to the model name to see the resource name and type (`InferenceService`)

![Resource Name](images/resource-name.png)

2. Click the **expand arrow** (>) to the left of the model name to see deployment details including inference endpoints, hardware profile, and token authentication

![Model Details Expanded](images/token.png)

---

# Part 5: Test with AI Playground (15 min)

The **AI Playground** provides a chat interface to interact with your deployed model directly from the dashboard — no code required.

## Step 5.1: Verify AI Asset Endpoint

Since you checked **"Publish as AI asset endpoint"** during deployment (Step 3.5), your model should already be registered.

1. Click **"Gen AI studio"** in the left sidebar to expand it
2. Click **"AI asset endpoints"**
3. Make sure your project (`user-XX`) is selected in the **Project** dropdown
4. You should see `qwen3-4b` listed with a **Ready** status

![AI Asset Endpoints](images/ai-asset-endpoint.png)

---

## Step 5.2: Create the Playground

1. On the AI asset endpoints page, click **"Add to playground"** next to your model
2. In the **"Configure playground"** dialog, make sure `qwen3-4b` is checked
3. Click **"Create"**

![Configure Playground](images/create-playground.png)

---

## Step 5.3: Open the Playground

1. Click **"Gen AI studio"** > **"Playground"** in the left sidebar
2. You should see the Playground interface with your model selected

![Playground Interface](images/open-playground.png)

---

## Step 5.4: Chat with Your Model

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

Your AI model is working! You can continue chatting with it about any topic.

---

## Step 5.5: Explore Playground Settings

The Playground offers several configuration options to tune model behavior:


| Setting           | What It Does                                          | Suggested Value     |
| ----------------- | ----------------------------------------------------- | ------------------- |
| **Temperature**   | Controls randomness (0 = deterministic, 1 = creative) | 0.7                 |
| **Max tokens**    | Maximum length of the response                        | 256–1024            |
| **Top P**         | Nucleus sampling threshold                            | 0.9                 |
| **System prompt** | Sets the model's persona/instructions                 | (try a custom one!) |


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

# Part 6: Deploy LlamaStack (10 min)

In the previous section, you tested your model using the built-in AI Playground. Now you'll deploy **LlamaStack** — a unified API layer that brings together inference, tool calling (MCP), and RAG under a single Kubernetes-managed endpoint.

## What is LlamaStack?

LlamaStack is a developer framework for building generative AI applications. On RHOAI, it's managed by the **LlamaStack Operator** — you deploy a `LlamaStackDistribution` custom resource, and the operator creates and manages the LlamaStack server for you.

**Why LlamaStack?** Instead of connecting to the model and MCP servers separately, LlamaStack provides a **single endpoint** that handles:
- **Inference** — forwards requests to your LLM (vLLM/RHOAI)
- **Tool calling** — executes MCP tools on behalf of the model

Your instructor has already deployed a shared model (qwen3-4b with tool calling) and a Kubernetes MCP server. You'll deploy LlamaStack in your own namespace, pointing to these shared services.

## Step 6.1: Set Up Your Environment

Open a terminal using the **Web Terminal** in the OpenShift console — click the **`>_`** icon in the top-right masthead. This gives you an in-browser terminal with `oc`, `git`, and `envsubst` pre-installed (no local CLI tools needed).

Set your environment variables. Replace the values with your assigned user number and the token provided by your instructor.

```bash
# Set your namespace (replace XX with your number)
export NAMESPACE=user-XX

# Set the model token (provided by your instructor)
export MODEL_TOKEN=<paste-token-here>
```

## Step 6.2: Deploy LlamaStack

Clone the workshop repository and deploy LlamaStack using the provided manifest:

```bash
git clone https://github.com/gymnatics/Red-Hat-Inference-Workshop.git
cd Red-Hat-Inference-Workshop

envsubst < manifests/llamastack.yaml | oc apply -f -
```

> **What just happened?** The manifest created three Kubernetes resources in your namespace:
> - A **Secret** with the shared model's URL and authentication token
> - A **ConfigMap** with LlamaStack's `run.yaml` configuration — this tells LlamaStack where to find the model and the MCP server
> - A **LlamaStackDistribution** custom resource — the LlamaStack Operator sees this and deploys a LlamaStack server pod in your namespace
>
> You can inspect the full YAML in [`manifests/llamastack.yaml`](manifests/llamastack.yaml).

## Step 6.3: Wait for LlamaStack to Start

```bash
oc wait --for=condition=available deployment -l llamastack.io/distribution=llamastack-workshop \
  -n $NAMESPACE --timeout=120s
```

This typically takes 1-2 minutes. When ready, verify:

```bash
oc get pods -n $NAMESPACE -l llamastack.io/distribution=llamastack-workshop
```

You should see a pod in `Running` state.

> **Tip:** If the pod is in `CrashLoopBackOff`, check the logs: `oc logs -n $NAMESPACE -l llamastack.io/distribution=llamastack-workshop`

---

# Part 7: Deploy Open WebUI (10 min)

Now you'll deploy **Open WebUI** — a self-hosted chat interface (similar to ChatGPT) that you'll connect to your LlamaStack instance.

## Step 7.1: Deploy Open WebUI

Make sure your `NAMESPACE` variable is still set and you're in the workshop repo directory, then deploy:

```bash
envsubst < manifests/open-webui.yaml | oc apply -f -
```

> **What this deploys:** A ConfigMap, PVC, Deployment, Service, and Route for Open WebUI. The `OPENAI_API_BASE_URLS` points to your LlamaStack instance — not directly to the model. LlamaStack acts as the unified API layer between OpenWebUI and the backend services.
>
> You can inspect the full YAML in [`manifests/open-webui.yaml`](manifests/open-webui.yaml).

## Step 7.2: Wait for Open WebUI

```bash
oc rollout status deployment/open-webui -n $NAMESPACE --timeout=120s
```

## Step 7.3: Access Open WebUI

```bash
echo "https://$(oc get route open-webui -n $NAMESPACE -o jsonpath='{.spec.host}')"
```

Open this URL in your browser. If you see a sign-up page, create any account — authentication is disabled for the workshop.

## Step 7.4: Quick Test

1. Click **"New Chat"**
2. Select `qwen3-4b` from the model dropdown
3. Type: `Hello, what model are you?`
4. Verify you get a response — this confirms OpenWebUI → LlamaStack → vLLM is working

> **Note:** When calling the LlamaStack API directly (e.g., via `curl`), the full model ID is `vllm-inference/qwen3-4b`. The OpenWebUI dropdown shows the short name.

---

# Part 8: Add MCP Server — Tool Calling (10 min)

Your LlamaStack instance already knows about the Kubernetes MCP server (it's in the `connectors` config). But for OpenWebUI to execute tool calls, you need to connect OpenWebUI **directly** to the MCP server as well.

## What is MCP?

**Model Context Protocol (MCP)** is a standard that lets LLMs call external tools. Instead of relying only on training data, the model can make tool calls to fetch live information — like listing pods, checking deployments, or viewing cluster status.

Your instructor has deployed a **Kubernetes MCP Server** that provides tools for querying the OpenShift cluster.

## Step 8.1: Add the MCP Server to Open WebUI

1. In Open WebUI, click the **gear icon** (bottom-left) to open **Settings**
2. Navigate to **Admin Settings** (you may need to click your avatar/name → Admin Panel)
3. Go to **Settings** → **Tools** (or **External Tools**)
4. Click **+ Add Connection**
5. Configure:

   | Field | Value |
   |-------|-------|
   | **Type** | **MCP (Streamable HTTP)** |
   | **URL** | `http://kubernetes-mcp-server.admin-workshop.svc.cluster.local:8080/mcp` |
   | **Auth** | **None** |

6. Click **Save**

## Step 8.2: Verify Tools Are Available

After saving, you should see the Kubernetes MCP Server listed with its available tools. Common tools include:

- **list_pods** — List pods in a namespace
- **get_pod** — Get details of a specific pod
- **list_deployments** — List deployments
- **list_services** — List services
- **get_logs** — Get pod logs
- **list_namespaces** — List cluster namespaces

> If tools don't appear immediately, try refreshing the page.

---

# Part 9: Test Tool Calling with MCP (10 min)

Now test the model's ability to use MCP tools to query your cluster in real time.

## Step 9.1: Start a New Chat

1. Click **"New Chat"**
2. Select `qwen3-4b` from the model dropdown
3. Make sure **Function Calling** is enabled (check in the chat settings/advanced params — it should be set to **Native**)

## Step 9.2: Try These Prompts

Ask the model questions that require cluster data. Watch how it makes tool calls to the Kubernetes MCP server:

**Query your own namespace:**
```
What pods are running in the user-XX namespace?
```

**Check model deployments:**
```
List all InferenceServices across all namespaces. Which ones are ready?
```

**Explore the cluster:**
```
What GPU nodes are available in this cluster? How much GPU memory do they have?
```

**Troubleshoot a deployment:**
```
Check the status of the qwen3-4b deployment in the admin-workshop namespace. Is it healthy?
```

**Get logs:**
```
Show me the recent logs from the kubernetes-mcp-server pod in admin-workshop namespace.
```

## Step 9.3: Observe Tool Calling in Action

When the model uses an MCP tool, you'll see:

1. The model decides which tool to call based on your question
2. A **tool call** is displayed showing the function name and parameters
3. The **tool response** returns real data from the cluster
4. The model uses the real data to formulate its answer

This is **agentic AI** in action — the model is not guessing, it's querying live infrastructure.

## Step 9.4: Understand the Architecture

Take a moment to appreciate what you've built:

```
You (browser)
  → Open WebUI (chat interface in your namespace)
    → LlamaStack (unified API layer in your namespace)
      → vLLM model (shared, in admin-workshop)
    → Kubernetes MCP Server (shared, in admin-workshop)
      → OpenShift API (live cluster data)
```

- **LlamaStack** provides the unified API layer — one Kubernetes CR gives you inference and tool calling under a single endpoint
- **Open WebUI** provides the chat interface and handles MCP tool execution
- **MCP** provides the tools that let the model interact with real infrastructure

> **Compare:** Try asking the same question in the AI Playground (Part 5). The Playground model will answer from training data only — it doesn't know what's actually running on your cluster. The MCP-connected model gives you real answers.

---

# Appendix: Good to Know

These are optional topics for further exploration after the workshop.

---

## Tool Calling

Tool calling allows the model to invoke external tools (APIs, databases, etc.) to answer questions with live data. To enable it, add **custom runtime arguments** during model deployment in the **Advanced settings** step (Step 3 of the wizard):

1. Check **"Add custom runtime arguments"**
2. Add the following arguments (each on its own line):

   ```
   --enable-auto-tool-choice
   --tool-call-parser=hermes
   ```

![Custom Runtime Arguments](images/vllm-args.png)

![Advanced Settings with Tool Calling](images/model-deployment-6.jpeg)

| Argument                    | Purpose                                            |
| --------------------------- | -------------------------------------------------- |
| `--enable-auto-tool-choice` | Allows the model to decide when to use tools       |
| `--tool-call-parser=hermes` | Tells vLLM how to parse Qwen's tool call output    |

Different model families require different tool call parsers:

| Model Family | Parser        |
| ------------ | ------------- |
| Llama        | `llama3_json` |
| Qwen         | `hermes`      |
| Mistral      | `mistral`     |

---

## Model Catalog

RHOAI 3.4 includes a **Model Catalog** with pre-validated model configurations:

1. Click **"Model catalog"** in the left sidebar
2. Browse available models (Granite, Llama, Qwen, Mistral, etc.)
3. Click on a model to see details, recommended hardware, and deployment instructions
4. Click **"Deploy"** to start a pre-configured deployment

---

# Congratulations!

You've completed the Model Deployment Workshop!

## What You Accomplished


| Task                                                    | Status |
| ------------------------------------------------------- | ------ |
| Logged into OpenShift AI                                | Done   |
| Created a Data Science project                          | Done   |
| Deployed a model with vLLM runtime                      | Done   |
| Monitored deployment status                             | Done   |
| Tested the model via the AI Playground                  | Done   |
| Deployed LlamaStack as a unified API layer              | Done   |
| Deployed Open WebUI as a self-hosted chat interface     | Done   |
| Added an MCP server for tool calling                    | Done   |
| Tested agentic AI with live cluster queries             | Done   |


## What's Next?

After this workshop, you can explore:


| Topic                          | Where to Learn More                                                                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **More MCP Tools**             | Deploy Weather, GitHub, or custom MCP servers for more tool capabilities. See [MCP Server Setup](MCP-SERVER-SETUP.md)                       |
| **Models-as-a-Service (MaaS)** | API keys, subscriptions, and rate limiting for multi-tenant model access. See [MaaS Policy Enforcement](MAAS-POLICY-ENFORCEMENT.md)         |
| **NeMo Guardrails**            | Add safety guardrails to your model responses. See [RHCL + Guardrails Architecture](RHCL-GUARDRAILS-ARCHITECTURE.md)                        |
| **Model Registry**             | Version and manage your models. See [Model Registry](MODEL-REGISTRY.md)                                                                     |
| **AI Pipelines**               | Build automated ML workflows. See the [RHOAI documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4) |
| **LLM Evaluation**             | Benchmark your models with LMEval. See the [Demo Environment](DEMO-ENVIRONMENT.md)                                                          |


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

## "Playground not loading or no models available"

**Cause:** Model is not registered as an AI asset, or model is not fully ready.

**Fix:**

1. Verify your model shows **Available** status in the Deployments tab
2. Ensure the model is registered as an AI asset endpoint
3. Try refreshing the browser page
4. Wait 1–2 minutes after the model becomes Available

## "Open WebUI shows 'Connection error' or no models"

**Cause:** Model URL or token is incorrect, or the model is not accessible from your namespace.

**Fix:**

1. Verify the model URL and token with your instructor
2. Check that the model is running: `oc get inferenceservice qwen3-4b -n admin-workshop`
3. In Open WebUI Settings → Connections, click the refresh icon to re-test
4. Make sure the URL ends with `/v1`

## "MCP tools don't appear in Open WebUI"

**Cause:** MCP server URL is wrong, or the server is not running.

**Fix:**

1. Verify the MCP server is running: `oc get pods -n admin-workshop | grep mcp`
2. Check the URL is exactly: `http://kubernetes-mcp-server.admin-workshop.svc.cluster.local:8080/mcp`
3. Make sure you selected **MCP (Streamable HTTP)** as the type (not OpenAPI)
4. Try removing and re-adding the MCP server connection
5. Refresh the Open WebUI page

## "Model doesn't make tool calls"

**Cause:** Function calling may not be enabled, or the model doesn't support tool calling.

**Fix:**

1. Make sure you're using the shared model (`qwen3-4b` from `admin-workshop`), not your own deployment
2. In the chat, check that the MCP tools are enabled (look for a tools toggle)
3. Be explicit in your prompt: "Use the available tools to check what pods are running in namespace user-XX"

## Still stuck?

Raise your hand! The instructors are here to help.

---

# Quick Reference Card

## Your Info

- **Username:** `_______`_
- **Password:** `________`
- **Project name:** `user-____`

## Key URLs


| Resource        | URL                                   |
| --------------- | ------------------------------------- |
| RHOAI Dashboard | `https://rh-ai.apps.<cluster-domain>` |


## Key Terminal Commands

```bash
# Check your login
oc whoami

# Switch to your project
oc project user-XX

# Check model pods
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

# Appendix: Instructor Setup Checklist

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


| Field                     | Value                                                                    |
| ------------------------- | ------------------------------------------------------------------------ |
| OpenShift AI Dashboard URL | `https://rh-ai.apps.<cluster-domain>`                                   |
| Login provider            | `htpasswd` or `workshop-users`                                           |
| Username                  | `userXX`                                                                 |
| Password                  | (your chosen password)                                                   |
| User number (for project) | `XX`                                                                     |
| Shared Model URL          | `https://qwen3-4b-admin-workshop.<cluster-domain>/v1`                    |
| Shared Model Token        | (from Step 6 above)                                                      |
| MCP Server URL            | `http://kubernetes-mcp-server.admin-workshop.svc.cluster.local:8080/mcp` |


---

**Reference:** [RHOAI 3.4 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4)