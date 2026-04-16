#!/bin/bash
# CÁC HÀM IN MÀU
RED='\033[0;31m' ; GREEN='\033[0;32m' ; YELLOW='\033[1;33m' ; BLUE='\033[0;34m' ; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $1"; } ; pass() { echo -e "${GREEN}[PASS]${NC} $1"; } ; fail() { echo -e "${RED}[FAIL]${NC} $1"; } ; warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

info "====================================================="
info " SCRIPT 2: KIỂM TRA 5.1.2 & 5.1.3 (IAM REPOSITORIES) "
info "====================================================="
AR_REPOS=$(gcloud artifacts repositories list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null)

if [ -z "$AR_REPOS" ]; then
    warn "[5.1.2 & 5.1.3] Không tìm thấy Artifact Registry repository nào. Bỏ qua."
else
    for repo in $AR_REPOS; do
        loc=$(gcloud artifacts repositories describe "$repo" --project="$PROJECT_ID" --format="value(location)")
        policies=$(gcloud artifacts repositories get-iam-policy "$repo" --location="$loc" --project="$PROJECT_ID" --format=json)
        
        if echo "$policies" | grep -q "allUsers"; then
            fail "[5.1.2] CẢNH BÁO: Repository '$repo' đang mở public (allUsers)!"
        else
            pass "[5.1.2 & 5.1.3] Repository '$repo' không public. Đạt kiểm tra sơ bộ (Cần review tay thêm theo CIS)."
        fi
    done
fi
