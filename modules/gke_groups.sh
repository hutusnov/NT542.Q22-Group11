#!/bin/bash

echo "==== 5.5.1 Check Google Groups ===="

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | cut -d'_' -f4)
LOCATION=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | cut -d'_' -f3)
PROJECT_ID=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | cut -d'_' -f2)

GROUP_CONFIG=$(gcloud container clusters describe "$CLUSTER_NAME" \
    --location "$LOCATION" \
    --project "$PROJECT_ID" \
    --format="value(authenticatorGroupsConfig.enabled)")

if [ "$GROUP_CONFIG" == "True" ]; then
    GROUP_DOMAIN=$(gcloud container clusters describe "$CLUSTER_NAME" \
        --location "$LOCATION" \
        --project "$PROJECT_ID" \
        --format="value(authenticatorGroupsConfig.securityGroup)")
    
    echo "[PASS] Tính năng Google Groups for GKE ĐÃ ĐƯỢC kích hoạt."
    echo "Nhóm bảo mật hiện tại: $GROUP_DOMAIN"
else
    echo "[FAIL] Tính năng Google Groups for GKE CHƯA được kích hoạt."
fi