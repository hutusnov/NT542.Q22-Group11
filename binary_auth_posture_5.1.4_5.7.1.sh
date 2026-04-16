#!/bin/bash
# CÁC HÀM IN MÀU
RED='\033[0;31m' ; GREEN='\033[0;32m' ; YELLOW='\033[1;33m' ; BLUE='\033[0;34m' ; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $1"; } ; pass() { echo -e "${GREEN}[PASS]${NC} $1"; } ; fail() { echo -e "${RED}[FAIL]${NC} $1"; }

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
CLUSTER_NAME="vuln-autopilot-lab" 
LOCATION="asia-southeast1"

info "====================================================="
info " SCRIPT 3: KIỂM TRA 5.1.4 & 5.7.1 (BIN AUTH & POSTURE) "
info "====================================================="

# Kiểm tra Binary Authorization
BIN_AUTH=$(gcloud container clusters describe "$CLUSTER_NAME" --location "$LOCATION" --project "$PROJECT_ID" --format json 2>/dev/null | jq -r '.binaryAuthorization.evaluationMode')
if [[ "$BIN_AUTH" == "PROJECT_SINGLETON_POLICY_ENFORCE" ]]; then
    pass "[5.1.4] Binary Authorization ĐÃ BẬT (Chế độ ENFORCE)."
else
    fail "[5.1.4] Binary Authorization CHƯA BẬT (Trạng thái: $BIN_AUTH)."
fi

# Kiểm tra Security Posture
POSTURE=$(gcloud container clusters describe "$CLUSTER_NAME" --location "$LOCATION" --project "$PROJECT_ID" --format json 2>/dev/null | jq -r '.securityPostureConfig.mode')
if [[ "$POSTURE" == "BASIC" || "$POSTURE" == "ENTERPRISE" ]]; then
    pass "[5.7.1] Security Posture ĐÃ BẬT (Chế độ: $POSTURE)."
else
    fail "[5.7.1] Security Posture CHƯA BẬT (Trạng thái: $POSTURE)."
fi
