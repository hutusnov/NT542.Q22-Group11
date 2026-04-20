#!/usr/bin/env bash

# Nạp logger nếu script được chạy độc lập.
if ! command -v log_info >/dev/null 2>&1; then
    if [ -f "./utils/logger.sh" ]; then
        source ./utils/logger.sh
    elif [ -f "../utils/logger.sh" ]; then
        source ../utils/logger.sh
    fi
fi

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
CLUSTER_NAME="${CLUSTER_NAME:-vuln-autopilot-lab}"
LOCATION="${LOCATION:-asia-southeast1}"

log_info "====================================================="
log_info " IMAGE SECURITY AUDIT: CIS 5.1.1 - 5.1.4, 5.7.1 "
log_info "====================================================="

# 5.1.1 - Vulnerability Scanning service
log_info "CIS 5.1.1: Vulnerability scanning services"
if gcloud services list --enabled --project "$PROJECT_ID" | grep -q "containerscanning.googleapis.com"; then
    log_pass "[5.1.1] Vulnerability Scanning (Artifact Registry) đã bật."
elif gcloud services list --enabled --project "$PROJECT_ID" | grep -q "containeranalysis.googleapis.com"; then
    log_pass "[5.1.1] Vulnerability Scanning (GCR) đã bật."
else
    log_fail "[5.1.1] Vulnerability Scanning chưa bật."
fi

# 5.1.2 - 5.1.3 - Repository IAM exposure
log_info "CIS 5.1.2 & 5.1.3: Artifact Registry IAM exposure"
AR_REPOS=$(gcloud artifacts repositories list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null)

if [ -z "$AR_REPOS" ]; then
    log_manual "[5.1.2 & 5.1.3] Không tìm thấy Artifact Registry repository nào."
else
    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        loc=$(gcloud artifacts repositories describe "$repo" --project="$PROJECT_ID" --format="value(location)" 2>/dev/null)
        policy=$(gcloud artifacts repositories get-iam-policy "$repo" --location="$loc" --project="$PROJECT_ID" --format=json 2>/dev/null)

        if echo "$policy" | grep -q "allUsers"; then
            log_fail "[5.1.2] Repository '$repo' đang mở public (allUsers)."
        else
            log_pass "[5.1.2 & 5.1.3] Repository '$repo' không public."
        fi
    done <<< "$AR_REPOS"
fi

# 5.1.4 - Binary Authorization
log_info "CIS 5.1.4: Binary Authorization"
BIN_AUTH=$(gcloud container clusters describe "$CLUSTER_NAME" --location "$LOCATION" --project "$PROJECT_ID" --format=json 2>/dev/null | jq -r '.binaryAuthorization.evaluationMode // "UNKNOWN"')
if [ "$BIN_AUTH" = "PROJECT_SINGLETON_POLICY_ENFORCE" ]; then
    log_pass "[5.1.4] Binary Authorization đã bật (ENFORCE)."
else
    log_fail "[5.1.4] Binary Authorization chưa bật (trạng thái: $BIN_AUTH)."
fi

# 5.7.1 - Security Posture
log_info "CIS 5.7.1: Security Posture"
POSTURE=$(gcloud container clusters describe "$CLUSTER_NAME" --location "$LOCATION" --project "$PROJECT_ID" --format=json 2>/dev/null | jq -r '.securityPostureConfig.mode // "UNKNOWN"')
if [ "$POSTURE" = "BASIC" ] || [ "$POSTURE" = "ENTERPRISE" ]; then
    log_pass "[5.7.1] Security Posture đã bật (chế độ: $POSTURE)."
else
    log_fail "[5.7.1] Security Posture chưa bật (trạng thái: $POSTURE)."
fi
