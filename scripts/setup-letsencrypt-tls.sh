#!/bin/bash
################################################################################
# TLS Certificate Setup for OpenShift AI
#
# Standalone script to configure TLS certificates for:
#   - OpenShift Ingress Router (default wildcard cert)
#   - Gateway API (maas-default-gateway, openshift-ai-inference)
#   - KServe/Knative (inference serving certs)
#
# Supports:
#   - Let's Encrypt via cert-manager + Route53 DNS-01
#   - Self-signed wildcard certificates via OpenSSL
#
# Prerequisites: cert-manager operator installed, oc logged in
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFESTS_DIR="$ROOT_DIR/lib/manifests/tls"

# Source utilities
if [ -f "$ROOT_DIR/lib/utils/colors.sh" ]; then
    source "$ROOT_DIR/lib/utils/colors.sh"
fi

# Fallback print functions
if ! type print_header &>/dev/null; then
    print_header()  { echo ""; echo "=== $1 ==="; echo ""; }
    print_step()    { echo "▶ $1"; }
    print_success() { echo "✓ $1"; }
    print_error()   { echo "✗ $1"; }
    print_warning() { echo "⚠ $1"; }
    print_info()    { echo "ℹ $1"; }
fi

GATEWAY_NS="openshift-ingress"
CERT_SECRET_NAME="apps-wildcard-tls"

################################################################################
# Utility functions
################################################################################

get_cluster_domain() {
    if [ -z "${CLUSTER_DOMAIN:-}" ]; then
        CLUSTER_DOMAIN=$(oc get ingress.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    fi
    if [ -z "$CLUSTER_DOMAIN" ]; then
        print_error "Could not detect cluster domain"
        return 1
    fi
    # Strip leading "apps." if present (base domain needed for some operations)
    CLUSTER_BASE_DOMAIN="${CLUSTER_DOMAIN#apps.}"
    export CLUSTER_DOMAIN CLUSTER_BASE_DOMAIN
}

get_aws_region() {
    if [ -z "${AWS_REGION:-}" ]; then
        AWS_REGION=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.aws.region}' 2>/dev/null)
    fi
    if [ -z "${AWS_REGION:-}" ]; then
        AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-2")
    fi
    export AWS_REGION
}

detect_public_hosted_zone() {
    print_step "Detecting public Route53 hosted zone..."

    local base_domain="$CLUSTER_BASE_DOMAIN"
    local zone_id=""

    while [ -n "$base_domain" ] && [ "$base_domain" != "${base_domain#*.}" -o -z "$zone_id" ]; do
        zone_id=$(aws route53 list-hosted-zones --output json 2>/dev/null | \
            python3 -c "
import json, sys
data = json.load(sys.stdin)
for z in data.get('HostedZones', []):
    if z['Name'].rstrip('.') == '${base_domain}' and not z['Config'].get('PrivateZone', False):
        print(z['Id'].split('/')[-1])
        break
" 2>/dev/null)

        if [ -n "$zone_id" ]; then
            break
        fi
        base_domain="${base_domain#*.}"
    done

    if [ -z "$zone_id" ]; then
        print_warning "Could not auto-detect public hosted zone. Listing available zones:"
        aws route53 list-hosted-zones --output json 2>/dev/null | \
            python3 -c "
import json, sys
data = json.load(sys.stdin)
for z in data.get('HostedZones', []):
    priv = '(private)' if z['Config'].get('PrivateZone', False) else '(public)'
    zid = z['Id'].split('/')[-1]
    print(f'  {zid}  {z[\"Name\"]}  {priv}')
" 2>/dev/null
        echo ""
        echo -n -e "${BLUE}Enter the PUBLIC hosted zone ID: ${NC}"
        read -r zone_id
    fi

    if [ -z "$zone_id" ]; then
        print_error "Route53 public hosted zone ID is required"
        return 1
    fi

    export ROUTE53_HOSTED_ZONE_ID="$zone_id"
    print_success "Using public hosted zone: $ROUTE53_HOSTED_ZONE_ID (${base_domain})"
}

configure_certmanager_dns_resolvers() {
    print_step "Configuring cert-manager to use public DNS resolvers..."

    local current_args=$(oc get certmanager cluster -o jsonpath='{.spec.controllerConfig.overrideArgs}' 2>/dev/null)
    if echo "$current_args" | grep -q "dns01-recursive-nameservers" 2>/dev/null; then
        print_info "cert-manager already configured with recursive DNS resolvers"
        return 0
    fi

    oc patch certmanager cluster --type=merge -p '{
      "spec": {
        "controllerConfig": {
          "overrideArgs": [
            "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
            "--dns01-recursive-nameservers-only=true"
          ]
        }
      }
    }' 2>/dev/null

    print_success "cert-manager configured to use Google/Cloudflare public DNS"
    print_info "Waiting for cert-manager controller to restart..."
    sleep 10

    local cm_timeout=60
    local cm_elapsed=0
    while [ $cm_elapsed -lt $cm_timeout ]; do
        if oc get pods -n cert-manager -l app=cert-manager --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
            print_success "cert-manager controller restarted"
            return 0
        fi
        sleep 5
        cm_elapsed=$((cm_elapsed + 5))
        echo -n "."
    done
    echo ""
    print_warning "cert-manager controller restart may still be in progress"
}

