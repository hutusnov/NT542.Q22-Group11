#!/usr/bin/env bash
# =============================================================================
# modules/module4_image.sh
# CIS GKE Autopilot Benchmark v1.3.0
# Module 4: Image Security & Managed Services
# Kiểm tra: 5.1.1 | 5.1.2 | 5.1.3 | 5.1.4 | 5.7.1
# =============================================================================

if ! declare -f log_info > /dev/null 2>&1; then
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_dir}/../utils/logger.sh" 2>/dev/null || source ./utils/logger.sh
fi

log_header "$(mod_header M4)"

# =============================================================================
# CIS 5.1.1 — Ensure Image Vulnerability Scanning is enabled
# Level: Automated
# =============================================================================
audit_5_1_1() {
    log_subheader "$(cis_title 5_1_1)"

    local scan_enabled=0

    if gcloud services list --enabled --project "$PROJECT_ID" 2>/dev/null \
        | grep -q "containerscanning.googleapis.com"; then
        log_pass "Container Scanning API (Artifact Registry) is ENABLED."
        scan_enabled=1
    fi

    if gcloud services list --enabled --project "$PROJECT_ID" 2>/dev/null \
        | grep -q "containeranalysis.googleapis.com"; then
        log_pass "Container Analysis API (GCR legacy scanning) is ENABLED."
        scan_enabled=1
    fi

    if [[ $scan_enabled -eq 1 ]]; then
        record_result "5.1.1" "$(cis_title 5_1_1)" "PASS" "Vulnerability Scanning API is enabled on project $PROJECT_ID"
    else
        log_fail "Image Vulnerability Scanning is NOT enabled on project $PROJECT_ID."
        log_info  "$(t REMEDIATION)"
        echo "    gcloud services enable containerscanning.googleapis.com --project $PROJECT_ID"
        record_result "5.1.1" "$(cis_title 5_1_1)" "FAIL" "containerscanning.googleapis.com not enabled"
    fi
    echo ""
}

# =============================================================================
# CIS 5.1.2 — Minimize user access to Container Image repositories
# Level: Manual
# =============================================================================
audit_5_1_2() {
    log_subheader "$(cis_title 5_1_2)"

    local ar_repos
    ar_repos=$(gcloud artifacts repositories list \
        --project="$PROJECT_ID" \
        --format="value(name)" 2>/dev/null)

    if [[ -z "$ar_repos" ]]; then
        log_manual "No Artifact Registry repository found — 5.1.2 not applicable."
        record_result "5.1.2" "$(cis_title 5_1_2)" "MANUAL" "No Artifact Registry repository found"
        echo ""
        return
    fi

    local has_fail=0
    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        local loc
        loc=$(gcloud artifacts repositories describe "$repo" \
            --project="$PROJECT_ID" \
            --format="value(location)" 2>/dev/null)
        local policy
        policy=$(gcloud artifacts repositories get-iam-policy "$repo" \
            --location="$loc" \
            --project="$PROJECT_ID" \
            --format=json 2>/dev/null)

        local public_members
        public_members=$(echo "$policy" | jq -r '
            .bindings[]? | select(
                .members[]? | (. == "allUsers" or . == "allAuthenticatedUsers")
            ) | "    Role: \(.role) — Members: \(.members | join(", "))"
        ')

        if [[ -n "$public_members" ]]; then
            log_fail "Repository '$repo' is PUBLICLY accessible:"
            echo "$public_members"
            has_fail=1
        else
            log_pass "Repository '$repo' is NOT public."
        fi
    done <<< "$ar_repos"

    if [[ $has_fail -eq 1 ]]; then
        record_result "5.1.2" "$(cis_title 5_1_2)" "FAIL" "One or more repositories allow allUsers/allAuthenticatedUsers"
    else
        record_result "5.1.2" "$(cis_title 5_1_2)" "PASS" "All Artifact Registry repos have no public access"
    fi
    echo ""
}

# =============================================================================
# CIS 5.1.3 — Minimize cluster access to read-only for Image repositories
# Level: Manual
# =============================================================================
audit_5_1_3() {
    log_subheader "$(cis_title 5_1_3)"

    local ar_repos
    ar_repos=$(gcloud artifacts repositories list \
        --project="$PROJECT_ID" \
        --format="value(name)" 2>/dev/null)

    if [[ -z "$ar_repos" ]]; then
        log_manual "No Artifact Registry repository found — 5.1.3 not applicable."
        record_result "5.1.3" "$(cis_title 5_1_3)" "MANUAL" "No Artifact Registry repository found"
        echo ""
        return
    fi

    local write_roles=("roles/artifactregistry.writer" "roles/artifactregistry.admin" "roles/editor" "roles/owner")
    local has_write=0

    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        local loc
        loc=$(gcloud artifacts repositories describe "$repo" \
            --project="$PROJECT_ID" \
            --format="value(location)" 2>/dev/null)
        local policy
        policy=$(gcloud artifacts repositories get-iam-policy "$repo" \
            --location="$loc" \
            --project="$PROJECT_ID" \
            --format=json 2>/dev/null)

        for role in "${write_roles[@]}"; do
            local members
            members=$(echo "$policy" | jq -r --arg r "$role" '
                .bindings[]? | select(.role == $r) | .members[]?
                | select(startswith("serviceAccount:") or startswith("user:"))
            ')
            if [[ -n "$members" ]]; then
                log_warn "Repository '$repo' grants WRITE access ($role):"
                echo "$members" | sed 's/^/    /'
                has_write=1
            fi
        done
    done <<< "$ar_repos"

    if [[ $has_write -eq 0 ]]; then
        log_pass "All repositories grant only read access to cluster service accounts."
        record_result "5.1.3" "$(cis_title 5_1_3)" "PASS" "No write-level IAM bindings on Artifact Registry repos"
    else
        log_manual "Write-level bindings found — manual review required to confirm necessity."
        record_result "5.1.3" "$(cis_title 5_1_3)" "MANUAL" "Write-level IAM bindings exist on one or more repos"
    fi
    echo ""
}

# =============================================================================
# CIS 5.1.4 — Ensure only trusted container images are used (Binary Authorization)
# Level: Automated
# =============================================================================
audit_5_1_4() {
    log_subheader "$(cis_title 5_1_4)"

    local cluster_json
    cluster_json=$(gcloud container clusters describe "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --project  "$PROJECT_ID" \
        --format   json 2>/dev/null)

    local bin_auth_mode
    bin_auth_mode=$(echo "$cluster_json" | jq -r '.binaryAuthorization.evaluationMode // "DISABLED"')

    printf "  %-30s %s\n" "binaryAuthorization.evaluationMode:" "$bin_auth_mode"
    echo ""

    case "$bin_auth_mode" in
        "PROJECT_SINGLETON_POLICY_ENFORCE")
            log_pass "Binary Authorization ENABLED (mode: ENFORCE)."
            record_result "5.1.4" "$(cis_title 5_1_4)" "PASS" "binaryAuthorization = PROJECT_SINGLETON_POLICY_ENFORCE"
            ;;
        "POLICY_BINDINGS"|"POLICY_BINDINGS_AND_PROJECT_SINGLETON_POLICY_ENFORCE")
            log_pass "Binary Authorization ENABLED (mode: $bin_auth_mode)."
            record_result "5.1.4" "$(cis_title 5_1_4)" "PASS" "binaryAuthorization.evaluationMode = $bin_auth_mode"
            ;;
        "DISABLED"|"EVALUATION_MODE_UNSPECIFIED"|"UNKNOWN")
            log_fail "Binary Authorization is NOT enabled (mode: $bin_auth_mode)."
            log_info  "$(t REMEDIATION)"
            echo "    gcloud container clusters update $CLUSTER_NAME --location $LOCATION \\"
            echo "      --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE"
            record_result "5.1.4" "$(cis_title 5_1_4)" "FAIL" "binaryAuthorization.evaluationMode = $bin_auth_mode"
            ;;
        *)
            log_manual "Binary Authorization mode '$bin_auth_mode' — manual review required."
            record_result "5.1.4" "$(cis_title 5_1_4)" "MANUAL" "Unknown evaluationMode: $bin_auth_mode"
            ;;
    esac
    echo ""
}

