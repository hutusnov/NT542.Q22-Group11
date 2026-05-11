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
    log_info "Bổ sung 6 mục kiểm tra thủ công (Manual) vào báo cáo..."
    echo ""

    # =========================================================================
    # CIS 4.1.5 — Ensure SA Tokens are only mounted where necessary (Manual)
    # =========================================================================
    audit_manual_4_1_5() {
        log_subheader "$(cis_title 4_1_5)"

        local pods_automount
        pods_automount=$(kubectl get pods -A -o json 2>/dev/null | jq -r '
            .items[] | select(
                (.spec.automountServiceAccountToken // true) == true
            ) | "  \(.metadata.namespace)/\(.metadata.name)  [automount=true]"
        ')

        local count
        count=$(echo "$pods_automount" | grep -c "." 2>/dev/null || echo 0)

        if [[ $count -eq 0 ]]; then
            log_pass "All Pods have automountServiceAccountToken disabled."
            record_result "4.1.5" "$(cis_title 4_1_5)" "MANUAL" "All Pods set automountServiceAccountToken: false"
        else
            log_manual "Found $count Pod(s) with automountServiceAccountToken: true (or default):"
            echo "$pods_automount" | head -15
            [[ $count -gt 15 ]] && echo "    ... and $(( count - 15 )) more"
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Ensure pods explicitly set automountServiceAccountToken: false if not using Kubernetes API."
            else
                echo "    # $(t REMEDIATION) Đảm bảo các pod có thiết lập automountServiceAccountToken: false nếu không cần giao tiếp với API."
            fi
            record_result "4.1.5" "$(cis_title 4_1_5)" "MANUAL" "$count Pod(s) with automountServiceAccountToken: true — review required"
        fi
        echo ""
    }

    # =========================================================================
    # CIS 4.1.7 — Limit Bind, Impersonate and Escalate permissions (Manual)
    # =========================================================================
    audit_manual_4_1_7() {
        log_subheader "$(cis_title 4_1_7)"

        local risky_roles
        risky_roles=$(kubectl get clusterroles -o json 2>/dev/null | jq -r '
            .items[] | select(
                .rules[]? | .verbs[]? | test("bind|impersonate|escalate")
            ) | "  ClusterRole/\(.metadata.name)"
        ')

        local count
        count=$(echo "$risky_roles" | grep -c "." 2>/dev/null || echo 0)

        if [[ $count -eq 0 ]]; then
            log_pass "No ClusterRole found with bind/impersonate/escalate permissions."
            record_result "4.1.7" "$(cis_title 4_1_7)" "MANUAL" "No risky verbs found"
        else
            log_manual "Found $count ClusterRole(s) with bind/impersonate/escalate:"
            echo "$risky_roles"
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Restrict these permissions to trusted administrators only."
            else
                echo "    # $(t REMEDIATION) Giới hạn các quyền rủi ro cao này chỉ cho admin thực sự."
            fi
            record_result "4.1.7" "$(cis_title 4_1_7)" "MANUAL" "$count ClusterRole(s) with bind/impersonate/escalate — review required"
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
            log_pass "External secret management components detected:"
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
            log_pass "User-created namespaces detected — administrative boundaries exist."
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
    # CIS 4.6.3 — Apply Security Context to Pods and Containers (Manual)
    # =========================================================================
    audit_manual_4_6_3() {
        log_subheader "$(cis_title 4_6_3)"

        local pods_no_sc
        pods_no_sc=$(kubectl get pods -A -o json 2>/dev/null | jq -r '
            .items[] | select(
                (.spec.securityContext == null or .spec.securityContext == {})
                and ([.spec.containers[]? | select(
                    .securityContext == null or .securityContext == {}
                )] | length > 0)
            ) | "  \(.metadata.namespace)/\(.metadata.name)"
        ')

        local count
        count=$(echo "$pods_no_sc" | grep -c "." 2>/dev/null || echo 0)

        local total
        total=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [[ $count -eq 0 ]]; then
            log_pass "All $total Pod(s) have Security Context configured."
            record_result "4.6.3" "$(cis_title 4_6_3)" "MANUAL" "All $total Pods have Security Context"
        else
            log_manual "Found $count/$total Pod(s) without Security Context:"
            echo "$pods_no_sc" | head -15
            [[ $count -gt 15 ]] && echo "    ... and $(( count - 15 )) more"
            echo ""
            if [[ "$AUDIT_LANG" == "en" ]]; then
                echo "    # $(t REMEDIATION) Ensure Pods and Containers apply strict Security Contexts (runAsNonRoot, readOnlyRootFilesystem, etc.)."
            else
                echo "    # $(t REMEDIATION) Đảm bảo Pods và Containers có áp dụng các ràng buộc Security Context chặt chẽ (runAsNonRoot, readOnlyRootFilesystem, v.v.)."
            fi
            record_result "4.6.3" "$(cis_title 4_6_3)" "MANUAL" "$count/$total Pod(s) missing Security Context — review required"
        fi
        echo ""
    }

    # --- Thực thi 6 manual checks ---
    audit_manual_4_1_5
    audit_manual_4_1_7
    audit_manual_4_4_1
    audit_manual_4_5_1
    audit_manual_4_6_1
    audit_manual_4_6_3

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
