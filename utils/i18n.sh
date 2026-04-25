#!/usr/bin/env bash
# =============================================================================
# utils/i18n.sh — Bilingual Message Management (vi / en)
# CIS GKE Autopilot Benchmark v1.3.0 Audit Tool
# =============================================================================
# Cách dùng:
#   export AUDIT_LANG="en"   # Chọn tiếng Anh
#   export AUDIT_LANG="vi"   # Chọn tiếng Việt (mặc định)
#   source utils/i18n.sh
#   log_subheader "$(cis_title 4_1_1)"
#   log_pass "$(t MSG_NO_BINDING)"
# =============================================================================

AUDIT_LANG="${AUDIT_LANG:-vi}"

# =============================================================================
# CIS Check Titles — Bilingual
# Key format: <section>_<subsection> (dots replaced with underscores)
# =============================================================================
declare -A _CIS_TITLE_VI=(
    # Module 1 — IAM & RBAC
    ["4_1_1"]="CIS 4.1.1 | cluster-admin role — Chỉ dùng khi thực sự cần"
    ["4_1_2"]="CIS 4.1.2 | Hạn chế quyền truy cập Secrets"
    ["4_1_3"]="CIS 4.1.3 | Hạn chế dùng wildcard (*) trong Roles & ClusterRoles"
    ["4_1_4"]="CIS 4.1.4 | Default Service Account không được tự động mount token"
    ["4_1_5"]="CIS 4.1.5 | Service Account Tokens chỉ mount khi cần thiết"
    ["4_1_6"]="CIS 4.1.6 | Tránh sử dụng nhóm system:masters"
    ["4_1_7"]="CIS 4.1.7 | Hạn chế quyền Bind, Impersonate và Escalate"
    ["4_1_8"]="CIS 4.1.8 | Không bind role cho system:anonymous"
    ["4_1_9"]="CIS 4.1.9 | Không có binding non-default cho system:unauthenticated"
    ["4_1_10"]="CIS 4.1.10 | Không có binding non-default cho system:authenticated"
    ["5_5_1"]="CIS 5.5.1 | Quản lý RBAC bằng Google Groups for GKE"
    # Module 2 — Networking
    ["4_3_1"]="CIS 4.3.1 | Tất cả Namespace phải có Network Policy"
    ["5_4_1"]="CIS 5.4.1 | VPC Flow Logs & Intranode Visibility"
    ["5_4_2"]="CIS 5.4.2 | Control Plane Authorized Networks"
    ["5_4_3"]="CIS 5.4.3 | Private Endpoint bật & Public Access tắt"
    ["5_4_4"]="CIS 5.4.4 | Cluster dùng Private Nodes"
    ["5_4_5"]="CIS 5.4.5 | Google-managed SSL Certificates"
    # Module 3 — Workload, Secrets & Storage
    ["4_4_1"]="CIS 4.4.1 | Sử dụng external secret storage (Khuyến nghị)"
    ["4_6_1"]="CIS 4.6.1 | Phân tách quản trị bằng Namespaces"
    ["4_6_2"]="CIS 4.6.2 | Seccomp Profile = RuntimeDefault"
    ["4_6_3"]="CIS 4.6.3 | Áp dụng Security Context cho Pods/Containers"
    ["4_6_4"]="CIS 4.6.4 | Không dùng namespace default cho workload"
    ["5_2_1"]="CIS 5.2.1 | Không dùng Compute Engine Default Service Account"
    ["5_3_1"]="CIS 5.3.1 | Secrets mã hoá bằng Cloud KMS (CMEK)"
    ["5_6_1"]="CIS 5.6.1 | CMEK cho Persistent Disks"
    # Module 4 — Image Security & Managed Services
    ["5_1_1"]="CIS 5.1.1 | Image Vulnerability Scanning đã bật"
    ["5_1_2"]="CIS 5.1.2 | Hạn chế quyền truy cập Image Repository (user)"
    ["5_1_3"]="CIS 5.1.3 | Cluster chỉ có quyền read-only vào Image Repository"
    ["5_1_4"]="CIS 5.1.4 | Binary Authorization đã bật"
    ["5_7_1"]="CIS 5.7.1 | Security Posture đã bật"
    ["4_5_1"]="CIS 4.5.1 | Image Provenance (ImagePolicyWebhook)"
)

