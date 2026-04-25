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
export PROJECT_ID="${PROJECT_ID:-project-b446ffba-838e-4ec0-a4b}"
export CLUSTER_NAME="${CLUSTER_NAME:-vuln-autopilot-lab}"
export LOCATION="${LOCATION:-asia-southeast1}"
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
            log_error "$(printf "$(t DEP_MISSING)" "$cmd")"
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
        else
            log_pass "$(printf "$(t AUTH_OK)" "$ACCOUNT")"
        fi
    fi

    log_info "$(printf "$(t CONNECT_CLUSTER)" "$CLUSTER_NAME")"
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
    log_info "Language : $(t LANG_CURRENT)"
    log_info "Time     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    check_dependencies
    authenticate_gcp

    # ---- CHẠY 4 MODULE CHÍNH ----
    source "${SCRIPT_DIR}/modules/module1_iam_rbac.sh"
    source "${SCRIPT_DIR}/modules/module2_networking.sh"
    source "${SCRIPT_DIR}/modules/module3_workload.sh"
    source "${SCRIPT_DIR}/modules/module4_image.sh"

    # ---- THÊM CÁC MỤC KIỂM TRA THỦ CÔNG ----
    log_info "Bổ sung 7 mục kiểm tra thủ công (Manual) vào báo cáo..."
    if [[ "$AUDIT_LANG" == "en" ]]; then
        record_result "4.1.5" "$(cis_title 4_1_5)" "MANUAL" "Review Pod specs for automountServiceAccountToken: false"
        record_result "4.1.6" "$(cis_title 4_1_6)" "MANUAL" "Review RBAC for system:masters usage"
        record_result "4.1.7" "$(cis_title 4_1_7)" "MANUAL" "Review ClusterRoles for bind/impersonate/escalate"
        record_result "4.4.1" "$(cis_title 4_4_1)" "MANUAL" "Consider Secret Store CSI Driver or HashiCorp Vault"
        record_result "4.5.1" "$(cis_title 4_5_1)" "MANUAL" "Verify ImagePolicyWebhook is configured"
        record_result "4.6.1" "$(cis_title 4_6_1)" "MANUAL" "Verify namespace boundaries"
        record_result "4.6.3" "$(cis_title 4_6_3)" "MANUAL" "Verify Pod Security Context (runAsNonRoot, etc.)"
    else
        record_result "4.1.5" "$(cis_title 4_1_5)" "MANUAL" "Kiểm tra thủ công: Đảm bảo Service Account Tokens chỉ mount khi cần thiết"
        record_result "4.1.6" "$(cis_title 4_1_6)" "MANUAL" "Kiểm tra thủ công: Tránh sử dụng nhóm system:masters"
        record_result "4.1.7" "$(cis_title 4_1_7)" "MANUAL" "Kiểm tra thủ công: Hạn chế quyền Bind, Impersonate và Escalate"
        record_result "4.4.1" "$(cis_title 4_4_1)" "MANUAL" "Kiểm tra thủ công: Cân nhắc sử dụng external secret storage"
        record_result "4.5.1" "$(cis_title 4_5_1)" "MANUAL" "Kiểm tra thủ công: Cấu hình Image Provenance với ImagePolicyWebhook"
        record_result "4.6.1" "$(cis_title 4_6_1)" "MANUAL" "Kiểm tra thủ công: Tạo ranh giới quản trị bằng namespaces"
        record_result "4.6.3" "$(cis_title 4_6_3)" "MANUAL" "Kiểm tra thủ công: Áp dụng Security Context cho Pods/Containers"
    fi

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