check_certmanager() {
    if oc get csv -A 2>/dev/null | grep -q "cert-manager.*Succeeded"; then
        print_success "cert-manager operator is installed"
        return 0
    fi

    # Also check if cert-manager pods are running (installed via non-OLM method)
    if oc get pods -n cert-manager 2>/dev/null | grep -q "cert-manager.*Running"; then
        print_success "cert-manager is running"
        return 0
    fi

    print_warning "cert-manager operator is not installed."
    echo -n -e "${YELLOW}Install cert-manager now? [Y/n]: ${NC}"
    read -r install_cm
    if [[ "${install_cm:-y}" =~ ^[Nn]$ ]]; then
        print_error "cert-manager is required for TLS certificate management"
        return 1
    fi

    install_certmanager_operator
}

install_certmanager_operator() {
    print_step "Installing cert-manager Operator..."

    oc create namespace cert-manager-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n cert-manager-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        oc delete operatorgroup --all -n cert-manager-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-subscription.yaml"

    print_step "Waiting for cert-manager operator to be ready..."
    local timeout=180
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        # Auto-approve pending InstallPlans
        for plan in $(oc get installplan -n cert-manager-operator -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null); do
            oc patch installplan "$plan" -n cert-manager-operator --type=merge -p '{"spec":{"approved":true}}' 2>/dev/null || true
        done

        if oc get csv -n cert-manager-operator 2>/dev/null | grep -q "cert-manager-operator.*Succeeded"; then
            print_success "cert-manager operator installed successfully"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done
    echo ""
    print_error "cert-manager operator did not become ready within ${timeout}s"
    return 1
}

################################################################################
# Let's Encrypt setup
################################################################################

