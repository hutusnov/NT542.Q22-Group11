#!/usr/bin/env bash
# =============================================================================
# modules/module1_iam_rbac.sh
# CIS GKE Autopilot Benchmark v1.3.0
# Module 1: IAM & RBAC
# Kiểm tra: 4.1.1 | 4.1.2 | 4.1.3 | 4.1.4 | 4.1.8 | 4.1.9 | 4.1.10 | 5.5.1
# =============================================================================

# Nạp logger (và i18n tự động) nếu chạy độc lập
if ! declare -f log_info > /dev/null 2>&1; then
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_dir}/../utils/logger.sh" 2>/dev/null || source ./utils/logger.sh
fi

log_header "$(mod_header M1)"

# =============================================================================
# CIS 4.1.1 — Ensure that the cluster-admin role is only used where required
# =============================================================================
audit_4_1_1() {
    log_subheader "$(cis_title 4_1_1)"

    local bindings
    bindings=$(kubectl get clusterrolebinding -o json 2>/dev/null \
        | jq -r '.items[] | select(.roleRef.name == "cluster-admin")
            | "  Binding: \(.metadata.name)\n    Subjects: \(
                [.subjects[]? | "\(.kind)/\(.name)"] | join(", ")
              )"')

    local count
    count=$(kubectl get clusterrolebinding -o json 2>/dev/null \
        | jq '[.items[] | select(.roleRef.name == "cluster-admin")] | length')

    log_info "cluster-admin ClusterRoleBindings: $count"
    echo ""

    if [[ -z "$bindings" ]]; then
        log_pass "$(t LOADING_CLUSTER)" # placeholder — overridden below
        log_pass "No cluster-admin ClusterRoleBinding found outside system accounts."
        record_result "4.1.1" "$(cis_title 4_1_1)" "PASS" "No cluster-admin binding found outside system accounts"
    else
        echo "$bindings"
        echo ""
        local user_bindings
        user_bindings=$(kubectl get clusterrolebinding -o json 2>/dev/null \
            | jq -r '.items[] | select(
                .roleRef.name == "cluster-admin"
                and (.subjects[]? | .name | startswith("system:") | not)
              ) | .metadata.name')

        if [[ -n "$user_bindings" ]]; then
            log_fail "cluster-admin bound to non-system users/SA: $user_bindings"
            record_result "4.1.1" "$(cis_title 4_1_1)" "FAIL" "Binding to non-system account: $user_bindings"
        else
            log_manual "Found $count cluster-admin binding(s) — all to system accounts. Verify manually."
            record_result "4.1.1" "$(cis_title 4_1_1)" "MANUAL" "Manual review required: $count binding(s) found"
        fi
    fi
    echo ""
}

