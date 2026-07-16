#!/bin/bash
################################################################################
# workshop-setup.sh — Workshop environment setup (RHOAI 3.4 + OpenWebUI)
################################################################################
# Provides:
#   setup_workshop_users            — Create htpasswd users, OAuth, RBAC
#   add_kubeadmin_to_rhods_admins   — Add kube:admin to rhods-admins group
#   setup_workshop_grafana          — Deploy admin Grafana with dashboards
#   setup_workshop_model_and_mcp    — Deploy qwen3-4b (tool calling) + K8s MCP server
#   setup_user_workload_monitoring  — Enable Prometheus UWM and vLLM metrics
#   run_complete_workshop_setup     — Full workshop setup orchestrator
#   install_web_terminal             — Install Web Terminal operator
#   disable_vllm_on_maas             — Disable vLLM on MaaS tech preview
#   create_gpu_machineset_for_workshop — Create AWS GPU MachineSet
#   scale_worker_nodes              — Scale worker MachineSet replicas
################################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || true

setup_workshop_users() {
    local user_count="${1:-150}"
    
    print_header "Setting Up Workshop Users ($user_count users)"
    
    print_step "Creating htpasswd file with $user_count users..."
    local htpasswd_file="/tmp/workshop-users.htpasswd"
    rm -f "$htpasswd_file"
    
    for i in $(seq 1 $user_count); do
        if [ $i -eq 1 ]; then
            htpasswd -c -B -b "$htpasswd_file" "user$i" "openshift" 2>/dev/null
        else
            htpasswd -B -b "$htpasswd_file" "user$i" "openshift" 2>/dev/null
        fi
        if [ $((i % 25)) -eq 0 ]; then
            echo "  Created $i users..."
        fi
    done
    print_success "Created $user_count users in htpasswd file"
    
    print_step "Creating htpasswd secret..."
    oc create secret generic workshop-htpasswd-secret \
        --from-file=htpasswd="$htpasswd_file" \
        -n openshift-config --dry-run=client -o yaml | oc apply -f -
    print_success "HTPasswd secret created"
    
    print_step "Configuring OAuth..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/oauth.yaml"
    print_success "OAuth configured"
    
    # Group requires dynamic user list — generated inline
    print_step "Creating workshop-users group..."
    cat <<EOF | oc apply -f -
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: workshop-users
users:
$(for i in $(seq 1 $user_count); do echo "- user$i"; done)
EOF
    print_success "Workshop users group created"
    
    print_step "Creating admin-workshop namespace..."
    oc new-project admin-workshop 2>/dev/null || oc project admin-workshop 2>/dev/null || true
    print_success "admin-workshop namespace ready"
    
    print_step "Creating Prometheus token..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/prometheus-token-monitoring.yaml"
    sleep 5
    
    local token
    token=$(oc get secret grafana-prometheus-token -n openshift-monitoring -o jsonpath='{.data.token}' 2>/dev/null || true)
    if [ -n "$token" ]; then
        export PROMETHEUS_TOKEN="$token"
        envsubst '${PROMETHEUS_TOKEN}' < "$ROOT_DIR/lib/manifests/workshop/prometheus-token-workshop.yaml" | oc apply -f -
        unset PROMETHEUS_TOKEN
        print_success "Prometheus token created in admin-workshop"
    fi
    
    print_step "Creating RBAC for workshop users..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/secret-reader-role.yaml"
    
    for i in $(seq 1 $user_count); do
        export USER_NAME="user$i"
        envsubst '${USER_NAME}' < "$ROOT_DIR/lib/manifests/workshop/secret-reader-rolebinding.yaml" | oc apply -f - 2>/dev/null
        if [ $((i % 25)) -eq 0 ]; then
            echo "  Created RBAC for $i users..."
        fi
    done
    unset USER_NAME
    print_success "RBAC created for $user_count users"
    
    print_success "Workshop users setup complete!"
    echo ""
    echo -e "${GREEN}Users:${NC} user1 to user$user_count"
    echo -e "${GREEN}Password:${NC} openshift"
    
    add_kubeadmin_to_rhods_admins
}

