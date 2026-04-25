#!/usr/bin/env bash
# =============================================================================
# multi_audit.sh — Công cụ chạy CIS Audit cho TẤT CẢ các cụm GKE trong Project
# =============================================================================

# 1. Xác định Project
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"

if [[ -z "$PROJECT_ID" ]]; then
    echo "❌ Lỗi: Không tìm thấy PROJECT_ID."
    echo "Vui lòng thiết lập biến môi trường (VD: export PROJECT_ID=my-project)"
    exit 1
fi

echo "🔍 Đang tìm kiếm các GKE cluster trong project: [$PROJECT_ID]..."
CLUSTERS=$(gcloud container clusters list --project="$PROJECT_ID" --format="value(name,location)" 2>/dev/null)

if [[ -z "$CLUSTERS" ]]; then
    echo "⚠️ Không tìm thấy GKE cluster nào trong project $PROJECT_ID."
    exit 0
fi

# Đếm số lượng cluster
COUNT=$(echo "$CLUSTERS" | wc -l)
echo "✅ Tìm thấy $COUNT cluster. Chuẩn bị tiến hành audit tuần tự..."
echo "================================================================="

# 2. Duyệt qua từng cụm và chạy main.sh
while read -r CLUSTER_NAME LOCATION; do
    if [[ -z "$CLUSTER_NAME" ]]; then
        continue
    fi
    
    echo "🚀 BẮT ĐẦU KIỂM TRA CLUSTER: $CLUSTER_NAME (Location: $LOCATION)"
    
    # Lấy thông tin kubeconfig (cần thiết để module dùng kubectl)
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --location="$LOCATION" \
        --project="$PROJECT_ID" \
        --quiet 2>/dev/null
        
    # Chạy công cụ kiểm tra (chuyển tiếp các tham số nếu có, ví dụ: --remediate)
    PROJECT_ID="$PROJECT_ID" CLUSTER_NAME="$CLUSTER_NAME" LOCATION="$LOCATION" bash main.sh "$@"
    
    echo "================================================================="
done <<< "$CLUSTERS"

echo "🎉 HOÀN TẤT! Đã quét thành công $COUNT cluster."
echo "📂 Xem các báo cáo được tạo ra trong thư mục output/"
