#!/bin/bash
################################################################################
# Setup Elyra Runtime Configuration (run inside workbench terminal)
################################################################################
# Reads S3 credentials from the namespace's pipeline secret and generates the
# Elyra runtime JSON so pipelines can be submitted from the Elyra UI.
#
# Usage (inside workbench terminal):
#   bash <(oc get cm elyra-runtime-config -o jsonpath='{.data.setup\.sh}')
################################################################################

set -e

NAMESPACE="${NAMESPACE:-$(oc project -q 2>/dev/null)}"
if [ -z "$NAMESPACE" ]; then
    echo "ERROR: Could not determine namespace. Set NAMESPACE env var."
    exit 1
fi

SECRET_NAME="pipelines-s3-credentials"
if ! oc get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "ERROR: Secret '$SECRET_NAME' not found in $NAMESPACE."
    echo "Ensure the pipeline server (DSPA) is configured first."
    exit 1
fi

S3_ACCESS_KEY=$(oc get secret "$SECRET_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
S3_COS_PASS=$(oc get secret "$SECRET_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_COS_PASS" ]; then
    echo "ERROR: Could not read S3 credentials from secret '$SECRET_NAME'."
    exit 1
fi

TEMPLATE=$(oc get cm elyra-runtime-config -n "$NAMESPACE" \
    -o jsonpath='{.data.template}' 2>/dev/null)

if [ -z "$TEMPLATE" ]; then
    echo "WARNING: ConfigMap template not found. Using built-in defaults."
    TEMPLATE='{
  "display_name": "${NAMESPACE}",
  "metadata": {
    "runtime_type": "KUBEFLOW_PIPELINES",
    "api_endpoint": "http://ds-pipeline-pipelines-definition.${NAMESPACE}.svc:8888",
    "cos_endpoint": "http://minio.${NAMESPACE}.svc:9000",
    "cos_bucket": "pipelines",
    "cos_auth_type": "USER_CREDENTIALS",
    "cos_username": "${S3_ACCESS_KEY}",
    "cos_password": "${S3_COS_PASS}",
    "tags": []
  },
  "schema_name": "kfp"
}'
fi

RUNTIME_DIR="$HOME/.local/share/jupyter/metadata/runtimes"
mkdir -p "$RUNTIME_DIR"

export NAMESPACE S3_ACCESS_KEY S3_COS_PASS
echo "$TEMPLATE" | envsubst > "$RUNTIME_DIR/pipeline-demo.json"

echo "Elyra runtime configured: $RUNTIME_DIR/pipeline-demo.json"
echo "  Pipeline server: ds-pipeline-pipelines-definition.$NAMESPACE.svc:8443"
echo "  Object storage:  minio.$NAMESPACE.svc:9000"
echo ""
echo "Refresh Elyra: close and reopen any .pipeline file, or restart the notebook server."
