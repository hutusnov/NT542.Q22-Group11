#!/bin/bash

# --- CẤU HÌNH ---
PROJECT_ID="${PROJECT_ID:-project-b446ffba-838e-4ec0-a4b}"
CLUSTER_NAME="${CLUSTER_NAME:-vuln-autopilot-lab}"
LOCATION="${LOCATION:-asia-southeast1}"

# --- MÀU SẮC CHO ĐẦU RA ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Không màu

echo "========================================================="
echo "BẮT ĐẦU KIỂM TRA BẢO MẬT MẠNG (NETWORKING) CHO CỤM GKE..."
echo "Cluster: $CLUSTER_NAME | Location: $LOCATION"
echo "========================================================="

echo -e "${YELLOW}[...] Đang tải thông tin cấu hình từ Google Cloud (vui lòng đợi vài giây)...${NC}"
# TỐI ƯU HÓA: Lấy data 1 lần duy nhất để script chạy nhanh hơn
CLUSTER_DATA=$(gcloud container clusters describe "$CLUSTER_NAME" --location "$LOCATION" --project "$PROJECT_ID" --format=json 2>/dev/null)

if [ -z "$CLUSTER_DATA" ]; then
    echo -e "${RED}Lỗi: Không thể lấy thông tin cụm. Vui lòng kiểm tra lại tên cụm hoặc kết nối!${NC}"
    exit 1
fi

# 1. Kiểm tra VPC Flow Logs (Mục 2001)
echo -e "\n[*] Kiểm tra Mục 2001: Enable VPC Flow Logs..."
FLOW_LOGS=$(echo "$CLUSTER_DATA" | jq -r '.networkConfig.enableIntraNodeVisibility')
if [ "$FLOW_LOGS" == "true" ]; then
    echo -e "  -> KẾT QUẢ: ${GREEN}PASS${NC} (Đã bật ghi log mạng)"
else
    echo -e "  -> KẾT QUẢ: ${RED}FAIL${NC} (Chưa bật ghi log - Vi phạm CIS 2001)"
fi
echo "---------------------------------------------------------"

# 2. Kiểm tra Authorized Networks (Mục 2002)
echo "[*] Kiểm tra Mục 2002: Ensure Control Plane Authorized Networks is Enabled..."
AUTH_NETWORKS=$(echo "$CLUSTER_DATA" | jq -r '.masterAuthorizedNetworksConfig.enabled')
if [ "$AUTH_NETWORKS" == "true" ]; then
    echo -e "  -> KẾT QUẢ: ${GREEN}PASS${NC} (Đã giới hạn IP truy cập Control Plane)"
else
    echo -e "  -> KẾT QUẢ: ${RED}FAIL${NC} (Nguy hiểm - Mở toang Control Plane cho mọi IP - Vi phạm CIS 2002)"
fi
echo "---------------------------------------------------------"

# 3. Kiểm tra Private Endpoint (Mục 2003)
echo "[*] Kiểm tra Mục 2003: Ensure Private Endpoint Enabled..."
PRIVATE_ENDPOINT=$(echo "$CLUSTER_DATA" | jq -r '.privateClusterConfig.enablePrivateEndpoint')
if [ "$PRIVATE_ENDPOINT" == "true" ]; then
    echo -e "  -> KẾT QUẢ: ${GREEN}PASS${NC} (Control Plane được giấu kín)"
else
    echo -e "  -> KẾT QUẢ: ${RED}FAIL${NC} (Nguy hiểm - Control Plane đang Public - Vi phạm CIS 2003)"
fi
echo "---------------------------------------------------------"

# 4. Kiểm tra Private Nodes (Mục 2004)
echo "[*] Kiểm tra Mục 2004: Ensure clusters are created with Private Nodes..."
PRIVATE_NODES=$(echo "$CLUSTER_DATA" | jq -r '.privateClusterConfig.enablePrivateNodes')
if [ "$PRIVATE_NODES" == "true" ]; then
    echo -e "  -> KẾT QUẢ: ${GREEN}PASS${NC} (Hệ thống an toàn - Đã bật Private Nodes)"
else
    echo -e "  -> KẾT QUẢ: ${RED}FAIL${NC} (Nguy hiểm - Đang dùng Public Nodes - Vi phạm CIS 2004)"
fi
echo "---------------------------------------------------------"

# 5. Kiểm tra Google-managed SSL Certificates (Mục 2005)
echo "[*] Kiểm tra Mục 2005: Ensure use of Google-managed SSL Certificates..."
SSL_CERT=$(kubectl get ingress --all-namespaces -o json 2>/dev/null | jq -r 'if .items | length > 0 then .items[].metadata.annotations["networking.gke.io/managed-certificates"] else "null" end')
if [ "$SSL_CERT" != "null" ] && [ -n "$SSL_CERT" ]; then
    echo -e "  -> KẾT QUẢ: ${GREEN}PASS${NC} (Đang dùng chứng chỉ SSL của Google)"
else
    echo -e "  -> KẾT QUẢ: ${RED}FAIL${NC} (Không tìm thấy Google-managed SSL - Vi phạm CIS 2005)"
fi
echo "========================================================="
echo -e "${GREEN}HOÀN THÀNH KIỂM TRA PHẦN NETWORKING!${NC}"
echo "========================================================="