# =============================================================================
# CIS 5.7.1 — Enable Security Posture
# Level: Automated
# =============================================================================
audit_5_7_1() {
    log_subheader "$(cis_title 5_7_1)"

    local cluster_json
    cluster_json=$(gcloud container clusters describe "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --project  "$PROJECT_ID" \
        --format   json 2>/dev/null)

    local posture_mode vuln_mode
    posture_mode=$(echo "$cluster_json" | jq -r '.securityPostureConfig.mode              // "DISABLED"')
    vuln_mode=$(echo   "$cluster_json" | jq -r '.securityPostureConfig.vulnerabilityMode  // "VULNERABILITY_DISABLED"')

    printf "  %-30s %s\n" "securityPostureConfig.mode:"             "$posture_mode"
    printf "  %-30s %s\n" "securityPostureConfig.vulnerabilityMode:" "$vuln_mode"
    echo ""

    local posture_ok=0 vuln_ok=0

    case "$posture_mode" in
        "BASIC"|"ENTERPRISE") posture_ok=1 ;;
    esac
    case "$vuln_mode" in
        "VULNERABILITY_BASIC"|"VULNERABILITY_ENTERPRISE") vuln_ok=1 ;;
    esac

    if [[ $posture_ok -eq 1 ]]; then
        log_pass "Security Posture mode is ENABLED ($posture_mode)."
    else
        log_fail "Security Posture mode is DISABLED."
    fi

    if [[ $vuln_ok -eq 1 ]]; then
        log_pass "Vulnerability Scanning mode is ENABLED ($vuln_mode)."
    else
        log_warn "Vulnerability Scanning mode is DISABLED — consider enabling for runtime threat detection."
    fi

    if [[ $posture_ok -eq 1 && $vuln_ok -eq 1 ]]; then
        record_result "5.7.1" "$(cis_title 5_7_1)" "PASS" "Security Posture: $posture_mode, Vulnerability: $vuln_mode"
    elif [[ $posture_ok -eq 1 ]]; then
        record_result "5.7.1" "$(cis_title 5_7_1)" "MANUAL" "Posture: $posture_mode (OK), VulnMode: $vuln_mode (consider upgrading)"
    else
        log_info  "$(t REMEDIATION)"
        echo "    gcloud container clusters update $CLUSTER_NAME --location $LOCATION \\"
        echo "      --security-posture=standard --workload-vulnerability-scanning=standard"
        record_result "5.7.1" "$(cis_title 5_7_1)" "FAIL" "securityPostureConfig.mode = $posture_mode"
    fi
    echo ""
}

# --- Thực thi ---
audit_5_1_1
audit_5_1_2
audit_5_1_3
audit_5_1_4
audit_5_7_1

log_info "$(printf "$(t DONE_MODULE)" "$(mod_header M4)")"