add_kubeadmin_to_rhods_admins() {
    print_step "Adding kube:admin to rhods-admins group..."
    
    local current_users
    current_users=$(oc get group rhods-admins -o jsonpath='{.users}' 2>/dev/null || echo "[]")
    
    if echo "$current_users" | grep -q "b64:kube:admin"; then
        print_success "kube:admin already in rhods-admins group"
        return 0
    fi
    
    oc patch group rhods-admins --type=json -p='[{"op": "add", "path": "/users/-", "value": "b64:kube:admin"}]' 2>/dev/null || \
        oc apply -f "$ROOT_DIR/lib/manifests/workshop/rhods-admins-group.yaml"
    
    print_success "kube:admin added to rhods-admins group"
    
    print_step "Configuring RHOAI dashboard admin groups..."
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
      "spec": {
        "groupsConfig": {
          "adminGroups": "rhods-admins,dedicated-admins,cluster-admins",
          "allowedGroups": "system:authenticated"
        }
      }
    }' 2>/dev/null || true
    
    print_success "RHOAI dashboard admin groups configured"
}

setup_workshop_grafana() {
    print_header "Setting Up Admin Grafana with Dashboards"
    
    echo -e "${YELLOW}Note: This deploys an admin Grafana instance with pre-configured dashboards.${NC}"
    echo -e "${YELLOW}Workshop users will deploy their own Grafana using: oc apply -f obs/grafana-user-setup.yaml -n <their-namespace>${NC}"
    echo ""
    
    print_step "Cloning workshop repository..."
    cd /tmp
    rm -rf rhoai-genai-workshop
    git clone https://github.com/cbtham/rhoai-genai-workshop.git
    cd rhoai-genai-workshop
    print_success "Workshop repository cloned"
    
    print_step "Creating Grafana namespace..."
    oc new-project grafana 2>/dev/null || true
    
    print_step "Deploying Admin Grafana..."
    oc apply -f obs/grafana-setup.yaml -n grafana
    oc apply -f obs/expose-grafana.yaml -n grafana
    print_success "Admin Grafana deployed"
    
    print_step "Getting Prometheus token..."
    local prom_token
    prom_token=$(oc get secret grafana-prometheus-token -n openshift-monitoring -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
    if [ -z "$prom_token" ]; then
        oc apply -f "$ROOT_DIR/lib/manifests/workshop/prometheus-token-monitoring.yaml"
        sleep 10
        prom_token=$(oc get secret grafana-prometheus-token -n openshift-monitoring -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
    fi
    
    # Datasource name MUST be "Prometheus" (capital P) to match dashboard references
    print_step "Creating Prometheus datasource provisioning..."
    export PROM_TOKEN="$prom_token"
    envsubst '${PROM_TOKEN}' < "$ROOT_DIR/lib/manifests/workshop/grafana-datasource-provisioning.yaml" | oc apply -f - -n grafana
    unset PROM_TOKEN
    print_success "Prometheus datasource provisioning created"
    
    print_step "Waiting for Grafana to be ready..."
    sleep 30
    
    print_step "Copying pre-configured dashboards..."
    
    if [ -f "$ROOT_DIR/lib/manifests/grafana/vllm-dashboard.json" ]; then
        cp "$ROOT_DIR/lib/manifests/grafana/vllm-dashboard.json" /tmp/vllm-dashboard.json
        cp "$ROOT_DIR/lib/manifests/grafana/vllm-advanced-dashboard.json" /tmp/llm-performance-dashboard.json
        cp "$ROOT_DIR/lib/manifests/grafana/nvidia-dcgm-dashboard.json" /tmp/nvidia-dcgm-dashboard.json
        print_success "Using local pre-configured dashboards"
    else
        print_warning "Local dashboards not found, downloading from internet..."
        curl -sL "https://raw.githubusercontent.com/redhat-et/ai-observability/main/vllm-dashboards/vllm-grafana-openshift.json" -o /tmp/vllm-dashboard.json
        curl -sL "https://github.com/cbtham/rhoai-genai-workshop/raw/main/obs/grafana-dashboard-llm-performance.json" -o /tmp/llm-performance-dashboard.json
        curl -sL "https://grafana.com/api/dashboards/12239/revisions/1/download" -o /tmp/nvidia-dcgm-dashboard.json
        
        print_step "Fixing datasource references in dashboards..."
        for dashboard in /tmp/vllm-dashboard.json /tmp/nvidia-dcgm-dashboard.json /tmp/llm-performance-dashboard.json; do
            sed -i.bak 's/\${DS_PROMETHEUS}/Prometheus/g' "$dashboard" 2>/dev/null || \
                sed -i '' 's/\${DS_PROMETHEUS}/Prometheus/g' "$dashboard"
            sed -i.bak 's/"datasource": *"prometheus"/"datasource": "Prometheus"/g' "$dashboard" 2>/dev/null || \
                sed -i '' 's/"datasource": *"prometheus"/"datasource": "Prometheus"/g' "$dashboard"
        done
    fi
    
    print_success "Dashboards ready"
    
    print_step "Creating dashboard ConfigMaps..."
    
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/grafana-dashboard-provider.yaml" -n grafana
    
    oc create configmap grafana-vllm-dashboard -n grafana --from-file=vllm-dashboard.json=/tmp/vllm-dashboard.json --dry-run=client -o yaml | oc apply -f -
    oc create configmap grafana-llm-performance-dashboard -n grafana --from-file=llm-performance-dashboard.json=/tmp/llm-performance-dashboard.json --dry-run=client -o yaml | oc apply -f -
    oc create configmap grafana-nvidia-dcgm-dashboard -n grafana --from-file=nvidia-dcgm-dashboard.json=/tmp/nvidia-dcgm-dashboard.json --dry-run=client -o yaml | oc apply -f -
    
    print_success "Dashboard ConfigMaps created"
    
    print_step "Patching Grafana deployment with datasource and dashboards..."
    
    oc patch deployment grafana -n grafana --type='json' -p='[
      {"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "datasource-provisioning", "configMap": {"name": "grafana-datasource-provisioning"}}},
      {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "datasource-provisioning", "mountPath": "/etc/grafana/provisioning/datasources"}}
    ]' 2>/dev/null || print_warning "Datasource provisioning may already be mounted"
    
    oc patch deployment grafana -n grafana --type='json' -p='[
      {"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "dashboard-provider", "configMap": {"name": "grafana-dashboard-provider"}}},
      {"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "vllm-dashboard", "configMap": {"name": "grafana-vllm-dashboard"}}},
      {"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "llm-performance-dashboard", "configMap": {"name": "grafana-llm-performance-dashboard"}}},
      {"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "nvidia-dcgm-dashboard", "configMap": {"name": "grafana-nvidia-dcgm-dashboard"}}},
      {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "dashboard-provider", "mountPath": "/etc/grafana/provisioning/dashboards"}},
      {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "vllm-dashboard", "mountPath": "/var/lib/grafana/dashboards/vllm-dashboard.json", "subPath": "vllm-dashboard.json"}},
      {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "llm-performance-dashboard", "mountPath": "/var/lib/grafana/dashboards/llm-performance-dashboard.json", "subPath": "llm-performance-dashboard.json"}},
      {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"name": "nvidia-dcgm-dashboard", "mountPath": "/var/lib/grafana/dashboards/nvidia-dcgm-dashboard.json", "subPath": "nvidia-dcgm-dashboard.json"}}
    ]' 2>/dev/null || print_warning "Dashboard volumes may already be mounted"
    
    print_step "Waiting for Grafana to restart..."
    sleep 20
    
    local grafana_url
    grafana_url=$(oc get route grafana -n grafana -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "Not available")
    
    print_success "Grafana setup complete!"
    echo ""
    echo -e "${GREEN}Grafana URL:${NC} $grafana_url"
    echo -e "${GREEN}Credentials:${NC} admin / admin"
    echo -e "${GREEN}Dashboards:${NC} vLLM, LLM Performance, NVIDIA DCGM"
}

