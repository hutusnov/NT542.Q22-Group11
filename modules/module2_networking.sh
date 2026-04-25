#!/usr/bin/env bash
# =============================================================================
# modules/module2_networking.sh
# CIS GKE Autopilot Benchmark v1.3.0
# Module 2: Networking & CNI
# Kiểm tra: 4.3.1 | 5.4.1 | 5.4.2 | 5.4.3 | 5.4.4 | 5.4.5
# =============================================================================

if ! declare -f log_info > /dev/null 2>&1; then
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_dir}/../utils/logger.sh" 2>/dev/null || source ./utils/logger.sh
fi

log_header "$(mod_header M2)"

log_info "$(t LOADING_CLUSTER)"
CLUSTER_DATA=$(gcloud container clusters describe "$CLUSTER_NAME" \
    --location "$LOCATION" \
    --project  "$PROJECT_ID" \
    --format   json 2>/dev/null)

if [[ -z "$CLUSTER_DATA" ]]; then
    log_error "$(t LOAD_FAIL)"
    record_result "5.4.x" "$(mod_header M2)" "FAIL" "$(t LOAD_FAIL)"
    return 1 2>/dev/null || exit 1
fi
log_pass "$(t LOAD_OK)"
echo ""

# =============================================================================
# CIS 4.3.1 — All Namespaces have Network Policies defined
# =============================================================================
audit_4_3_1() {
    log_subheader "$(cis_title 4_3_1)"

    local all_ns
    all_ns=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n')

    local total=0 covered=0 missing=()
    while IFS= read -r ns; do
        [[ -z "$ns" ]] && continue
        ((total++))
        local np_count
        np_count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$np_count" -gt 0 ]]; then
            ((covered++))
        else
            missing+=("$ns")
        fi
    done <<< "$all_ns"

    echo ""
    printf "  %-12s %-12s %-12s\n" "Total NS" "Has NetPol" "Missing"
    printf "  %-12s %-12s %-12s\n" "────────" "────────" "────────"
    printf "  %-12s %-12s %-12s\n" "$total" "$covered" "${#missing[@]}"
    echo ""

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_pass "All $total namespaces have Network Policy defined."
        record_result "4.3.1" "$(cis_title 4_3_1)" "PASS" "$covered/$total namespaces have NetworkPolicy"
    else
        log_fail "Namespaces without Network Policy (${#missing[@]}):"
        for ns in "${missing[@]}"; do log_fail "  - $ns"; done
        echo ""
        log_info "$(t REMEDIATION)"
        cat << 'EOF'
    kubectl apply -f - <<YAML
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: default-deny-all
      namespace: <NAMESPACE>
    spec:
      podSelector: {}
      policyTypes: [Ingress, Egress]
    YAML
EOF
        record_result "4.3.1" "$(cis_title 4_3_1)" "FAIL" "${#missing[@]}/$total namespaces missing NetworkPolicy: ${missing[*]}"
    fi
    echo ""
}

# =============================================================================
# CIS 5.4.1 — Enable VPC Flow Logs and Intranode Visibility
# =============================================================================
audit_5_4_1() {
    log_subheader "$(cis_title 5_4_1)"

    local intranode
    intranode=$(echo "$CLUSTER_DATA" | jq -r '.networkConfig.enableIntraNodeVisibility // false')

    if [[ "$intranode" == "true" ]]; then
        log_pass "Intranode Visibility (VPC Flow Logs) is ENABLED."
        record_result "5.4.1" "$(cis_title 5_4_1)" "PASS" "networkConfig.enableIntraNodeVisibility = true"
    else
        log_fail "Intranode Visibility is DISABLED — pod-to-pod traffic is not logged."
        log_info  "$(t REMEDIATION) gcloud container clusters update $CLUSTER_NAME --enable-intra-node-visibility --location=$LOCATION"
        record_result "5.4.1" "$(cis_title 5_4_1)" "FAIL" "networkConfig.enableIntraNodeVisibility = false"
    fi
    echo ""
}

