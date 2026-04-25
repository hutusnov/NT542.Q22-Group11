#!/usr/bin/env bash
# =============================================================================
# modules/module5_remediation.sh
# CIS GKE Autopilot Benchmark v1.3.0
# Module 5: Remediation (Khắc phục)
# Tự động tạo script khắc phục (remediation.sh) cho các mục bị FAIL
# =============================================================================

if ! declare -f log_info > /dev/null 2>&1; then
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_dir}/../utils/logger.sh" 2>/dev/null || source ./utils/logger.sh
fi

log_header "$(mod_header M5)"

REMEDIATION_FILE="${OUTPUT_DIR:-output}/remediation.sh"
mkdir -p "$(dirname "$REMEDIATION_FILE")"

cat > "$REMEDIATION_FILE" << 'EOF'
#!/usr/bin/env bash
# =============================================================================
# GKE Auto-Remediation Script
# CẢNH BÁO: Hãy kiểm tra kỹ các lệnh trước khi chạy trên môi trường Production!
# =============================================================================
EOF

echo "PROJECT_ID=\"\${PROJECT_ID:-$PROJECT_ID}\"" >> "$REMEDIATION_FILE"
echo "CLUSTER_NAME=\"\${CLUSTER_NAME:-$CLUSTER_NAME}\"" >> "$REMEDIATION_FILE"
echo "LOCATION=\"\${LOCATION:-$LOCATION}\"" >> "$REMEDIATION_FILE"
echo "" >> "$REMEDIATION_FILE"

has_remediation=0

for entry in "${AUDIT_RESULTS[@]}"; do
    IFS='§' read -r cis_id title status detail <<< "$entry"
    if [[ "$status" == "FAIL" ]]; then
        case "$cis_id" in
            "4.3.1")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 4.3.1: Thêm default-deny Network Policy ---
# Cần thay <NAMESPACE> bằng namespace bị thiếu (ví dụ: default)
kubectl apply -f - <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
YAML

EOF
                has_remediation=1
                ;;
            "5.4.1")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 5.4.1: Bật VPC Flow Logs / Intranode Visibility ---
gcloud container clusters update "$CLUSTER_NAME" --enable-intra-node-visibility --location="$LOCATION" --project="$PROJECT_ID"

EOF
                has_remediation=1
                ;;
            "5.4.4")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 5.4.4: Bật Private Nodes ---
# Lưu ý: Autopilot không hỗ trợ chuyển đổi public -> private node sau khi tạo. Cần tạo lại cluster với cờ --enable-private-nodes.
echo "[CẢNH BÁO] CIS 5.4.4: Vui lòng tạo lại cluster với cờ --enable-private-nodes"

EOF
                has_remediation=1
                ;;
            "5.3.1")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 5.3.1: Bật CMEK cho Secrets ---
# Có thể thay đổi keyring và key name theo ý muốn
gcloud kms keyrings create gke-keyring --location "$LOCATION" --project "$PROJECT_ID" || true
gcloud kms keys create gke-secrets-key --location "$LOCATION" --keyring gke-keyring --purpose encryption --project "$PROJECT_ID" || true
KEY="projects/$PROJECT_ID/locations/$LOCATION/keyRings/gke-keyring/cryptoKeys/gke-secrets-key"
gcloud container clusters update "$CLUSTER_NAME" --location "$LOCATION" --database-encryption-key "$KEY" --project "$PROJECT_ID"

EOF
                has_remediation=1
                ;;
            "5.1.1")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 5.1.1: Bật Image Vulnerability Scanning ---
gcloud services enable containerscanning.googleapis.com --project "$PROJECT_ID"

EOF
                has_remediation=1
                ;;
            "5.1.4")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 5.1.4: Bật Binary Authorization ---
gcloud container clusters update "$CLUSTER_NAME" --location "$LOCATION" --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE --project "$PROJECT_ID"

EOF
                has_remediation=1
                ;;
            "5.7.1")
                cat >> "$REMEDIATION_FILE" << 'EOF'
# --- CIS 5.7.1: Bật Security Posture ---
gcloud container clusters update "$CLUSTER_NAME" --location "$LOCATION" --security-posture=standard --workload-vulnerability-scanning=standard --project "$PROJECT_ID"

EOF
                has_remediation=1
                ;;
        esac
    fi
done

chmod +x "$REMEDIATION_FILE"

if [[ $has_remediation -eq 1 ]]; then
    if [[ "$AUDIT_LANG" == "en" ]]; then
        log_pass "Generated auto-remediation script: $REMEDIATION_FILE"
        log_info "Review and run using: bash $REMEDIATION_FILE"
    else
        log_pass "Đã tạo file kịch bản khắc phục (Remediation script): $REMEDIATION_FILE"
        log_info "Có thể xem và chạy lệnh: bash $REMEDIATION_FILE"
    fi
else
    if [[ "$AUDIT_LANG" == "en" ]]; then
        log_pass "No automated remediations generated (no applicable FAILs)."
    else
        log_pass "Không có mục nào có thể tạo remediation script tự động."
    fi
    rm -f "$REMEDIATION_FILE"
fi

echo ""
log_info "$(printf "$(t DONE_MODULE)" "$(mod_header M5)")"