setup_workshop_model_and_mcp() {
    print_header "Deploying Admin Model, MCP Server, and Enabling LlamaStack"

    print_step "Enabling LlamaStack operator..."
    oc patch datasciencecluster default-dsc --type merge \
        -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}' 2>/dev/null || true
    print_success "LlamaStack operator enabled"

    oc new-project admin-workshop 2>/dev/null || oc project admin-workshop 2>/dev/null || true

    local gpu_nodes
    gpu_nodes=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)
    if [ "$gpu_nodes" -eq 0 ]; then
        print_warning "No GPU nodes detected. Model deployment may fail."
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        print_success "Found $gpu_nodes GPU node(s)"
    fi

    print_step "Deploying ServingRuntime (vLLM with tool calling)..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/workshop-servingruntime.yaml"
    print_success "ServingRuntime created"

    print_step "Deploying InferenceService (qwen3-4b)..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/workshop-inferenceservice.yaml"
    print_success "InferenceService created"

    print_step "Creating external route for model..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/workshop-model-service.yaml"
    oc create route edge qwen3-4b --service=qwen3-4b-external --port=8080 -n admin-workshop 2>/dev/null || true
    print_success "External route created"

    print_step "Waiting for model to be ready (this may take 5-10 minutes)..."
    local timeout=600
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local status
        status=$(oc get inferenceservice qwen3-4b -n admin-workshop -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$status" == "True" ]; then
            print_success "Model is READY!"
            break
        fi
        echo "  Waiting for model... (${elapsed}s elapsed)"
        sleep 30
        elapsed=$((elapsed + 30))
    done

    print_step "Deploying Kubernetes MCP Server..."

    local mcp_image="quay.io/redhat-ai-services/kubernetes-mcp-server"
    local mcp_args='["--port=8080", "--read-only"]'

    export NAMESPACE="admin-workshop"
    export CLUSTER_ROLE="view"
    export MCP_SERVER_IMAGE="$mcp_image"
    export MCP_SERVER_ARGS="$mcp_args"
    envsubst < "$ROOT_DIR/lib/manifests/mcp/kubernetes-mcp-server.yaml" | oc apply -f - -n admin-workshop
    unset NAMESPACE CLUSTER_ROLE MCP_SERVER_IMAGE MCP_SERVER_ARGS

    print_step "Waiting for MCP Server to be ready..."
    if oc rollout status deployment/kubernetes-mcp-server -n admin-workshop --timeout=180s 2>/dev/null; then
        print_success "Kubernetes MCP Server is running"
    else
        print_warning "MCP Server may still be starting (check pods)"
    fi

    local cluster_domain
    cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

    local model_token=""
    local sa_secret
    sa_secret=$(oc get secret -n admin-workshop 2>/dev/null | grep "default-name-qwen3-4b-sa" | head -1 | awk '{print $1}')
    if [ -n "$sa_secret" ]; then
        model_token=$(oc get secret "$sa_secret" -n admin-workshop -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null)
    fi

    print_success "Model and MCP Server deployment complete!"
    echo ""
    echo -e "${GREEN}Model Endpoint:${NC} https://qwen3-4b-admin-workshop.${cluster_domain}/v1"
    if [ -n "$model_token" ]; then
        echo -e "${GREEN}Model Token:${NC} $model_token"
    fi
    echo -e "${GREEN}MCP Server (internal):${NC} http://kubernetes-mcp-server.admin-workshop.svc.cluster.local:8080/mcp"
    echo -e "${GREEN}LlamaStack Operator:${NC} Enabled (participants deploy LlamaStackDistribution in their namespaces)"
    echo ""
    echo -e "${YELLOW}Share with participants:${NC}"
    echo "  1. Model Token: (shown above)"
    echo "  2. Workshop guide: https://github.com/gymnatics/Red-Hat-Inference-Workshop"
    echo ""
    echo -e "${YELLOW}Participants will deploy in their own namespaces:${NC}"
    echo "  1. LlamaStack (unified API layer → shared model + MCP)"
    echo "  2. OpenWebUI (chat interface → LlamaStack + MCP)"
}

