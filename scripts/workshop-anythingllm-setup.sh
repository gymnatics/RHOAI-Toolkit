#!/bin/bash
# AnythingLLM Workspace Setup Script for Workshop
# Run this script after deploying AnythingLLM to configure optimal settings

set -e

NAMESPACE="${1:-$(oc project -q)}"
WORKSPACE_SLUG="${2:-my-workspace}"

echo "=== AnythingLLM Workshop Setup ==="
echo "Namespace: $NAMESPACE"
echo "Workspace: $WORKSPACE_SLUG"
echo ""

# Find the AnythingLLM pod
ANYTHINGLLM_POD=$(oc get pods -n "$NAMESPACE" -l app=anythingllm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$ANYTHINGLLM_POD" ]; then
    # Try notebook naming convention
    ANYTHINGLLM_POD=$(oc get pods -n "$NAMESPACE" --no-headers | grep anythingllm | awk '{print $1}' | head -1)
fi

if [ -z "$ANYTHINGLLM_POD" ]; then
    echo "ERROR: Could not find AnythingLLM pod in namespace $NAMESPACE"
    echo "Make sure AnythingLLM workbench is running."
    exit 1
fi

echo "Found AnythingLLM pod: $ANYTHINGLLM_POD"
echo ""

# Check if workspace exists
echo "Checking for existing workspace..."
WORKSPACE_EXISTS=$(oc exec -n "$NAMESPACE" "$ANYTHINGLLM_POD" -c anythingllm -- \
    curl -s http://localhost:3001/api/workspaces 2>/dev/null | grep -c "$WORKSPACE_SLUG" || echo "0")

if [ "$WORKSPACE_EXISTS" -eq "0" ]; then
    echo "Workspace '$WORKSPACE_SLUG' not found."
    echo "Please create a workspace in AnythingLLM first, then run this script again."
    echo ""
    echo "Steps:"
    echo "1. Open AnythingLLM in your browser"
    echo "2. Create a new workspace (you can name it '$WORKSPACE_SLUG')"
    echo "3. Run this script again"
    exit 1
fi

echo "Found workspace: $WORKSPACE_SLUG"
echo ""

# Define the optimized system prompt
SYSTEM_PROMPT='You are an OpenShift cluster assistant with access to MCP tools for managing Kubernetes resources.

CRITICAL RULES FOR TOOL USAGE:
1. NEVER use placeholder values like "<pod-name>", "<namespace>", "<resource-name>" or any text in angle brackets
2. Always use REAL, ACTUAL values when calling tools
3. If you need to find resource names, FIRST call the appropriate list function to get actual names
4. If a tool returns an error or empty result, try a different approach - do NOT repeat the same call with the same arguments
5. Pay attention to namespace spelling carefully

WORKFLOW FOR GETTING INFORMATION:
1. If the user mentions a specific namespace, use that exact namespace name
2. If unsure about the namespace, first call namespaces_list or projects_list to see available namespaces
3. To get pod information: first call pods_list_in_namespace to get actual pod names, then use those names for pods_get or pods_log
4. To get other resources: first call resources_list with the appropriate resource type

COMMON MISTAKES TO AVOID:
- Do NOT use placeholder text like "<pod-name>" - always get real names first
- Do NOT repeat failed tool calls with the same arguments
- Double-check namespace spelling before making calls

When the user asks about their resources, help them discover and work with resources in their namespace.'

echo "Updating workspace settings..."

# Update the workspace with optimized settings
RESULT=$(oc exec -n "$NAMESPACE" "$ANYTHINGLLM_POD" -c anythingllm -- \
    curl -s -X POST "http://localhost:3001/api/workspace/$WORKSPACE_SLUG/update" \
    -H "Content-Type: application/json" \
    -d "{\"openAiPrompt\": $(echo "$SYSTEM_PROMPT" | jq -Rs .), \"openAiHistory\": 40}" 2>&1)

if echo "$RESULT" | grep -q '"workspace"'; then
    echo "✅ Workspace updated successfully!"
    echo ""
    echo "Settings applied:"
    echo "  - System prompt: Optimized for MCP tool usage"
    echo "  - Chat history: 40 messages"
    echo ""
    echo "IMPORTANT: You should also increase the Context Window in the UI:"
    echo "1. Open AnythingLLM"
    echo "2. Go to Workspace Settings (gear icon)"
    echo "3. Find 'Context Window' or 'Max Tokens'"
    echo "4. Set it to 8192 or higher"
    echo "5. Save"
else
    echo "❌ Failed to update workspace"
    echo "Response: $RESULT"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo "You can now use @agent in your chat to invoke MCP tools."