declare -A _CIS_TITLE_EN=(
    # Module 1 — IAM & RBAC
    ["4_1_1"]="CIS 4.1.1 | cluster-admin role — Only used where required"
    ["4_1_2"]="CIS 4.1.2 | Minimize access to secrets"
    ["4_1_3"]="CIS 4.1.3 | Minimize wildcard use in Roles and ClusterRoles"
    ["4_1_4"]="CIS 4.1.4 | Default service accounts are not actively used"
    ["4_1_5"]="CIS 4.1.5 | Service Account Tokens only mounted where necessary"
    ["4_1_6"]="CIS 4.1.6 | Avoid use of system:masters group"
    ["4_1_7"]="CIS 4.1.7 | Limit use of Bind, Impersonate and Escalate permissions"
    ["4_1_8"]="CIS 4.1.8 | Avoid bindings to system:anonymous"
    ["4_1_9"]="CIS 4.1.9 | Avoid non-default bindings to system:unauthenticated"
    ["4_1_10"]="CIS 4.1.10 | Avoid non-default bindings to system:authenticated"
    ["5_5_1"]="CIS 5.5.1 | Manage Kubernetes RBAC users with Google Groups for GKE"
    # Module 2 — Networking
    ["4_3_1"]="CIS 4.3.1 | All Namespaces have Network Policies defined"
    ["5_4_1"]="CIS 5.4.1 | Enable VPC Flow Logs and Intranode Visibility"
    ["5_4_2"]="CIS 5.4.2 | Control Plane Authorized Networks is Enabled"
    ["5_4_3"]="CIS 5.4.3 | Private Endpoint Enabled and Public Access Disabled"
    ["5_4_4"]="CIS 5.4.4 | Clusters created with Private Nodes"
    ["5_4_5"]="CIS 5.4.5 | Use of Google-managed SSL Certificates"
    # Module 3 — Workload, Secrets & Storage
    ["4_4_1"]="CIS 4.4.1 | Consider external secret storage"
    ["4_6_1"]="CIS 4.6.1 | Create administrative boundaries between resources using namespaces"
    ["4_6_2"]="CIS 4.6.2 | Seccomp profile set to RuntimeDefault in pod definitions"
    ["4_6_3"]="CIS 4.6.3 | Apply Security Context to Pods and Containers"
    ["4_6_4"]="CIS 4.6.4 | Default namespace should not be used"
    ["5_2_1"]="CIS 5.2.1 | GKE clusters not running using Compute Engine default service account"
    ["5_3_1"]="CIS 5.3.1 | Kubernetes Secrets encrypted using keys managed in Cloud KMS"
    ["5_6_1"]="CIS 5.6.1 | Customer-Managed Encryption Keys (CMEK) for GKE Persistent Disks"
    # Module 4 — Image Security & Managed Services
    ["5_1_1"]="CIS 5.1.1 | Image Vulnerability Scanning is enabled"
    ["5_1_2"]="CIS 5.1.2 | Minimize user access to Container Image repositories"
    ["5_1_3"]="CIS 5.1.3 | Minimize cluster access to read-only for Image repositories"
    ["5_1_4"]="CIS 5.1.4 | Only trusted container images are used (Binary Authorization)"
    ["5_7_1"]="CIS 5.7.1 | Security Posture is enabled"
    ["4_5_1"]="CIS 4.5.1 | Configure Image Provenance using ImagePolicyWebhook"
)

# =============================================================================
# Module Headers — Bilingual
# =============================================================================
declare -A _MOD_HEADER_VI=(
    ["M1"]="MODULE 1 — QUẢN LÝ DANH TÍNH & QUYỀN HẠN (IAM & RBAC)"
    ["M2"]="MODULE 2 — MẠNG & CÁCH LY (NETWORKING & CNI)"
    ["M3"]="MODULE 3 — WORKLOAD, SECRETS & STORAGE"
    ["M4"]="MODULE 4 — BẢO MẬT IMAGE & DỊCH VỤ QUẢN LÝ"
    ["M5"]="MODULE 5 — KHẮC PHỤC TỰ ĐỘNG (REMEDIATION)"
    ["SUMMARY"]="KẾT QUẢ TỔNG HỢP — CIS GKE Autopilot Benchmark v1.3.0"
    ["MAIN"]="CIS GKE AUTOPILOT BENCHMARK V1.3.0 — CÔNG CỤ KIỂM TRA BẢO MẬT TỰ ĐỘNG"
)
declare -A _MOD_HEADER_EN=(
    ["M1"]="MODULE 1 — IDENTITY & ACCESS MANAGEMENT (IAM & RBAC)"
    ["M2"]="MODULE 2 — NETWORKING & ISOLATION (CNI)"
    ["M3"]="MODULE 3 — WORKLOAD, SECRETS & STORAGE"
    ["M4"]="MODULE 4 — IMAGE SECURITY & MANAGED SERVICES"
    ["M5"]="MODULE 5 — AUTO REMEDIATION"
    ["SUMMARY"]="SUMMARY RESULTS — CIS GKE Autopilot Benchmark v1.3.0"
    ["MAIN"]="CIS GKE AUTOPILOT BENCHMARK V1.3.0 — AUTOMATED SECURITY AUDIT TOOL"
)

