#!/bin/bash

# Load các hàm từ logger.sh
source ./utils/logger.sh

# Kiểm tra môi trường, xác thực với Google Cloud và gọi các module khác.
# ==========================================
# CẤU HÌNH BIẾN MÔI TRƯỜNG
# ==========================================
export PROJECT_ID="${PROJECT_ID:project-b446ffba-838e-4ec0-a4b}"
export CLUSTER_NAME="${CLUSTER_NAME:vuln-autopilot-lab}"
export LOCATION="${LOCATION:-asia-southeast1}"

# ==========================================
# HÀM KIỂM TRA PHỤ THUỘC (DEPENDENCIES)
# ==========================================
check_dependencies() {
    log_info "Đang kiểm tra các công cụ phụ thuộc..."
    
    local deps=("gcloud" "kubectl" "jq")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Không tìm thấy '$cmd'. Vui lòng cài đặt trước khi chạy script."
            exit 1
        fi
    done
    log_pass "Tất cả công cụ (gcloud, kubectl, jq) đã sẵn sàng."
}

# ==========================================
# HÀM XÁC THỰC VÀ KẾT NỐI GCP
# ==========================================
authenticate_gcp() {
    log_info "Đang xác thực với Google Cloud Platform..."
    
    # Nếu đang chạy trên GitHub Actions (biến môi trường CI = true)
    if [ "$CI" == "true" ]; then
        log_info "Đang chạy trên môi trường CI/CD. Bỏ qua xác thực trình duyệt."
        # GitHub Actions đã tự xác thực bằng Secret JSON, nên chỉ cần kết nối Cluster
    else
        # Chạy trên máy tính cá nhân
        ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
        if [ -z "$ACCOUNT" ]; then
            log_info "Chưa có phiên đăng nhập. Mở trình duyệt để xác thực..."
            gcloud auth login
        else
            log_pass "Đã xác thực với tài khoản: $ACCOUNT"
        fi
    fi

    log_info "Kết nối tới cụm GKE Autopilot: $CLUSTER_NAME..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --location="$LOCATION" --project="$PROJECT_ID" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_pass "Kết nối cụm thành công."
    else
        log_error "Không thể kết nối cụm. Vui lòng kiểm tra lại PROJECT_ID, CLUSTER_NAME hoặc quyền IAM."
        exit 1
    fi
}

# ==========================================
# LUỒNG THỰC THI CHÍNH
# ==========================================
main() {
    clear
    log_header "CIS GKE AUTOPILOT BENCHMARK V1.3.0 AUDIT TOOL"
    
    check_dependencies
    authenticate_gcp

    # Chỗ này để gọi các script con do các thành viên khác viết
    # Ví dụ:
    # log_header "Chương 4.1: RBAC và Service Accounts (Thành viên 2)"
    # bash ./modules/iam_audit.sh
    
    # log_header "Chương 4.3 & 5.4: Cluster Networking (Thành viên 3)"
    # bash ./modules/network_audit.sh
    
    log_info "Hoàn tất quá trình rà soát!"
}

# Gọi hàm main
main