setup_user_workload_monitoring() {
    print_header "Setting Up User Workload Monitoring"
    
    print_step "Enabling User Workload Monitoring..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/cluster-monitoring-config.yaml"
    print_success "User Workload Monitoring enabled"
    
    print_step "Waiting for User Workload Monitoring pods..."
    sleep 30
    oc get pods -n openshift-user-workload-monitoring 2>/dev/null || print_warning "UWM pods not yet ready"
    
    print_step "Creating vLLM metrics allowlist..."
    oc apply -f "$ROOT_DIR/lib/manifests/workshop/uwm-metrics-allowlist.yaml"
    print_success "vLLM metrics allowlist created"
}

install_web_terminal() {
    print_header "Installing Web Terminal Operator"

    if oc get subscription web-terminal -n openshift-operators &>/dev/null; then
        local phase
        phase=$(oc get csv -n openshift-operators -l operators.coreos.com/web-terminal.openshift-operators 2>/dev/null \
            | grep -v NAME | awk '{print $NF}' | head -1)
        if [ "$phase" = "Succeeded" ]; then
            print_success "Web Terminal operator already installed"
            return 0
        fi
        print_step "Subscription exists, waiting for CSV..."
    else
        print_step "Creating Web Terminal subscription..."
        oc apply -f "$ROOT_DIR/lib/manifests/operators/web-terminal-subscription.yaml"
        print_success "Subscription created"
    fi

    print_step "Waiting for Web Terminal operator to become ready..."
    local timeout=180 elapsed=0
    local approval_done=false
    while [ $elapsed -lt $timeout ]; do
        local phase
        phase=$(oc get csv -n openshift-operators 2>/dev/null \
            | grep web-terminal | awk '{print $NF}' | head -1)
        if [ "$phase" = "Succeeded" ]; then
            print_success "Web Terminal operator ready"
            print_info "Participants can use the >_ icon in the OpenShift console masthead"
            return 0
        fi

        if [ "$approval_done" = "false" ]; then
            local plan_name
            plan_name=$(oc get subscription web-terminal -n openshift-operators \
                -o jsonpath='{.status.installPlanRef.name}' 2>/dev/null)
            if [ -n "$plan_name" ]; then
                local plan_approved
                plan_approved=$(oc get installplan "$plan_name" -n openshift-operators \
                    -o jsonpath='{.spec.approved}' 2>/dev/null)
                if [ "$plan_approved" = "false" ]; then
                    print_step "Approving pending InstallPlan ($plan_name)..."
                    oc patch installplan "$plan_name" -n openshift-operators \
                        --type merge -p '{"spec":{"approved":true}}' 2>/dev/null
                    print_success "InstallPlan approved"
                fi
                approval_done=true
            fi
        fi

        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting... (${elapsed}s)"
    done

    print_warning "Web Terminal operator not ready after ${timeout}s (may still be installing)"
}

