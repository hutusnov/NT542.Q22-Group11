#!/usr/bin/env bash
# =============================================================================
# modules/module3_workload.sh
# CIS GKE Autopilot Benchmark v1.3.0
# Module 3: Workload, Secrets & Storage
# Kiểm tra: 4.6.2 | 4.6.4 | 5.2.1 | 5.3.1 | 5.6.1
# =============================================================================

if ! declare -f log_info > /dev/null 2>&1; then
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_dir}/../utils/logger.sh" 2>/dev/null || source ./utils/logger.sh
fi

log_header "$(mod_header M3)"

# =============================================================================
# CIS 4.6.2 — Seccomp profile set to RuntimeDefault
# =============================================================================
audit_4_6_2() {
    log_subheader "$(cis_title 4_6_2)"

    local pod_json
    pod_json=$(kubectl get pods --all-namespaces -o json 2>/dev/null)
    local total
    total=$(echo "$pod_json" | jq '.items | length')
    log_info "$(t TOTAL_PODS): $total"
    echo ""

    if [[ "$total" -eq 0 ]]; then
        log_warn "$(t NO_PODS)"
        record_result "4.6.2" "$(cis_title 4_6_2)" "WARN" "$(t NO_PODS)"
        return
    fi

    local pass_list=() fail_list=()
    while IFS= read -r entry; do
        local ns name stype ann
        ns=$(echo    "$entry" | jq -r '.namespace')
        name=$(echo  "$entry" | jq -r '.name')
        stype=$(echo "$entry" | jq -r '.seccompType // ""')
        ann=$(echo   "$entry" | jq -r '.annotation  // ""')
        if [[ "$stype" == "RuntimeDefault" || "$ann" == "runtime/default" ]]; then
            pass_list+=("${ns}/${name}  [seccomp=${stype:-via-annotation}]")
        else
            fail_list+=("${ns}/${name}  [seccomp=${stype:-UNSET}]")
        fi
    done < <(echo "$pod_json" | jq -c '.items[] | {
        namespace:   .metadata.namespace,
        name:        .metadata.name,
        seccompType: (.spec.securityContext.seccompProfile.type // ""),
        annotation:  (.metadata.annotations."seccomp.security.alpha.kubernetes.io/pod" // "")
    }')

    if [[ ${#fail_list[@]} -gt 0 ]]; then
        log_fail "Pod without Seccomp RuntimeDefault (${#fail_list[@]} pod(s)):"
        for item in "${fail_list[@]}"; do log_fail "  $item"; done
        echo ""
    fi
    if [[ ${#pass_list[@]} -gt 0 ]]; then
        log_pass "Pod with Seccomp RuntimeDefault: ${#pass_list[@]}"
    fi

    echo ""
    echo -e "  ┌─ Summary 4.6.2 ────────────────────────────"
    echo -e "  │  Total Pods  : $total"
    echo -e "  │  PASS        : ${#pass_list[@]}"
    echo -e "  │  FAIL        : ${#fail_list[@]}"
    echo -e "  └────────────────────────────────────────────"

    if [[ ${#fail_list[@]} -gt 0 ]]; then
        echo ""
        log_info "$(t REMEDIATION)"
        echo "    securityContext:"
        echo "      seccompProfile:"
        echo "        type: RuntimeDefault"
        record_result "4.6.2" "$(cis_title 4_6_2)" "FAIL" "${#fail_list[@]}/$total Pod(s) missing seccomp RuntimeDefault"
    else
        record_result "4.6.2" "$(cis_title 4_6_2)" "PASS" "All $total Pod(s) have seccomp RuntimeDefault"
    fi
    echo ""
}

# =============================================================================
# CIS 4.6.4 — Default namespace should not be used
# =============================================================================
audit_4_6_4() {
    log_subheader "$(cis_title 4_6_4)"

    local resources
    resources=$(kubectl get \
        all,configmaps,secrets,serviceaccounts,networkpolicies \
        -n default -o json 2>/dev/null)

    local user_res
    user_res=$(echo "$resources" | jq -r '
        .items[]
        | select(
            ((.kind == "Service"        and .metadata.name == "kubernetes")      or
             (.kind == "ServiceAccount" and .metadata.name == "default")         or
             (.kind == "ConfigMap"      and .metadata.name == "kube-root-ca.crt"))
            | not
          )
        | "  [\(.kind)] \(.metadata.name)"')

    local count
    count=$(echo "$user_res" | grep -c '\[' 2>/dev/null || true)

    if [[ $count -gt 0 ]]; then
        log_fail "Found $count user resource(s) in namespace default:"
        echo ""
        printf "  %-30s %s\n" "KIND" "NAME"
        printf "  %-30s %s\n" "──────────────────────────────" "──────────────────────"
        echo "$user_res" | while IFS= read -r line; do
            [[ -n "$line" ]] && log_fail "$line"
        done
        echo ""
        log_warn "Move workloads to dedicated namespaces."
        record_result "4.6.4" "$(cis_title 4_6_4)" "FAIL" "$count user resource(s) in namespace default"
    else
        log_pass "Namespace default has no user workloads — CIS 4.6.4 passed."
        record_result "4.6.4" "$(cis_title 4_6_4)" "PASS" "No user workload in namespace default"
    fi
    echo ""
}

# =============================================================================
# CIS 5.2.1 — GKE clusters not running using Compute Engine default SA
# =============================================================================
audit_5_2_1() {
    log_subheader "$(cis_title 5_2_1)"

    local cluster_json
    cluster_json=$(gcloud container clusters describe "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --project  "$PROJECT_ID" \
        --format   json 2>/dev/null)

    local sa_list
    sa_list=$(echo "$cluster_json" | jq -r '
        [ .nodeConfig.serviceAccount,
          (.nodePools[]?.config.serviceAccount) ]
        | map(select(. != null))
        | unique[]' 2>/dev/null || echo "default")

    echo ""
    printf "  %-55s %s\n" "SERVICE ACCOUNT" "STATUS"
    printf "  %-55s %s\n" "───────────────────────────────────────────────────────" "──────────"

    local has_default=0
    while IFS= read -r sa; do
        [[ -z "$sa" ]] && continue
        if [[ "$sa" == "default" ]]; then
            printf "  %-55s %s\n" "$sa" "❌ FAIL — Default SA"
            has_default=1
        else
            printf "  %-55s %s\n" "$sa" "✅ PASS — Custom SA"
        fi
    done <<< "$sa_list"
    echo ""

    if [[ $has_default -eq 1 ]]; then
        log_fail "Cluster is using Compute Engine Default Service Account!"
        local project_number
        project_number=$(gcloud projects describe "$PROJECT_ID" \
            --format="value(projectNumber)" 2>/dev/null || echo "???")
        log_warn "Default SA: ${project_number}-compute@developer.gserviceaccount.com"
        record_result "5.2.1" "$(cis_title 5_2_1)" "FAIL" "Cluster uses default Compute Engine SA"
    else
        log_pass "Cluster is NOT using default SA — CIS 5.2.1 passed."
        record_result "5.2.1" "$(cis_title 5_2_1)" "PASS" "All node pools use custom SA"
    fi
    echo ""
}

# =============================================================================
# CIS 5.3.1 — Kubernetes Secrets encrypted using Cloud KMS
# =============================================================================
audit_5_3_1() {
    log_subheader "$(cis_title 5_3_1)"

    local db_enc
    db_enc=$(gcloud container clusters describe "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --project  "$PROJECT_ID" \
        --format   json 2>/dev/null | jq '.databaseEncryption // {}')

    local state key_name
    state=$(echo    "$db_enc" | jq -r '.state    // "DECRYPTED"')
    key_name=$(echo "$db_enc" | jq -r '.keyName  // ""')

    printf "  %-22s %s\n" "Encryption State:" "$state"
    printf "  %-22s %s\n" "KMS Key Name:"     "${key_name:-(empty)}"
    echo ""

    if [[ "$state" == "ENCRYPTED" && -n "$key_name" ]]; then
        log_pass "Secrets encrypted with CMEK (state=ENCRYPTED)."
        log_pass "KMS Key: $key_name"
        local key_state
        key_state=$(gcloud kms keys describe "$key_name" \
            --format="value(primary.state)" 2>/dev/null || echo "UNKNOWN")
        printf "  %-22s %s\n" "KMS Key State:" "$key_state"
        if [[ "$key_state" == "ENABLED" ]]; then
            log_pass "KMS Key is ENABLED — valid."
            record_result "5.3.1" "$(cis_title 5_3_1)" "PASS" "CMEK ENCRYPTED, KMS key: $key_name (ENABLED)"
        else
            log_fail "KMS Key state: $key_state — needs investigation!"
            record_result "5.3.1" "$(cis_title 5_3_1)" "FAIL" "CMEK ENCRYPTED but KMS key state: $key_state"
        fi
    else
        log_fail "Secrets NOT encrypted (state=$state) — sensitive data unprotected!"
        log_info  "$(t REMEDIATION)"
        echo "    gcloud kms keyrings create gke-keyring --location $LOCATION --project $PROJECT_ID"
        echo "    gcloud kms keys create gke-secrets-key --location $LOCATION --keyring gke-keyring --purpose encryption --project $PROJECT_ID"
        echo "    KEY=projects/$PROJECT_ID/locations/$LOCATION/keyRings/gke-keyring/cryptoKeys/gke-secrets-key"
        echo "    gcloud container clusters update $CLUSTER_NAME --location $LOCATION --database-encryption-key \$KEY --project $PROJECT_ID"
        record_result "5.3.1" "$(cis_title 5_3_1)" "FAIL" "databaseEncryption.state = $state (CMEK not enabled)"
    fi
    echo ""
}

# =============================================================================
# CIS 5.6.1 — CMEK for GKE Persistent Disks
# =============================================================================
audit_5_6_1() {
    log_subheader "$(cis_title 5_6_1)"

    local total
    total=$(kubectl get pv --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$total" -eq 0 ]]; then
        log_warn "$(t NO_PV)"
        log_warn "GKE Autopilot has no PersistentDisk — CIS 5.6.1 not applicable."
        record_result "5.6.1" "$(cis_title 5_6_1)" "WARN" "No PV in cluster — not applicable"
        return
    fi

    log_info "$(t TOTAL_PV): $total"
    echo ""

    local ok=0 fail_count=0
    printf "  %-30s %-30s %-38s %s\n" "PV NAME" "DISK NAME" "KMS KEY" "STATUS"
    printf "  %-30s %-30s %-38s %s\n" \
        "──────────────────────────────" \
        "──────────────────────────────" \
        "──────────────────────────────────────" \
        "──────────"

    while IFS= read -r pv_name; do
        [[ -z "$pv_name" ]] && continue
        local vol_handle disk_name disk_zone
        vol_handle=$(kubectl get pv "$pv_name" -o json 2>/dev/null | \
            jq -r '.spec.csi.volumeHandle // .spec.gcePersistentDisk.pdName // "unknown"')
        if [[ "$vol_handle" == projects/* ]]; then
            disk_zone=$(echo "$vol_handle" | cut -d'/' -f4)
            disk_name=$(echo "$vol_handle" | cut -d'/' -f6)
        else
            disk_name="$vol_handle"
            disk_zone="${LOCATION}-a"
        fi
        local kms_key
        kms_key=$(gcloud compute disks describe "$disk_name" \
            --zone    "$disk_zone" \
            --project "$PROJECT_ID" \
            --format  json 2>/dev/null \
            | jq -r '.diskEncryptionKey.kmsKeyName // ""')
        if [[ -n "$kms_key" ]]; then
            printf "  %-30s %-30s %-38s %s\n" "$pv_name" "$disk_name" "${kms_key:0:36}.." "✅ PASS"
            ((ok++))
        else
            printf "  %-30s %-30s %-38s %s\n" "$pv_name" "$disk_name" "(none)" "❌ FAIL"
            ((fail_count++))
        fi
    done < <(kubectl get pv -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n')

    echo ""
    echo -e "  ┌─ Summary 5.6.1 ────────────────────────────"
    echo -e "  │  Total PVs     : $total"
    echo -e "  │  With CMEK     : $ok"
    echo -e "  │  Without CMEK  : $fail_count"
    echo -e "  └────────────────────────────────────────────"

    if [[ $fail_count -gt 0 ]]; then
        record_result "5.6.1" "$(cis_title 5_6_1)" "FAIL" "$fail_count/$total PV(s) missing CMEK encryption"
    else
        record_result "5.6.1" "$(cis_title 5_6_1)" "PASS" "All $total PV(s) have CMEK encryption"
    fi
    echo ""
}

# --- Thực thi ---
audit_4_6_2
audit_4_6_4
audit_5_2_1
audit_5_3_1
audit_5_6_1

log_info "$(t DONE_MODULE "$(mod_header M3)")"
