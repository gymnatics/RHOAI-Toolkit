# AnythingLLM System Prompt Configuration Guide

This guide explains how to configure the system prompt and token settings in AnythingLLM to improve MCP tool calling behavior.

## Quick Setup for Workshop Users

If you're a workshop participant, run this script after deploying AnythingLLM:

```bash
# From your terminal (logged into OpenShift)
curl -sL https://raw.githubusercontent.com/YOUR_REPO/workshop-anythingllm-setup.sh | bash -s -- <your-namespace> my-workspace
```

Or download and run locally:
```bash
./workshop-anythingllm-setup.sh <your-namespace> my-workspace
```

This script automatically configures the optimal system prompt and settings.

---

## Overview

When using AnythingLLM with MCP (Model Context Protocol) servers, the model may sometimes:
- Use incorrect namespace names (e.g., "admin-workspace" instead of "admin-workshop")
- Use placeholder values like `<pod-name>` instead of actual resource names
- Repeat failed tool calls with the same arguments

A well-crafted system prompt can significantly improve the model's tool calling accuracy.

## Method 1: Via AnythingLLM UI (Recommended)

1. **Open AnythingLLM** in your browser
2. **Navigate to Workspace Settings**:
   - Click on the gear icon (⚙️) next to your workspace name
   - Or click on "Workspace Settings" in the sidebar
3. **Find the "System Prompt" or "Chat Settings" section**
4. **Enter your custom system prompt** (see example below)
5. **Adjust Token Settings**:
   - **Chat History**: Increase to 40 (default is 20)
   - **Context Window**: Increase to 8192 or higher (default may be 1024)
6. **Save** the settings

## Method 2: Via API (Programmatic)

You can update the workspace settings via AnythingLLM's internal API:

```bash
# From inside the AnythingLLM pod or via port-forward
curl -X POST http://localhost:3001/api/workspace/<workspace-slug>/update \
  -H "Content-Type: application/json" \
  -d '{
    "openAiPrompt": "Your system prompt here...",
    "openAiHistory": 40
  }'
```

### Example using oc exec:

```bash
# Get the workspace slug first
oc exec -n <namespace> <anythingllm-pod> -c anythingllm -- \
  curl -s http://localhost:3001/api/workspaces | jq '.workspaces[].slug'

# Update the workspace
PROMPT='Your system prompt here...'
oc exec -n <namespace> <anythingllm-pod> -c anythingllm -- \
  curl -s -X POST http://localhost:3001/api/workspace/<workspace-slug>/update \
  -H "Content-Type: application/json" \
  -d "{\"openAiPrompt\": $(echo "$PROMPT" | jq -Rs .), \"openAiHistory\": 40}"
```

## Recommended System Prompt for OpenShift MCP

```
You are an OpenShift cluster assistant with access to MCP tools for managing Kubernetes resources.

CRITICAL RULES FOR TOOL USAGE:
1. NEVER use placeholder values like "<pod-name>", "<namespace>", "<resource-name>" or any text in angle brackets
2. Always use REAL, ACTUAL values when calling tools
3. If you need to find resource names, FIRST call the appropriate list function to get actual names
4. If a tool returns an error or empty result, try a different approach - do NOT repeat the same call with the same arguments
5. Pay attention to namespace spelling - common namespaces include "admin-workshop" (not "admin-workspace")

WORKFLOW FOR GETTING INFORMATION:
1. If the user mentions a specific namespace, use that exact namespace name
2. If unsure about the namespace, first call namespaces_list or projects_list to see available namespaces
3. To get pod information: first call pods_list_in_namespace to get actual pod names, then use those names for pods_get or pods_log
4. To get other resources: first call resources_list with the appropriate resource type

COMMON MISTAKES TO AVOID:
- Do NOT use "admin-workspace" - the correct name is "admin-workshop"
- Do NOT use placeholder text like "<pod-name>" - always get real names first
- Do NOT repeat failed tool calls with the same arguments

When the user asks about their resources, help them discover and work with resources in their namespace.
```

## Token Settings Explained

| Setting | Description | Recommended Value | API Updatable |
|---------|-------------|-------------------|---------------|
| **openAiHistory** | Number of previous messages to include in context | 40 (default: 20) | Yes |
| **contextWindow** | Maximum tokens for context | 8192+ (default: 1024) | UI only |
| **openAiTemp** | Temperature for response randomness | 0.7 (default) | Yes |
| **topN** | Number of document chunks for RAG | 4 (default) | Yes |

> **Note**: The `contextWindow` setting may need to be configured through the AnythingLLM UI under Workspace Settings → Chat Settings. The API may not update this field directly.

### Why Increase Token Limits?

1. **Larger Context Window (8192+)**:
   - Allows more conversation history to be included
   - Helps the model remember previous tool calls and their results
   - Essential for multi-step tool workflows

2. **More Chat History (40+)**:
   - Keeps more previous messages in context
   - Helps the model understand the conversation flow
   - Reduces repeated mistakes

3. **Model's Max Context**:
   - qwen3-4b supports up to 40,960 tokens
   - You can safely use 8192-16384 for the context window
   - Leave room for tool definitions and responses

## Verifying Your Settings

```bash
# Check current workspace settings
oc exec -n <namespace> <anythingllm-pod> -c anythingllm -- \
  curl -s http://localhost:3001/api/workspace/<workspace-slug> | jq '{
    prompt: .workspace.openAiPrompt,
    history: .workspace.openAiHistory,
    contextWindow: .workspace.contextWindow
  }'
```

## Troubleshooting

### Issue: Model still uses placeholder values
- Make the system prompt more explicit
- Add specific examples of correct vs incorrect tool calls
- Consider using a larger model (8B+ parameters)

### Issue: Tool calls timeout
- Check if the MCP server is responding
- Verify network connectivity between AnythingLLM and MCP server
- Check MCP server logs for errors

### Issue: Model doesn't use tools at all
- Ensure you're using `@agent` prefix in chat
- Verify MCP server is configured in AnythingLLM settings
- Check that tools are being attached (visible in logs)

## Checking Logs

```bash
# View AnythingLLM logs for tool call activity
oc logs -n <namespace> <anythingllm-pod> -c anythingllm --tail=100 | grep -i "tool\|mcp\|agent"
```

Look for:
- `Attached MCP::...` - Tools being loaded
- `Executing MCP server:` - Tool being called
- `completed successfully` - Tool call result
- `Function tool with exact arguments has already been called` - Repeated call (bad)