# =============================================================================
# Generic Messages — Bilingual
# =============================================================================
declare -A _MSG_VI=(
    # Common
    ["LOADING_CLUSTER"]="Đang tải cấu hình cluster từ GCP (vui lòng đợi)..."
    ["LOAD_OK"]="Đã tải cấu hình cluster thành công."
    ["LOAD_FAIL"]="Không thể lấy thông tin cluster. Kiểm tra PROJECT_ID, CLUSTER_NAME, LOCATION."
    ["REMEDIATION"]="Hướng dẫn khắc phục:"
    ["TOTAL_PODS"]="Tổng số Pod tìm thấy"
    ["NO_PODS"]="Không có Pod nào trong cluster."
    ["NO_PV"]="Không có Persistent Volume nào trong cluster."
    ["TOTAL_PV"]="Tổng Persistent Volume"
    ["CHECKING_DEPS"]="Đang kiểm tra các công cụ phụ thuộc..."
    ["DEPS_OK"]="Tất cả công cụ (gcloud, kubectl, jq) đã sẵn sàng."
    ["DEP_MISSING"]="Không tìm thấy '%s'. Vui lòng cài đặt trước khi chạy script."
    ["AUTH_GCP"]="Đang xác thực với Google Cloud Platform..."
    ["AUTH_CI"]="Đang chạy trên môi trường CI/CD. Bỏ qua xác thực trình duyệt."
    ["AUTH_NO_SESSION"]="Chưa có phiên đăng nhập. Mở trình duyệt để xác thực..."
    ["AUTH_OK"]="Đã xác thực với tài khoản: %s"
    ["CONNECT_CLUSTER"]="Kết nối tới cụm GKE: %s..."
    ["CONNECT_OK"]="Kết nối cụm thành công."
    ["CONNECT_FAIL"]="Không thể kết nối cụm. Kiểm tra PROJECT_ID, CLUSTER_NAME hoặc quyền IAM."
    ["DONE_MODULE"]="✔ %s — Hoàn tất."
    ["ALL_DONE"]="Hoàn tất kiểm tra toàn bộ hệ thống!"
    ["REPORT_CSV"]="Đã xuất báo cáo CSV: %s"
    ["REPORT_HTML"]="Đã xuất báo cáo HTML: %s"
    ["PASS_RATE"]="Tỷ lệ đạt (Automated PASS)"
    ["ALL_PASS"]="Cluster đạt tất cả kiểm tra tự động CIS GKE v1.3.0!"
    ["HAS_FAIL"]="Có %d mục THẤT BẠI — cần khắc phục trước khi go-live."
    ["TOTAL_CHECKS"]="Tổng mục"
    ["COL_CIS"]="CIS ID"
    ["COL_TITLE"]="Tên mục kiểm tra"
    ["COL_RESULT"]="Kết quả"
    ["COL_DETAIL"]="Chi tiết"
    ["HTML_SUBTITLE"]="Báo cáo kiểm tra bảo mật tự động theo tiêu chuẩn CIS Google Kubernetes Engine Autopilot Benchmark"
    ["HTML_TIME_LABEL"]="Thời gian kiểm tra"
    ["HTML_TABLE_TITLE"]="Chi tiết kết quả kiểm tra"
    ["HTML_FOOTER"]="Tạo bởi GKE CIS Audit Tool v1.3.0"
    ["LANG_CURRENT"]="Ngôn ngữ đầu ra: Tiếng Việt (vi)"
)
declare -A _MSG_EN=(
    # Common
    ["LOADING_CLUSTER"]="Loading cluster configuration from GCP (please wait)..."
    ["LOAD_OK"]="Cluster configuration loaded successfully."
    ["LOAD_FAIL"]="Cannot retrieve cluster info. Check PROJECT_ID, CLUSTER_NAME, LOCATION."
    ["REMEDIATION"]="Remediation steps:"
    ["TOTAL_PODS"]="Total Pods found"
    ["NO_PODS"]="No Pods found in the cluster."
    ["NO_PV"]="No Persistent Volumes found in the cluster."
    ["TOTAL_PV"]="Total Persistent Volumes"
    ["CHECKING_DEPS"]="Checking required tools..."
    ["DEPS_OK"]="All tools (gcloud, kubectl, jq) are ready."
    ["DEP_MISSING"]="'%s' not found. Please install it before running this script."
    ["AUTH_GCP"]="Authenticating with Google Cloud Platform..."
    ["AUTH_CI"]="Running in CI/CD environment. Skipping browser authentication."
    ["AUTH_NO_SESSION"]="No active session. Opening browser for authentication..."
    ["AUTH_OK"]="Authenticated with account: %s"
    ["CONNECT_CLUSTER"]="Connecting to GKE cluster: %s..."
    ["CONNECT_OK"]="Cluster connected successfully."
    ["CONNECT_FAIL"]="Cannot connect to cluster. Check PROJECT_ID, CLUSTER_NAME or IAM permissions."
    ["DONE_MODULE"]="✔ %s — Completed."
    ["ALL_DONE"]="All security checks completed!"
    ["REPORT_CSV"]="CSV report exported: %s"
    ["REPORT_HTML"]="HTML report exported: %s"
    ["PASS_RATE"]="Pass rate (Automated PASS)"
    ["ALL_PASS"]="Cluster passed all automated CIS GKE v1.3.0 checks!"
    ["HAS_FAIL"]="Found %d FAILED checks — remediation required before go-live."
    ["TOTAL_CHECKS"]="Total checks"
    ["COL_CIS"]="CIS ID"
    ["COL_TITLE"]="Check Name"
    ["COL_RESULT"]="Result"
    ["COL_DETAIL"]="Detail"
    ["HTML_SUBTITLE"]="Automated security audit report following CIS Google Kubernetes Engine Autopilot Benchmark"
    ["HTML_TIME_LABEL"]="Audit time"
    ["HTML_TABLE_TITLE"]="Detailed check results"
    ["HTML_FOOTER"]="Generated by GKE CIS Audit Tool v1.3.0"
    ["LANG_CURRENT"]="Output language: English (en)"
)