# =============================================================================
# CIS 5.4.2 — Ensure Control Plane Authorized Networks is Enabled
# =============================================================================
audit_5_4_2() {
    log_subheader "$(cis_title 5_4_2)"

    local auth_nets_enabled cidr_count
    auth_nets_enabled=$(echo "$CLUSTER_DATA" | jq -r '.masterAuthorizedNetworksConfig.enabled // false')
    cidr_count=$(echo "$CLUSTER_DATA" | jq '.masterAuthorizedNetworksConfig.cidrBlocks | length // 0')

    if [[ "$auth_nets_enabled" == "true" ]]; then
        log_pass "Control Plane Authorized Networks is ENABLED ($cidr_count CIDR block(s))."
        local cidrs
        cidrs=$(echo "$CLUSTER_DATA" | jq -r '.masterAuthorizedNetworksConfig.cidrBlocks[]? | "    \(.displayName // "N/A"): \(.cidrBlock)"')
        [[ -n "$cidrs" ]] && echo "$cidrs"
        record_result "5.4.2" "$(cis_title 5_4_2)" "PASS" "Enabled with $cidr_count CIDR block(s)"
    else
        log_fail "Control Plane Authorized Networks is DISABLED — Control Plane accessible from any IP!"
        record_result "5.4.2" "$(cis_title 5_4_2)" "FAIL" "masterAuthorizedNetworksConfig.enabled = false"
    fi
    echo ""
}

# =============================================================================
# CIS 5.4.3 — Private Endpoint Enabled & Public Access Disabled
# =============================================================================
audit_5_4_3() {
    log_subheader "$(cis_title 5_4_3)"

    local private_ep
    private_ep=$(echo "$CLUSTER_DATA" | jq -r '.privateClusterConfig.enablePrivateEndpoint // false')

    if [[ "$private_ep" == "true" ]]; then
        log_pass "Private Endpoint is ENABLED — Control Plane accessible only from VPC."
        record_result "5.4.3" "$(cis_title 5_4_3)" "PASS" "privateClusterConfig.enablePrivateEndpoint = true"
    else
        log_fail "Private Endpoint is NOT enabled — Control Plane is PUBLIC!"
        log_info  "Note: GKE Autopilot does not support post-creation conversion. Cluster must be recreated."
        record_result "5.4.3" "$(cis_title 5_4_3)" "FAIL" "privateClusterConfig.enablePrivateEndpoint = false"
    fi
    echo ""
}

# =============================================================================
# CIS 5.4.4 — Clusters created with Private Nodes
# =============================================================================
audit_5_4_4() {
    log_subheader "$(cis_title 5_4_4)"

    local private_nodes
    private_nodes=$(echo "$CLUSTER_DATA" | jq -r '.privateClusterConfig.enablePrivateNodes // false')

    if [[ "$private_nodes" == "true" ]]; then
        log_pass "Private Nodes ENABLED — Nodes have no external IP."
        record_result "5.4.4" "$(cis_title 5_4_4)" "PASS" "privateClusterConfig.enablePrivateNodes = true"
    else
        log_fail "Private Nodes NOT enabled — Nodes have public IPs!"
        log_info  "$(t REMEDIATION) Recreate cluster with --enable-private-nodes"
        record_result "5.4.4" "$(cis_title 5_4_4)" "FAIL" "privateClusterConfig.enablePrivateNodes = false"
    fi
    echo ""
}

# =============================================================================
# CIS 5.4.5 — Ensure use of Google-managed SSL Certificates
# =============================================================================
audit_5_4_5() {
    log_subheader "$(cis_title 5_4_5)"

    local ssl_cert
    ssl_cert=$(kubectl get ingress --all-namespaces -o json 2>/dev/null \
        | jq -r '.items[].metadata.annotations["networking.gke.io/managed-certificates"] // empty' \
        | head -1)

    if [[ -n "$ssl_cert" ]]; then
        log_pass "Google-managed SSL Certificate in use: $ssl_cert"
        record_result "5.4.5" "$(cis_title 5_4_5)" "PASS" "ManagedCertificate: $ssl_cert"
    else
        local ingress_count
        ingress_count=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$ingress_count" -eq 0 ]]; then
            log_warn "No Ingress resources found — CIS 5.4.5 not applicable."
            record_result "5.4.5" "$(cis_title 5_4_5)" "WARN" "No Ingress resource — not applicable"
        else
            log_fail "Found $ingress_count Ingress but NO Google-managed SSL Certificate."
            record_result "5.4.5" "$(cis_title 5_4_5)" "FAIL" "$ingress_count Ingress not using Google-managed SSL"
        fi
    fi
    echo ""
}

# --- Thực thi ---
audit_4_3_1
audit_5_4_1
audit_5_4_2
audit_5_4_3
audit_5_4_4
audit_5_4_5

log_info "$(printf "$(t DONE_MODULE)" "$(mod_header M2)")"
