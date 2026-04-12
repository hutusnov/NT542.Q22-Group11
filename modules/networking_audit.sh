#!/bin/bash

# --- CẤU HÌNH ---
PROJECT_ID="${PROJECT_ID:-project-b446ffba-838e-4ec0-a4b}"
CLUSTER_NAME="${CLUSTER_NAME:-vuln-autopilot-lab}"
LOCATION="${LOCATION:-asia-southeast1}"

# Nạp logger nếu script được chạy độc lập.
if ! command -v log_info >/dev/null 2>&1; then
    if [ -f "./utils/logger.sh" ]; then
        source ./utils/logger.sh
    elif [ -f "../utils/logger.sh" ]; then
        source ../utils/logger.sh
    fi
fi

log_header "BẮT ĐẦU KIỂM TRA BẢO MẬT MẠNG (NETWORKING)"
log_info "Cluster: $CLUSTER_NAME | Location: $LOCATION"

log_info "Đang tải thông tin cấu hình từ Google Cloud (vui lòng đợi vài giây)..."
# TỐI ƯU HÓA: Lấy data 1 lần duy nhất để script chạy nhanh hơn
CLUSTER_DATA=$(gcloud container clusters describe "$CLUSTER_NAME" --location "$LOCATION" --project "$PROJECT_ID" --format=json 2>/dev/null)

if [ -z "$CLUSTER_DATA" ]; then
    log_error "Không thể lấy thông tin cụm. Vui lòng kiểm tra lại tên cụm hoặc kết nối!"
    exit 1
fi

# 1. Kiểm tra VPC Flow Logs (Mục 2001)
log_info "Mục 2001: Enable VPC Flow Logs"
FLOW_LOGS=$(echo "$CLUSTER_DATA" | jq -r '.networkConfig.enableIntraNodeVisibility')
if [ "$FLOW_LOGS" == "true" ]; then
    log_pass "CIS 2001: Đã bật ghi log mạng."
else
    log_fail "CIS 2001: Chưa bật ghi log mạng."
fi

# 2. Kiểm tra Authorized Networks (Mục 2002)
log_info "Mục 2002: Ensure Control Plane Authorized Networks is Enabled"
AUTH_NETWORKS=$(echo "$CLUSTER_DATA" | jq -r '.masterAuthorizedNetworksConfig.enabled')
if [ "$AUTH_NETWORKS" == "true" ]; then
    log_pass "CIS 2002: Đã giới hạn IP truy cập Control Plane."
else
    log_fail "CIS 2002: Control Plane chưa giới hạn Authorized Networks."
fi

# 3. Kiểm tra Private Endpoint (Mục 2003)
log_info "Mục 2003: Ensure Private Endpoint Enabled"
PRIVATE_ENDPOINT=$(echo "$CLUSTER_DATA" | jq -r '.privateClusterConfig.enablePrivateEndpoint')
if [ "$PRIVATE_ENDPOINT" == "true" ]; then
    log_pass "CIS 2003: Private Endpoint đã bật."
else
    log_fail "CIS 2003: Control Plane còn Public (chưa bật Private Endpoint)."
fi

# 4. Kiểm tra Private Nodes (Mục 2004)
log_info "Mục 2004: Ensure clusters are created with Private Nodes"
PRIVATE_NODES=$(echo "$CLUSTER_DATA" | jq -r '.privateClusterConfig.enablePrivateNodes')
if [ "$PRIVATE_NODES" == "true" ]; then
    log_pass "CIS 2004: Đã bật Private Nodes."
else
    log_fail "CIS 2004: Đang dùng Public Nodes (chưa bật Private Nodes)."
fi

# 5. Kiểm tra Google-managed SSL Certificates (Mục 2005)
log_info "Mục 2005: Ensure use of Google-managed SSL Certificates"
SSL_CERT=$(kubectl get ingress --all-namespaces -o json 2>/dev/null | jq -r 'if .items | length > 0 then .items[].metadata.annotations["networking.gke.io/managed-certificates"] else "null" end')
if [ "$SSL_CERT" != "null" ] && [ -n "$SSL_CERT" ]; then
    log_pass "CIS 2005: Đang dùng chứng chỉ SSL managed của Google."
else
    log_fail "CIS 2005: Không tìm thấy Google-managed SSL certificate."
fi
log_header "HOÀN THÀNH KIỂM TRA PHẦN NETWORKING"