setup_letsencrypt() {
    print_header "Let's Encrypt TLS Certificate Setup (Route53 DNS-01)"

    check_certmanager || return 1
    get_cluster_domain || return 1
    get_aws_region

    echo -e "${CYAN}Cluster domain:${NC} $CLUSTER_DOMAIN"
    echo -e "${CYAN}AWS region:${NC}     $AWS_REGION"
    echo ""

    # Step 1: Collect AWS credentials
    print_step "Step 1: AWS credentials for Route53 DNS-01 challenge"
    echo ""

    local aws_key_id="${AWS_ACCESS_KEY_ID:-}"
    local aws_secret="${AWS_SECRET_ACCESS_KEY:-}"

    if [ -z "$aws_key_id" ] && [ -f "$HOME/.aws/credentials" ]; then
        aws_key_id=$(grep -A2 '\[default\]' "$HOME/.aws/credentials" 2>/dev/null | grep aws_access_key_id | awk -F= '{print $2}' | tr -d ' ')
        aws_secret=$(grep -A2 '\[default\]' "$HOME/.aws/credentials" 2>/dev/null | grep aws_secret_access_key | awk -F= '{print $2}' | tr -d ' ')
    fi

    if [ -n "$aws_key_id" ]; then
        print_info "Found AWS credentials (key: ${aws_key_id:0:8}...)"
        echo -n -e "${YELLOW}Use these credentials? [Y/n]: ${NC}"
        read -r use_existing
        if [[ "${use_existing:-y}" =~ ^[Nn]$ ]]; then
            aws_key_id=""
            aws_secret=""
        fi
    fi

    if [ -z "$aws_key_id" ]; then
        echo -n -e "${BLUE}AWS Access Key ID: ${NC}"
        read -r aws_key_id
        echo -n -e "${BLUE}AWS Secret Access Key: ${NC}"
        read -rs aws_secret
        echo ""
    fi

    if [ -z "$aws_key_id" ] || [ -z "$aws_secret" ]; then
        print_error "AWS credentials are required for Route53 DNS-01 challenge"
        return 1
    fi

    export AWS_ACCESS_KEY_ID="$aws_key_id"
    export AWS_SECRET_ACCESS_KEY="$aws_secret"

    # Step 2: Detect public Route53 hosted zone
    detect_public_hosted_zone || return 1

    # Step 3: Choose ACME environment
    print_step "Step 3: ACME environment"
    echo ""
    echo "  1) Production (real trusted certificates)"
    echo "  2) Staging (test certificates, higher rate limits)"
    echo ""
    echo -n -e "${YELLOW}Select [1]: ${NC}"
    read -r acme_choice

    if [ "${acme_choice:-1}" = "2" ]; then
        export ACME_ENV="staging"
        export ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
        print_info "Using Let's Encrypt STAGING (certificates will NOT be trusted by browsers)"
    else
        export ACME_ENV="prod"
        export ACME_SERVER="https://acme-v02.api.letsencrypt.org/directory"
        print_info "Using Let's Encrypt PRODUCTION"
    fi

    # Step 4: ACME email
    echo ""
    echo -n -e "${BLUE}ACME contact email [admin@${CLUSTER_BASE_DOMAIN}]: ${NC}"
    read -r acme_email
    export ACME_EMAIL="${acme_email:-admin@${CLUSTER_BASE_DOMAIN}}"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo "  Domain:      *.${CLUSTER_DOMAIN}"
    echo "  ACME Server: ${ACME_ENV}"
    echo "  Email:       ${ACME_EMAIL}"
    echo "  AWS Key:     ${AWS_ACCESS_KEY_ID:0:8}..."
    echo "  AWS Region:  ${AWS_REGION}"
    echo "  Zone ID:     ${ROUTE53_HOSTED_ZONE_ID}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n -e "${YELLOW}Proceed? [Y/n]: ${NC}"
    read -r confirm
    if [[ "${confirm:-y}" =~ ^[Nn]$ ]]; then
        print_warning "Cancelled"
        return 0
    fi

    echo ""

    # Step 5: Configure cert-manager DNS resolvers (prevents private zone NS issues)
    configure_certmanager_dns_resolvers

    # Step 6: Create Route53 credentials secret
    print_step "Creating Route53 credentials secret in cert-manager namespace..."
    local cm_ns="cert-manager"
    if ! oc get namespace "$cm_ns" &>/dev/null; then
        cm_ns="cert-manager-operator"
    fi

    oc create secret generic route53-credentials \
        -n "$cm_ns" \
        --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "Route53 credentials secret created in $cm_ns"

    # Step 7: Create ClusterIssuer
    print_step "Creating ClusterIssuer (letsencrypt-${ACME_ENV})..."
    envsubst < "$MANIFESTS_DIR/letsencrypt-clusterissuer.yaml.tmpl" | oc apply -f -
    print_success "ClusterIssuer created"

    # Step 8: Wait for ClusterIssuer to be ready
    print_step "Waiting for ClusterIssuer to be ready..."
    local ci_timeout=60
    local ci_elapsed=0
    while [ $ci_elapsed -lt $ci_timeout ]; do
        local ci_ready=$(oc get clusterissuer "letsencrypt-${ACME_ENV}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$ci_ready" = "True" ]; then
            print_success "ClusterIssuer is ready"
            break
        fi
        sleep 5
        ci_elapsed=$((ci_elapsed + 5))
        echo -n "."
    done
    if [ $ci_elapsed -ge $ci_timeout ]; then
        print_warning "ClusterIssuer not ready yet - check: oc describe clusterissuer letsencrypt-${ACME_ENV}"
    fi

    # Step 9: Create wildcard Certificate
    print_step "Creating wildcard Certificate (*.${CLUSTER_DOMAIN})..."
    envsubst < "$MANIFESTS_DIR/wildcard-certificate.yaml.tmpl" | oc apply -f -
    print_success "Certificate CR created"

    # Step 10: Wait for certificate to be issued
    print_step "Waiting for certificate to be issued (DNS-01 challenge, may take 1-3 minutes)..."
    local cert_timeout=300
    local cert_elapsed=0
    while [ $cert_elapsed -lt $cert_timeout ]; do
        local cert_ready=$(oc get certificate apps-wildcard-cert -n "$GATEWAY_NS" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$cert_ready" = "True" ]; then
            echo ""
            print_success "Certificate issued successfully!"
            break
        fi
        sleep 10
        cert_elapsed=$((cert_elapsed + 10))
        echo -n "."
    done
    echo ""
    if [ $cert_elapsed -ge $cert_timeout ]; then
        print_warning "Certificate not ready within ${cert_timeout}s"
        print_info "Check status: oc describe certificate apps-wildcard-cert -n $GATEWAY_NS"
        print_info "Check challenge: oc get challenges -A"
        print_info "The certificate may still be issuing. You can apply it later with option 3."
        return 1
    fi

    # Step 11: Apply to targets
    apply_cert_to_targets

    echo ""
    print_success "Let's Encrypt TLS setup complete!"
    echo ""
    show_tls_status
}

################################################################################
# Self-signed certificate setup
################################################################################

setup_selfsigned() {
    print_header "Self-signed Wildcard Certificate Setup"

    get_cluster_domain || return 1

    echo -e "${CYAN}Cluster domain:${NC} $CLUSTER_DOMAIN"
    echo ""
    print_info "This creates a self-signed wildcard certificate for *.${CLUSTER_DOMAIN}"
    print_warning "Browsers will show security warnings with self-signed certificates."
    echo ""
    echo -n -e "${YELLOW}Continue? [Y/n]: ${NC}"
    read -r confirm
    if [[ "${confirm:-y}" =~ ^[Nn]$ ]]; then
        return 0
    fi

    echo ""

    local tmpdir
    tmpdir=$(mktemp -d)

    print_step "Generating self-signed wildcard certificate..."
    cat > "$tmpdir/openssl.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext
x509_extensions = v3_ext

[dn]
CN = *.${CLUSTER_DOMAIN}

[req_ext]
subjectAltName = @alt_names

[v3_ext]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment

[alt_names]
DNS.1 = *.${CLUSTER_DOMAIN}
DNS.2 = ${CLUSTER_DOMAIN}
EOF

    openssl req -x509 -newkey rsa:2048 \
        -keyout "$tmpdir/tls.key" \
        -out "$tmpdir/tls.crt" \
        -days 365 -nodes \
        -config "$tmpdir/openssl.cnf" 2>/dev/null

    print_success "Certificate generated (valid for 365 days)"

    # Create/update the secret
    print_step "Creating TLS secret ($CERT_SECRET_NAME) in $GATEWAY_NS..."
    oc create secret tls "$CERT_SECRET_NAME" \
        -n "$GATEWAY_NS" \
        --cert="$tmpdir/tls.crt" \
        --key="$tmpdir/tls.key" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "TLS secret created"

    # Also create default-gateway-tls if it doesn't exist
    if ! oc get secret default-gateway-tls -n "$GATEWAY_NS" &>/dev/null; then
        print_step "Creating default-gateway-tls secret..."
        oc create secret tls default-gateway-tls \
            -n "$GATEWAY_NS" \
            --cert="$tmpdir/tls.crt" \
            --key="$tmpdir/tls.key" \
            --dry-run=client -o yaml | oc apply -f -
        print_success "default-gateway-tls secret created"
    fi

    rm -rf "$tmpdir"

    # Apply to targets
    apply_cert_to_targets

    echo ""
    print_success "Self-signed TLS setup complete!"
    echo ""
    show_tls_status
}

################################################################################
# Apply certificate to targets
################################################################################

apply_cert_to_targets() {
    echo ""
    print_header "Applying Certificate to Targets"

    # 1. Gateway TLS
    print_step "Applying to Gateway API resources..."

    for gw_name in maas-default-gateway openshift-ai-inference; do
        if oc get gateway "$gw_name" -n "$GATEWAY_NS" &>/dev/null; then
            local listener_count=$(oc get gateway "$gw_name" -n "$GATEWAY_NS" \
                -o jsonpath='{range .spec.listeners[*]}{.name}{"\n"}{end}' 2>/dev/null | wc -l | tr -d ' ')
            local patch_ops="["
            for ((idx=0; idx<listener_count; idx++)); do
                [ $idx -gt 0 ] && patch_ops+=","
                patch_ops+="{\"op\":\"replace\",\"path\":\"/spec/listeners/$idx/tls/certificateRefs/0/name\",\"value\":\"$CERT_SECRET_NAME\"}"
            done
            patch_ops+="]"
            oc patch gateway "$gw_name" -n "$GATEWAY_NS" --type=json -p "$patch_ops" 2>/dev/null \
                && print_success "  $gw_name: updated $listener_count listener(s)" \
                || print_warning "  Could not patch $gw_name"
        else
            print_info "  $gw_name not found (skipping)"
        fi
    done

    # 2. Ingress Router
    print_step "Applying to OpenShift Ingress Router..."
    if oc get secret "$CERT_SECRET_NAME" -n "$GATEWAY_NS" &>/dev/null; then
        oc patch ingresscontroller default -n openshift-ingress-operator \
            --type=merge -p "{\"spec\":{\"defaultCertificate\":{\"name\":\"$CERT_SECRET_NAME\"}}}" 2>/dev/null \
            && print_success "  IngressController defaultCertificate updated" \
            || print_warning "  Could not patch IngressController"
    fi

    # 3. KServe/Knative
    print_step "Applying to KServe/Knative..."
    local dsc_name=$(oc get datasciencecluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$dsc_name" ]; then
        oc patch datasciencecluster "$dsc_name" --type=merge \
            -p '{"spec":{"components":{"kserve":{"serving":{"ingressGateway":{"certificate":{"type":"Provided"}}}}}}}' 2>/dev/null \
            && print_success "  DataScienceCluster certificate type set to Provided" \
            || print_warning "  Could not patch DataScienceCluster"
    else
        print_info "  DataScienceCluster not found (skipping)"
    fi
}

################################################################################
# Show TLS status
################################################################################

show_tls_status() {
    print_header "TLS Certificate Status"

    get_cluster_domain 2>/dev/null

    # ClusterIssuers
    echo -e "${CYAN}ClusterIssuers:${NC}"
    local issuers=$(oc get clusterissuer --no-headers 2>/dev/null)
    if [ -n "$issuers" ]; then
        echo "$issuers" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  (none)"
    fi
    echo ""

    # Certificates in openshift-ingress
    echo -e "${CYAN}Certificates (openshift-ingress):${NC}"
    local certs=$(oc get certificate -n "$GATEWAY_NS" --no-headers 2>/dev/null)
    if [ -n "$certs" ]; then
        echo "$certs" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  (none - using manual secrets)"
    fi
    echo ""

    # TLS Secrets
    echo -e "${CYAN}TLS Secrets (openshift-ingress):${NC}"
    for secret_name in apps-wildcard-tls default-gateway-tls; do
        if oc get secret "$secret_name" -n "$GATEWAY_NS" &>/dev/null; then
            local not_after=$(oc get secret "$secret_name" -n "$GATEWAY_NS" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
            echo -e "  ${GREEN}$secret_name${NC}: exists (expires: ${not_after:-unknown})"
        else
            echo -e "  ${YELLOW}$secret_name${NC}: not found"
        fi
    done
    echo ""

    # Ingress Router default cert
    echo -e "${CYAN}Ingress Router Default Certificate:${NC}"
    local ingress_cert=$(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
    if [ -n "$ingress_cert" ]; then
        echo "  Using: $ingress_cert"
    else
        echo "  Using: cluster default (self-signed)"
    fi
    echo ""

    # Gateway TLS refs
    echo -e "${CYAN}Gateway Certificate References:${NC}"
    for gw_name in maas-default-gateway openshift-ai-inference; do
        local cert_ref=$(oc get gateway "$gw_name" -n "$GATEWAY_NS" -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}' 2>/dev/null)
        if [ -n "$cert_ref" ]; then
            echo "  $gw_name: $cert_ref"
        else
            echo "  $gw_name: (not found)"
        fi
    done
    echo ""

    # KServe certificate type
    echo -e "${CYAN}KServe Certificate Type:${NC}"
    local dsc_name=$(oc get datasciencecluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$dsc_name" ]; then
        local cert_type=$(oc get datasciencecluster "$dsc_name" -o jsonpath='{.spec.components.kserve.serving.ingressGateway.certificate.type}' 2>/dev/null)
        echo "  ${cert_type:-SelfSigned (default)}"
    else
        echo "  DataScienceCluster not found"
    fi
    echo ""
}

################################################################################
# Revert to defaults
################################################################################

revert_to_default() {
    print_header "Revert TLS to Cluster Defaults"

    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Remove IngressController custom certificate setting"
    echo "  2. Revert Gateway TLS to default-gateway-tls"
    echo "  3. Revert KServe to SelfSigned certificate type"
    echo "  4. Delete Let's Encrypt resources (ClusterIssuer, Certificate)"
    echo ""
    echo -n -e "${RED}Are you sure? [y/N]: ${NC}"
    read -r confirm
    if [[ ! "${confirm:-n}" =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        return 0
    fi

    echo ""

    # Revert IngressController
    print_step "Reverting IngressController..."
    oc patch ingresscontroller default -n openshift-ingress-operator \
        --type=json -p '[{"op":"remove","path":"/spec/defaultCertificate"}]' 2>/dev/null \
        && print_success "IngressController reverted" \
        || print_info "No custom certificate was set"

    # Revert Gateways to default-gateway-tls
    for gw_name in maas-default-gateway openshift-ai-inference; do
        if oc get gateway "$gw_name" -n "$GATEWAY_NS" &>/dev/null; then
            oc patch gateway "$gw_name" -n "$GATEWAY_NS" --type=json \
                -p '[{"op":"replace","path":"/spec/listeners/0/tls/certificateRefs/0/name","value":"default-gateway-tls"}]' 2>/dev/null \
                && print_success "  $gw_name reverted to default-gateway-tls" \
                || print_warning "  Could not patch $gw_name"
        fi
    done

    # Revert KServe
    local dsc_name=$(oc get datasciencecluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$dsc_name" ]; then
        oc patch datasciencecluster "$dsc_name" --type=merge \
            -p '{"spec":{"components":{"kserve":{"serving":{"ingressGateway":{"certificate":{"type":"SelfSigned"}}}}}}}' 2>/dev/null \
            && print_success "KServe reverted to SelfSigned" \
            || print_warning "Could not patch DataScienceCluster"
    fi

    # Delete LE resources
    for env in prod staging; do
        if oc get clusterissuer "letsencrypt-$env" &>/dev/null; then
            print_step "Deleting ClusterIssuer letsencrypt-$env..."
            oc delete clusterissuer "letsencrypt-$env" 2>/dev/null || true
        fi
    done
    if oc get certificate apps-wildcard-cert -n "$GATEWAY_NS" &>/dev/null; then
        print_step "Deleting Certificate apps-wildcard-cert..."
        oc delete certificate apps-wildcard-cert -n "$GATEWAY_NS" 2>/dev/null || true
    fi

    echo ""
    print_success "Reverted to cluster defaults"
}

################################################################################
# Interactive menu
################################################################################

show_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              TLS Certificate Setup                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Let's Encrypt (Route53 DNS-01) ${GREEN}[Recommended]${NC}"
    echo "    Trusted wildcard certificate via ACME + AWS Route53"
    echo -e "${YELLOW}2)${NC} Self-signed Certificate (OpenSSL)"
    echo "    Quick setup, but browsers will show warnings"
    echo -e "${YELLOW}3)${NC} Show TLS Status"
    echo "    Display current certificate configuration"
    echo -e "${YELLOW}4)${NC} Revert to Defaults"
    echo "    Remove custom certificates, restore cluster defaults"
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

run_interactive() {
    while true; do
        show_menu
        echo -n -e "${YELLOW}Select an option (1-4, 0): ${NC}"
        read -r choice

        case $choice in
            1)
                setup_letsencrypt
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                setup_selfsigned
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                show_tls_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                revert_to_default
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|q|Q)
                return 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# CLI mode
################################################################################

usage() {
    echo "Usage: $(basename "$0") [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  letsencrypt    Setup Let's Encrypt certificate (Route53 DNS-01)"
    echo "  selfsigned     Setup self-signed wildcard certificate"
    echo "  status         Show current TLS configuration"
    echo "  revert         Revert to cluster defaults"
    echo "  (none)         Interactive menu"
    echo ""
    echo "Options:"
    echo "  --email EMAIL  ACME contact email (letsencrypt only)"
    echo "  --staging      Use Let's Encrypt staging server"
    echo "  -h, --help     Show this help"
}

# Main entry point
case "${1:-}" in
    letsencrypt|le)
        shift
        while [[ $# -gt 0 ]]; do
            case $1 in
                --email) export ACME_EMAIL="$2"; shift 2 ;;
                --staging) export ACME_ENV="staging"; export ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"; shift ;;
                *) shift ;;
            esac
        done
        setup_letsencrypt
        ;;
    selfsigned|self-signed)
        setup_selfsigned
        ;;
    status)
        show_tls_status
        ;;
    revert)
        revert_to_default
        ;;
    -h|--help)
        usage
        ;;
    "")
        run_interactive
        ;;
    *)
        print_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