disable_vllm_on_maas() {
    print_header "Disabling vLLM on MaaS (Tech Preview)"

    local current
    current=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.vLLMDeploymentOnMaaS}' 2>/dev/null)

    if [ "$current" = "false" ]; then
        print_success "vLLM on MaaS is already disabled"
        return 0
    fi

    print_step "Patching OdhDashboardConfig..."
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        --type merge -p '{"spec":{"dashboardConfig":{"vLLMDeploymentOnMaaS":false}}}' 2>&1

    if [ $? -eq 0 ]; then
        print_success "vLLM on MaaS disabled"
        print_info "Dashboard will no longer show vLLM as a MaaS-compatible runtime"
    else
        print_error "Failed to patch OdhDashboardConfig"
        return 1
    fi
}

run_complete_workshop_setup() {
    local user_count="${1:-150}"
    local gpu_instance="${2:-g6e.xlarge}"
    local gpu_count="${3:-64}"
    local worker_count="${4:-12}"

    print_header "Complete Workshop Setup (RHOAI 3.4 + OpenWebUI)"

    echo -e "${YELLOW}This will set up a complete workshop environment:${NC}"
    echo "  • RHOAI 3.4 installation"
    echo "  • Web Terminal operator (in-browser terminal for participants)"
    echo "  • Disable vLLM on MaaS tech preview"
    echo "  • GPU hardware profile"
    echo "  • User Workload Monitoring (Prometheus)"
    echo "  • GPU MachineSet ($gpu_count x $gpu_instance)"
    echo "  • Worker nodes ($worker_count)"
    echo "  • Workshop users ($user_count users)"
    echo "  • Grafana with dashboards"
    echo "  • Admin model (qwen3-4b with tool calling) + Kubernetes MCP Server"
    echo "  • LlamaStack operator (participants deploy in their namespaces)"
    echo ""
    echo -e "${CYAN}Participants will deploy LlamaStack + OpenWebUI in their own namespaces.${NC}"
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled"
        return 0
    fi

    print_header "Step 1/9: Installing RHOAI 3.4"
    "$ROOT_DIR/scripts/install-rhoai-34.sh" --skip-admin-user --setup-users --num-users "$user_count"

    print_header "Step 2/10: Installing Web Terminal"
    install_web_terminal

    print_header "Step 3/10: Disabling vLLM on MaaS Tech Preview"
    disable_vllm_on_maas

    print_header "Step 4/10: Creating GPU Hardware Profile"
    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/hardware-profile-gpu.yaml"
    print_success "GPU hardware profile created"

    print_header "Step 5/10: Enabling User Workload Monitoring"
    setup_user_workload_monitoring

    print_header "Step 6/10: Creating GPU MachineSet"
    create_gpu_machineset_for_workshop "$gpu_instance" "$gpu_count"

    print_header "Step 7/10: Scaling Worker Nodes"
    scale_worker_nodes "$worker_count"

    print_header "Step 8/10: Setting Up Workshop Users"
    setup_workshop_users "$user_count"

    print_header "Step 9/10: Setting Up Grafana"
    setup_workshop_grafana

    print_header "Step 10/10: Deploying Model and MCP Server"
    echo -e "${YELLOW}Note: Model deployment requires GPU nodes to be ready.${NC}"
    echo "Checking GPU node status..."
    local gpu_ready
    gpu_ready=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)
    if [ "$gpu_ready" -gt 0 ]; then
        setup_workshop_model_and_mcp
    else
        print_warning "No GPU nodes ready yet. Run 'Deploy Admin Model and MCP Server' later."
    fi

    local cluster_domain
    cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

    echo ""
    print_header "Workshop Setup Complete!"
    echo ""
    echo -e "${GREEN}Cluster Domain:${NC} $cluster_domain"
    echo -e "${GREEN}Users:${NC} user1 to user$user_count (password: openshift)"
    echo -e "${GREEN}GPU Nodes:${NC} $gpu_count x $gpu_instance (may still be provisioning)"
    echo -e "${GREEN}Worker Nodes:${NC} $worker_count"
    echo ""
    local dashboard_url
    if type get_dashboard_url &>/dev/null; then
      dashboard_url=$(get_dashboard_url)
    else
      dashboard_url="https://rh-ai.apps.$(oc get ingress.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null)"
    fi

    echo -e "${CYAN}URLs:${NC}"
    echo "  Console: https://console-openshift-console.${cluster_domain}"
    echo "  RHOAI: $dashboard_url"
    echo "  Grafana: https://grafana-grafana.${cluster_domain}"
    echo "  Model: https://qwen3-4b-admin-workshop.${cluster_domain}/v1"
    echo "  MCP: http://kubernetes-mcp-server.admin-workshop.svc.cluster.local:8080/mcp"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Wait for GPU nodes: oc get nodes -l nvidia.com/gpu.present=true -w"
    echo "2. If model not deployed, run option 4 from Workshop Setup menu"
    echo "3. Share the workshop guide with participants"
    echo ""
}