# =============================================================================
# CIS 4.1.2 — Minimize access to secrets
# =============================================================================
audit_4_1_2() {
    log_subheader "$(cis_title 4_1_2)"

    local roles_with_secrets
    roles_with_secrets=$(kubectl get clusterrole,role -A -o json 2>/dev/null | jq -r '
        def wanted: ["get","list","watch"];
        .items[] as $r
        | [ $r.rules[]?
            | select(
                ((.apiGroups? // [""]) | any(.=="" or .=="*"))
                and ((.resources? // []) | any(.=="secrets" or .=="secrets/*" or .=="*"))
                and ((.verbs? // []) | any(.=="*" or .=="get" or .=="list" or .=="watch"))
              )
            | if ((.verbs? // []) | any(.=="*"))
              then wanted[] else (.verbs[]? | select(IN("get","list","watch"))) end
          ] as $verbs
        | select($verbs | length > 0)
        | "  \($r.kind)/\($r.metadata.name) [ns: \($r.metadata.namespace // "cluster-wide")] — verbs: \($verbs | unique | join(","))"
    ')

    if [[ -z "$roles_with_secrets" ]]; then
        log_pass "No Role/ClusterRole found with secrets access."
        record_result "4.1.2" "$(cis_title 4_1_2)" "PASS" "No Role has get/list/watch on secrets"
    else
        local count
        count=$(echo "$roles_with_secrets" | grep -c "." || true)
        log_fail "Found $count Role(s) with secrets access:"
        echo "$roles_with_secrets"
        record_result "4.1.2" "$(cis_title 4_1_2)" "FAIL" "$count Role(s) with get/list/watch on secrets"
    fi
    echo ""
}

# =============================================================================
# CIS 4.1.3 — Minimize wildcard use in Roles and ClusterRoles
# =============================================================================
audit_4_1_3() {
    log_subheader "$(cis_title 4_1_3)"

    local wildcard_roles
    wildcard_roles=$(kubectl get clusterrole,role -A -o json 2>/dev/null | jq -r '
        .items[] | select(.rules[]? |
            ((.apiGroups? // []) | any(. == "*")) or
            ((.resources? // []) | any(. == "*")) or
            ((.verbs? // []) | any(. == "*"))
        ) | "  \(.kind)/\(.metadata.name) [ns: \(.metadata.namespace // "cluster-wide")]"
    ')

    if [[ -z "$wildcard_roles" ]]; then
        log_pass "No Role found using wildcard (*) permissions."
        record_result "4.1.3" "$(cis_title 4_1_3)" "PASS" "No Role uses wildcard (*)"
    else
        local count
        count=$(echo "$wildcard_roles" | grep -c "." || true)
        log_fail "Found $count Role(s) using wildcard (*):"
        echo "$wildcard_roles"
        record_result "4.1.3" "$(cis_title 4_1_3)" "FAIL" "$count Role(s) use wildcard (*)"
    fi
    echo ""
}

# =============================================================================
# CIS 4.1.4 — Ensure that default service accounts are not actively used
# =============================================================================
audit_4_1_4() {
    log_subheader "$(cis_title 4_1_4)"

    local sa_automount
    sa_automount=$(kubectl get serviceaccounts -A -o json 2>/dev/null | jq -r '
        .items[] | select(
            .metadata.name == "default"
            and (.automountServiceAccountToken // true) == true
        ) | "  Namespace: \(.metadata.namespace)"
    ')

    local pods_default_sa
    pods_default_sa=$(kubectl get pods -A -o json 2>/dev/null | jq -r '
        .items[] | select(
            (.spec.serviceAccountName // "default") == "default"
        ) | "  \(.metadata.namespace)/\(.metadata.name)"
    ')

    local sa_count pods_count
    sa_count=$(echo "$sa_automount"   | grep -c "." 2>/dev/null || echo 0)
    pods_count=$(echo "$pods_default_sa" | grep -c "." 2>/dev/null || echo 0)

    if [[ $sa_count -eq 0 ]]; then
        log_pass "All default ServiceAccounts have automountServiceAccountToken disabled."
    else
        log_fail "Default SA in $sa_count namespace(s) still automounting tokens:"
        echo "$sa_automount"
    fi
    echo ""

    if [[ $pods_count -eq 0 ]]; then
        log_pass "No Pod found running with default ServiceAccount."
        record_result "4.1.4" "$(cis_title 4_1_4)" "PASS" "No Pod uses default SA"
    else
        log_warn "Found $pods_count Pod(s) using default ServiceAccount:"
        echo "$pods_default_sa" | head -10
        [[ $pods_count -gt 10 ]] && echo "    ... and $(( pods_count - 10 )) more"
        if [[ $sa_count -gt 0 ]]; then
            record_result "4.1.4" "$(cis_title 4_1_4)" "FAIL" "$sa_count NS not disabled automount; $pods_count Pod(s) use default SA"
        else
            record_result "4.1.4" "$(cis_title 4_1_4)" "MANUAL" "$pods_count Pod(s) use default SA — manual review required"
        fi
    fi
    echo ""
}

# =============================================================================
# CIS 4.1.8 — Avoid bindings to system:anonymous
# =============================================================================
audit_4_1_8() {
    log_subheader "$(cis_title 4_1_8)"

    local anon_bindings
    anon_bindings=$(kubectl get clusterrolebinding,rolebinding -A -o json 2>/dev/null | jq -r '
        .items[] | select(.subjects[]? | .name == "system:anonymous")
        | "  \(.kind)/\(.metadata.name) — role: \(.roleRef.name)"
    ')

    if [[ -z "$anon_bindings" ]]; then
        log_pass "No binding found for system:anonymous."
        record_result "4.1.8" "$(cis_title 4_1_8)" "PASS" "No binding for system:anonymous"
    else
        log_fail "CRITICAL: Found binding(s) for system:anonymous:"
        echo "$anon_bindings"
        record_result "4.1.8" "$(cis_title 4_1_8)" "FAIL" "Binding(s) to system:anonymous detected — unauthenticated access risk"
    fi
    echo ""
}

# =============================================================================
# CIS 4.1.9 — Avoid non-default bindings to system:unauthenticated
# =============================================================================
audit_4_1_9() {
    log_subheader "$(cis_title 4_1_9)"

    local unauth_bindings
    unauth_bindings=$(kubectl get clusterrolebinding,rolebinding -A -o json 2>/dev/null | jq -r '
        .items[] | select(
            .subjects[]? | .name == "system:unauthenticated"
        ) | select(
            .metadata.name | (
                startswith("system:public-info-viewer") or
                startswith("system:discovery") or
                startswith("system:basic-user")
            ) | not
        ) | "  \(.kind)/\(.metadata.name) — role: \(.roleRef.name)"
    ')

    if [[ -z "$unauth_bindings" ]]; then
        log_pass "No non-default binding found for system:unauthenticated."
        record_result "4.1.9" "$(cis_title 4_1_9)" "PASS" "Only system defaults exist for system:unauthenticated"
    else
        log_fail "Found non-default binding(s) for system:unauthenticated:"
        echo "$unauth_bindings"
        record_result "4.1.9" "$(cis_title 4_1_9)" "FAIL" "Custom binding(s) to system:unauthenticated detected"
    fi
    echo ""
}

# =============================================================================
# CIS 4.1.10 — Avoid non-default bindings to system:authenticated
# =============================================================================
audit_4_1_10() {
    log_subheader "$(cis_title 4_1_10)"

    local auth_bindings
    auth_bindings=$(kubectl get clusterrolebinding,rolebinding -A -o json 2>/dev/null | jq -r '
        .items[] | select(
            .subjects[]? | .name == "system:authenticated"
        ) | select(
            .metadata.name | (
                startswith("system:public-info-viewer") or
                startswith("system:discovery") or
                startswith("system:basic-user")
            ) | not
        ) | "  \(.kind)/\(.metadata.name) — role: \(.roleRef.name)"
    ')

    if [[ -z "$auth_bindings" ]]; then
        log_pass "No non-default binding found for system:authenticated."
        record_result "4.1.10" "$(cis_title 4_1_10)" "PASS" "Only system defaults exist for system:authenticated"
    else
        log_fail "Found non-default binding(s) for system:authenticated:"
        echo "$auth_bindings"
        record_result "4.1.10" "$(cis_title 4_1_10)" "FAIL" "Custom binding(s) to system:authenticated detected"
    fi
    echo ""
}

# =============================================================================
# CIS 5.5.1 — Manage Kubernetes RBAC users with Google Groups for GKE
# =============================================================================
audit_5_5_1() {
    log_subheader "$(cis_title 5_5_1)"

    local group_enabled
    group_enabled=$(gcloud container clusters describe "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --project  "$PROJECT_ID" \
        --format   "value(authenticatorGroupsConfig.enabled)" 2>/dev/null)

    if [[ "$group_enabled" == "True" ]]; then
        local group_domain
        group_domain=$(gcloud container clusters describe "$CLUSTER_NAME" \
            --location "$LOCATION" \
            --project  "$PROJECT_ID" \
            --format   "value(authenticatorGroupsConfig.securityGroup)" 2>/dev/null)
        log_pass "Google Groups for GKE is ENABLED."
        log_info  "Security Group: $group_domain"
        record_result "5.5.1" "$(cis_title 5_5_1)" "PASS" "Security Group: ${group_domain:-N/A}"
    else
        log_fail "Google Groups for GKE is NOT enabled."
        record_result "5.5.1" "$(cis_title 5_5_1)" "FAIL" "authenticatorGroupsConfig.enabled = false"
    fi
    echo ""
}

# --- Thực thi ---
audit_4_1_1
audit_4_1_2
audit_4_1_3
audit_4_1_4
audit_4_1_8
audit_4_1_9
audit_4_1_10
audit_5_5_1

log_info "$(t DONE_MODULE "$(mod_header M1)")"
