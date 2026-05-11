#!/usr/bin/env bash
# =============================================================================
# main.sh — CIS GKE Autopilot Benchmark v1.3.0 Audit Tool (Entry Point)
# =============================================================================
# Cách dùng:
#   bash main.sh                          # Chạy với ngôn ngữ mặc định (vi)
#   AUDIT_LANG=en bash main.sh            # Chạy với ngôn ngữ tiếng Anh
#   PROJECT_ID=my-proj CLUSTER_NAME=my-cluster bash main.sh
#
# Kết quả xuất ra:
#   output/gke_audit_YYYYMMDD_HHMMSS.csv
#   output/gke_audit_YYYYMMDD_HHMMSS.html
# =============================================================================

# Xác định đường dẫn gốc của script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Nạp tiện ích (i18n được nạp tự động bên trong logger.sh) ---
source "${SCRIPT_DIR}/utils/logger.sh"
source "${SCRIPT_DIR}/utils/reporter.sh"

# ==========================================
# CẤU HÌNH BIẾN MÔI TRƯỜNG
# ==========================================
export PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
export CLUSTER_NAME="${CLUSTER_NAME:-$(kubectl config current-context 2>/dev/null | awk -F'_' '{print $4}')}"
export LOCATION="${LOCATION:-$(kubectl config current-context 2>/dev/null | awk -F'_' '{print $3}')}"
export AUDIT_LANG="${AUDIT_LANG:-vi}"

# Timestamp dùng cho tên file output
_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${SCRIPT_DIR}/output"
OUTPUT_CSV="${OUTPUT_DIR}/gke_audit_${_TIMESTAMP}.csv"
OUTPUT_HTML="${OUTPUT_DIR}/gke_audit_${_TIMESTAMP}.html"

DO_REMEDIATE=false
for arg in "$@"; do
    if [[ "$arg" == "--remediate" ]]; then
        DO_REMEDIATE=true
    fi
done

# ==========================================
# KIỂM TRA PHỤ THUỘC
# ==========================================
check_dependencies() {
    log_info "$(t CHECKING_DEPS)"
    local deps=("gcloud" "kubectl" "jq")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$(t DEP_MISSING "$cmd")"
            exit 1
        fi
    done
    log_pass "$(t DEPS_OK)"
}

# ==========================================
# XÁC THỰC VÀ KẾT NỐI GCP
# ==========================================
authenticate_gcp() {
    log_info "$(t AUTH_GCP)"

    if [[ "$CI" == "true" ]]; then
        log_info "$(t AUTH_CI)"
    else
        local ACCOUNT
        ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
        if [[ -z "$ACCOUNT" ]]; then
            log_info "$(t AUTH_NO_SESSION)"
            gcloud auth login
        fi
        ACCOUNT=$(gcloud config get-value account 2>/dev/null)
        if [[ -n "$ACCOUNT" ]]; then
            log_pass "$(t AUTH_OK "$ACCOUNT")"
        fi
    fi

    log_info "$(t CONNECT_CLUSTER "$CLUSTER_NAME")"
    if gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --location="$LOCATION" \
        --project="$PROJECT_ID" > /dev/null 2>&1; then
        log_pass "$(t CONNECT_OK)"
    else
        log_error "$(t CONNECT_FAIL)"
        exit 1
    fi
}