create_gpu_machineset_for_workshop() {
    local gpu_instance="${1:-g6e.xlarge}"
    local gpu_count="${2:-64}"
    
    local infra_id region az ami_id
    infra_id=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
    region=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.aws.region}')
    az="${region}c"
    ami_id=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.ami.id}')
    
    local vcpu mem
    case "$gpu_instance" in
        g6e.xlarge)  vcpu=4;  mem=32768 ;;
        g6e.2xlarge) vcpu=8;  mem=65536 ;;
        g6.xlarge)   vcpu=4;  mem=16384 ;;
        g6.2xlarge)  vcpu=8;  mem=32768 ;;
        *)           vcpu=4;  mem=32768 ;;
    esac
    
    print_step "Creating GPU MachineSet: $gpu_count x $gpu_instance"
    
    export INFRA_ID="$infra_id" REGION="$region" AZ="$az" AMI_ID="$ami_id"
    export GPU_INSTANCE="$gpu_instance" GPU_COUNT="$gpu_count" VCPU="$vcpu" MEM="$mem"
    envsubst < "$ROOT_DIR/lib/manifests/workshop/gpu-machineset.yaml" | oc apply -f -
    unset INFRA_ID REGION AZ AMI_ID GPU_INSTANCE GPU_COUNT VCPU MEM
    
    print_success "GPU MachineSet created: $gpu_count x $gpu_instance"
}

scale_worker_nodes() {
    local worker_count="${1:-12}"
    
    local worker_ms
    worker_ms=$(oc get machineset -n openshift-machine-api -o name | grep -v gpu | head -1)
    
    if [ -n "$worker_ms" ]; then
        print_step "Scaling worker nodes to $worker_count..."
        oc scale "$worker_ms" -n openshift-machine-api --replicas="$worker_count"
        print_success "Worker nodes scaled to $worker_count"
    else
        print_warning "No worker MachineSet found"
    fi
}
