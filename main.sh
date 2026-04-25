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

    # ---- CHẠY 4 MODULE ----
    source "${SCRIPT_DIR}/modules/module1_iam_rbac.sh"
    source "${SCRIPT_DIR}/modules/module2_networking.sh"
    source "${SCRIPT_DIR}/modules/module3_workload.sh"
    source "${SCRIPT_DIR}/modules/module4_image.sh"

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