# =============================================================================
# cis_title <key>  — Trả về tên mục CIS theo ngôn ngữ hiện tại
#   Ví dụ: cis_title 4_1_1  →  "CIS 4.1.1 | cluster-admin role ..."
# =============================================================================
cis_title() {
    local key="$1"
    if [[ "$AUDIT_LANG" == "en" ]]; then
        echo "${_CIS_TITLE_EN[$key]:-${_CIS_TITLE_VI[$key]:-CIS $key}}"
    else
        echo "${_CIS_TITLE_VI[$key]:-${_CIS_TITLE_EN[$key]:-CIS $key}}"
    fi
}

# =============================================================================
# mod_header <key>  — Trả về tiêu đề module theo ngôn ngữ hiện tại
#   Ví dụ: mod_header M1  →  "MODULE 1 — QUẢN LÝ DANH TÍNH..."
# =============================================================================
mod_header() {
    local key="$1"
    if [[ "$AUDIT_LANG" == "en" ]]; then
        echo "${_MOD_HEADER_EN[$key]:-${_MOD_HEADER_VI[$key]:-$key}}"
    else
        echo "${_MOD_HEADER_VI[$key]:-${_MOD_HEADER_EN[$key]:-$key}}"
    fi
}

# =============================================================================
# t <key> [arg1] [arg2]  — Translate a generic message key
#   Ví dụ: t MSG_LOAD_OK
#           t MSG_DEP_MISSING "gcloud"
#           t MSG_HAS_FAIL 3
# =============================================================================
t() {
    local key="$1"; shift
    local tpl
    if [[ "$AUDIT_LANG" == "en" ]]; then
        tpl="${_MSG_EN[$key]:-${_MSG_VI[$key]:-$key}}"
    else
        tpl="${_MSG_VI[$key]:-${_MSG_EN[$key]:-$key}}"
    fi
    # shellcheck disable=SC2059
    printf "$tpl" "$@"
}

# --- Thông báo ngôn ngữ hiện tại khi load ---
# (Chỉ hiển thị khi script được chạy trực tiếp, không phải source từ main)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "[i18n] $(t LANG_CURRENT)"
fi