# ==========================================
# LUỒNG THỰC THI CHÍNH
# ==========================================
main() {
    clear
    log_header "$(t MAIN)"

    log_info "Project  : $PROJECT_ID"
    log_info "Cluster  : $CLUSTER_NAME"
    log_info "Location : $LOCATION"
    log_info "$(t LANG_CURRENT)"
    log_info "Time     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    check_dependencies
    authenticate_gcp

    # ---- CHẠY 4 MODULE CHÍNH ----
    source "${SCRIPT_DIR}/modules/module1_iam_rbac.sh"
    source "${SCRIPT_DIR}/modules/module2_networking.sh"
    source "${SCRIPT_DIR}/modules/module3_workload.sh"
    source "${SCRIPT_DIR}/modules/module4_image.sh"

    # ---- THÊM CÁC MỤC KIỂM TRA THỦ CÔNG (có thực thi lệnh) ----
    log_info "Bổ sung 3 mục kiểm tra tự động (Automated) và 3 mục thủ công (Manual) vào báo cáo..."
    echo ""

    # =========================================================================
    # CIS 4.1.5 — Ensure SA Tokens are only mounted where necessary (Automated)
    # =========================================================================
    audit_4_1_5() {
        log_subheader "$(cis_title 4_1_5)"

        # Whitelist: system namespaces legitimately need SA token access
        local SYS_NS_PATTERN="^(kube-system|kube-public|kube-node-lease|gke-.*|gmp-.*|gke-managed-.*)$"

        local all_automount
        all_automount=$(kubectl get pods -A -o json 2>/dev/null | jq -r '
            .items[] | select(
                (.spec.automountServiceAccountToken // true) == true
            ) | "\(.metadata.namespace)/\(.metadata.name)"
        ')

        local total_automount=0
        [[ -n "$all_automount" ]] && total_automount=$(echo "$all_automount" | wc -l | tr -d ' ')

        # Filter: only flag user-namespace pods
        local user_pods_automount=""
        if [[ -n "$all_automount" ]]; then
            user_pods_automount=$(echo "$all_automount" | while IFS='/' read -r ns pod; do
                if ! [[ "$ns" =~ $SYS_NS_PATTERN ]]; then
                    echo "  $ns/$pod  [automount=true]"
                fi
            done)
        fi

        local user_count=0
        [[ -n "$user_pods_automount" ]] && user_count=$(echo "$user_pods_automount" | wc -l | tr -d ' ')

        local sys_count=$(( total_automount - user_count ))

        log_info "Total pods with automount=true: $total_automount (system: $sys_count, user: $user_count)"

        if [[ $user_count -eq 0 ]]; then
            log_pass "No user-namespace Pod has automountServiceAccountToken enabled."
            [[ $sys_count -gt 0 ]] && log_info "($sys_count system pod(s) whitelisted — kube-system, gke-*, gmp-*)"
            record_result "4.1.5" "$(cis_title 4_1_5)" "PASS" "No user-ns pod with automount=true ($sys_count system pods whitelisted)"
        else
            log_fail "Found $user_count user-namespace Pod(s) with automountServiceAccountToken: true:"
            echo "$user_pods_automount" | head -15
            [[ $user_count -gt 15 ]] && echo "    ... and $(( user_count - 15 )) more"
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Set automountServiceAccountToken: false in pod spec for pods that don't need Kubernetes API access."
            else
                echo "    # $(t REMEDIATION) Đặt automountServiceAccountToken: false trong pod spec cho các pod không cần truy cập Kubernetes API."
            fi
            record_result "4.1.5" "$(cis_title 4_1_5)" "FAIL" "$user_count user-ns Pod(s) with automount=true"
        fi
        echo ""
    }

    # =========================================================================
    # CIS 4.1.7 — Limit Bind, Impersonate and Escalate permissions (Automated)
    # =========================================================================
    audit_4_1_7() {
        log_subheader "$(cis_title 4_1_7)"

        # Get all ClusterRoles with risky verbs, separated by system vs custom
        local all_risky
        all_risky=$(kubectl get clusterroles -o json 2>/dev/null | jq -r '
            .items[] | select(
                .rules[]? | .verbs[]? | test("bind|impersonate|escalate")
            ) | .metadata.name
        ')

        local total_risky=0
        [[ -n "$all_risky" ]] && total_risky=$(echo "$all_risky" | wc -l | tr -d ' ')

        # Separate system roles (system:* and known k8s built-ins) from custom
        local custom_risky=""
        local system_risky=""
        if [[ -n "$all_risky" ]]; then
            while IFS= read -r role; do
                if [[ "$role" =~ ^system: ]]; then
                    system_risky="${system_risky:+$system_risky
}  ClusterRole/$role  [system]"
                else
                    custom_risky="${custom_risky:+$custom_risky
}  ClusterRole/$role  [custom]"
                fi
            done <<< "$all_risky"
        fi

        local custom_count=0
        [[ -n "$custom_risky" ]] && custom_count=$(echo "$custom_risky" | wc -l | tr -d ' ')
        local system_count=$(( total_risky - custom_count ))

        log_info "ClusterRoles with bind/impersonate/escalate: $total_risky (system: $system_count, custom: $custom_count)"

        if [[ $custom_count -eq 0 ]]; then
            log_pass "No custom ClusterRole found with bind/impersonate/escalate permissions."
            [[ $system_count -gt 0 ]] && log_info "($system_count system role(s) whitelisted — system:* built-in roles)"
            record_result "4.1.7" "$(cis_title 4_1_7)" "PASS" "No custom role with risky verbs ($system_count system roles whitelisted)"
        else
            log_fail "Found $custom_count custom ClusterRole(s) with bind/impersonate/escalate:"
            echo "$custom_risky"
            [[ $system_count -gt 0 ]] && echo "" && log_info "($system_count system role(s) whitelisted)"
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Remove bind/impersonate/escalate verbs from custom ClusterRoles, or restrict them to trusted admin accounts."
            else
                echo "    # $(t REMEDIATION) Xóa các quyền bind/impersonate/escalate khỏi ClusterRole tùy chỉnh, hoặc giới hạn chỉ cho tài khoản admin đáng tin cậy."
            fi
            record_result "4.1.7" "$(cis_title 4_1_7)" "FAIL" "$custom_count custom ClusterRole(s) with risky verbs"
        fi
        echo ""
    }

    # =========================================================================
    # CIS 4.4.1 — Consider external secret storage (Manual)
    # =========================================================================
    audit_manual_4_4_1() {
        log_subheader "$(cis_title 4_4_1)"

        local secret_pods
        secret_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -iE "vault|external-secrets|secret-store|csi-secrets" || true)

        if [[ -n "$secret_pods" ]]; then
            log_manual "External secret management components detected — verify configuration:"
            echo "$secret_pods" | sed 's/^/    /'
            record_result "4.4.1" "$(cis_title 4_4_1)" "MANUAL" "External secret pods found — verify configuration"
        else
            log_manual "No external secret storage components (Vault, External Secrets, CSI) detected."
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Consider deploying External Secrets Operator or Secrets Store CSI Driver."
            else
                echo "    # $(t REMEDIATION) Cân nhắc triển khai External Secrets Operator hoặc Secrets Store CSI Driver."
            fi
            record_result "4.4.1" "$(cis_title 4_4_1)" "MANUAL" "No external secret storage detected — consider deploying one"
        fi
        echo ""
    }

    # =========================================================================
    # CIS 4.5.1 — Configure Image Provenance (ImagePolicyWebhook) (Manual)
    # =========================================================================
    audit_manual_4_5_1() {
        log_subheader "$(cis_title 4_5_1)"

        local webhooks
        webhooks=$(kubectl get validatingwebhookconfigurations --no-headers 2>/dev/null || true)
        local mutating
        mutating=$(kubectl get mutatingwebhookconfigurations --no-headers 2>/dev/null || true)

        local wh_count=0 mwh_count=0
        [[ -n "$webhooks" ]] && wh_count=$(echo "$webhooks" | wc -l | tr -d ' ')
        [[ -n "$mutating" ]] && mwh_count=$(echo "$mutating" | wc -l | tr -d ' ')

        log_info "ValidatingWebhookConfigurations: $wh_count"
        log_info "MutatingWebhookConfigurations:    $mwh_count"
        echo ""

        if [[ $wh_count -gt 0 ]]; then
            echo "  ValidatingWebhook:"
            echo "$webhooks" | sed 's/^/    /'
        fi
        if [[ $mwh_count -gt 0 ]]; then
            echo "  MutatingWebhook:"
            echo "$mutating" | sed 's/^/    /'
        fi
        echo ""

        if [[ $wh_count -gt 0 || $mwh_count -gt 0 ]]; then
            log_manual "Webhook configurations found — verify if image provenance is validated."
            record_result "4.5.1" "$(cis_title 4_5_1)" "MANUAL" "$wh_count validating + $mwh_count mutating webhook(s) — verify image provenance"
        else
            log_manual "No admission webhook found — image provenance is NOT validated."
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Configure an admission controller to validate image provenance."
            else
                echo "    # $(t REMEDIATION) Cấu hình Admission Controller để xác thực nguồn gốc image."
            fi
            record_result "4.5.1" "$(cis_title 4_5_1)" "MANUAL" "No admission webhook configured for image provenance"
        fi
        echo ""
    }

    # =========================================================================
    # CIS 4.6.1 — Administrative boundaries using namespaces (Manual)
    # =========================================================================
    audit_manual_4_6_1() {
        log_subheader "$(cis_title 4_6_1)"

        local ns_list
        ns_list=$(kubectl get namespaces -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp --no-headers 2>/dev/null)

        local total
        total=$(echo "$ns_list" | wc -l | tr -d ' ')

        local user_ns
        user_ns=$(echo "$ns_list" | grep -vE "^(kube-system|kube-public|kube-node-lease|default|gke-managed)" || true)
        local user_count=0
        [[ -n "$user_ns" ]] && user_count=$(echo "$user_ns" | wc -l | tr -d ' ')

        echo ""
        printf "  %-30s %-12s %s\n" "NAMESPACE" "STATUS" "CREATED"
        printf "  %-30s %-12s %s\n" "──────────────────────────────" "────────────" "───────────────────"
        echo "$ns_list" | while IFS= read -r line; do
            printf "  %-30s\n" "$line"
        done
        echo ""

        log_info "Total namespaces: $total (system) + $user_count (user-created)"

        if [[ $user_count -gt 0 ]]; then
            log_manual "User-created namespaces detected — verify administrative boundaries are adequate."
            record_result "4.6.1" "$(cis_title 4_6_1)" "MANUAL" "$user_count user namespace(s) found — verify boundaries are adequate"
        else
            log_manual "Only system namespaces found — workloads may lack segregation."
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Ensure workloads are segregated into dedicated namespaces."
            else
                echo "    # $(t REMEDIATION) Đảm bảo workloads được triển khai vào các namespace phân lập."
            fi
            record_result "4.6.1" "$(cis_title 4_6_1)" "MANUAL" "Only system namespaces found — consider creating dedicated namespaces"
        fi
        echo ""
    }

    # =========================================================================
    # CIS 4.6.3 — Apply Security Context to Pods and Containers (Automated)
    # =========================================================================
    audit_4_6_3() {
        log_subheader "$(cis_title 4_6_3)"

        local total
        total=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')

        # Check each container for critical security context settings:
        #   - runAsNonRoot: true (pod or container level)
        #   - allowPrivilegeEscalation: false
        #   - readOnlyRootFilesystem: true (recommended)
        local pods_weak_sc
        pods_weak_sc=$(kubectl get pods -A -o json 2>/dev/null | jq -r '
            .items[] as $pod |
            # Check pod-level securityContext
            ($pod.spec.securityContext // {}) as $pod_sc |
            # Check each container
            [ $pod.spec.containers[]? |
                (.securityContext // {}) as $csc |
                {
                    name: .name,
                    runAsNonRoot: ($csc.runAsNonRoot // $pod_sc.runAsNonRoot // false),
                    allowPrivEsc: (if $csc.allowPrivilegeEscalation == null then true else $csc.allowPrivilegeEscalation end),
                    readOnlyFS: ($csc.readOnlyRootFilesystem // false)
                } |
                select(
                    .runAsNonRoot != true or
                    .allowPrivEsc != false or
                    .readOnlyFS != true
                )
            ] |
            select(length > 0) |
            # Build detail string with missing fields
            map(
                .name + " [" +
                ([ (if .runAsNonRoot != true then "runAsNonRoot" else empty end),
                   (if .allowPrivEsc != false then "allowPrivEsc" else empty end),
                   (if .readOnlyFS != true then "readOnlyFS" else empty end)
                ] | join(",")) + "]"
            ) as $details |
            "  \($pod.metadata.namespace)/\($pod.metadata.name): \($details | join(", "))"
        ')

        local count=0
        if [[ -n "$pods_weak_sc" ]]; then
            count=$(echo "$pods_weak_sc" | wc -l | tr -d ' ')
        fi

        log_info "Checking $total Pod(s) for: runAsNonRoot, allowPrivilegeEscalation=false, readOnlyRootFilesystem"

        if [[ $count -eq 0 ]]; then
            log_pass "All $total Pod(s) have strict Security Context configured."
            record_result "4.6.3" "$(cis_title 4_6_3)" "PASS" "All $total Pods have strict Security Context"
        else
            log_fail "Found $count/$total Pod(s) with weak/missing Security Context:"
            echo "$pods_weak_sc" | head -15
            [[ $count -gt 15 ]] && echo "    ... and $(( count - 15 )) more"
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Apply strict Security Context: runAsNonRoot: true, allowPrivilegeEscalation: false, readOnlyRootFilesystem: true."
            else
                echo "    # $(t REMEDIATION) Áp dụng Security Context chặt: runAsNonRoot: true, allowPrivilegeEscalation: false, readOnlyRootFilesystem: true."
            fi
            record_result "4.6.3" "$(cis_title 4_6_3)" "FAIL" "$count/$total Pod(s) with weak Security Context"
        fi
        echo ""
    }

    # --- Thực thi 3 automated + 3 manual checks ---
    audit_4_1_5
    audit_4_1_7
    audit_manual_4_4_1
    audit_manual_4_5_1
    audit_manual_4_6_1
    audit_4_6_3

    # ---- CHẠY MODULE 5 (REMEDIATION) ----
    if [[ "$DO_REMEDIATE" == "true" ]]; then
        source "${SCRIPT_DIR}/modules/module5_remediation.sh"
    else
        if [[ "$AUDIT_LANG" == "en" ]]; then
            log_info "Skipping Auto Remediation. Use --remediate flag to generate remediation script."
        else
            log_info "Bỏ qua tạo Remediation script. Dùng cờ --remediate để tự động tạo."
        fi
    fi

    # ---- TỔNG KẾT & XUẤT BÁO CÁO ----
    print_summary_table

    mkdir -p "$OUTPUT_DIR"
    export_csv  "$OUTPUT_CSV"
    export_html "$OUTPUT_HTML"

    echo ""
    log_pass "$(t ALL_DONE)"
    echo ""
    log_info "📄 CSV  → $OUTPUT_CSV"
    log_info "🌐 HTML → $OUTPUT_HTML"
    echo ""
}

main
