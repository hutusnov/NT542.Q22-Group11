#!/usr/bin/env bash
# =============================================================================
# CIS GKE Autopilot Benchmark v1.3.0
# Audit: 4.6.2 | 4.6.4 | 5.2.1 | 5.3.1 | 5.6.1
# =============================================================================
sed -i 's/set +e/set +e/' workload_audit.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((PASS++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((WARN++)); }
info() { echo -e "  ${CYAN}[INFO]${NC} $*"; }
divider() {
  echo -e "\n${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $*${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}\n"
}

audit_4_6_2() {
  divider "CIS 4.6.2 | Seccomp Profile = RuntimeDefault (Level 2)"
  local pod_json
  pod_json=$(kubectl get pods --all-namespaces -o json 2>/dev/null)
  local total
  total=$(echo "$pod_json" | jq '.items | length')
  info "Tổng số Pod tìm thấy: $total"
  echo ""
  if [[ "$total" -eq 0 ]]; then
    warn "Không có Pod nào trong cluster."
    return
  fi
  local pass_list=()
  local fail_list=()
  while IFS= read -r entry; do
    local ns name stype ann
    ns=$(echo    "$entry" | jq -r '.namespace')
    name=$(echo  "$entry" | jq -r '.name')
    stype=$(echo "$entry" | jq -r '.seccompType // ""')
    ann=$(echo   "$entry" | jq -r '.annotation  // ""')
    if [[ "$stype" == "RuntimeDefault" || "$ann" == "runtime/default" ]]; then
      pass_list+=("${ns}/${name}  [seccomp=${stype:-via-annotation}]")
    else
      fail_list+=("${ns}/${name}  [seccomp=${stype:-UNSET}]")
    fi
  done < <(echo "$pod_json" | jq -c '.items[] | {
      namespace:   .metadata.namespace,
      name:        .metadata.name,
      seccompType: (.spec.securityContext.seccompProfile.type // ""),
      annotation:  (.metadata.annotations."seccomp.security.alpha.kubernetes.io/pod" // "")
    }')
  if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo -e "  ${RED}${BOLD}❌ Pod KHÔNG có Seccomp RuntimeDefault (${#fail_list[@]} pod):${NC}"
    for item in "${fail_list[@]}"; do fail "$item"; done
    echo ""
  fi
  if [[ ${#pass_list[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✅ Pod ĐÃ có Seccomp RuntimeDefault (${#pass_list[@]} pod):${NC}"
    for item in "${pass_list[@]}"; do pass "$item"; done
    echo ""
  fi
  echo -e "  ┌─ Tổng kết 4.6.2 ──────────────────────────"
  echo -e "  │  Tổng Pod  : $total"
  echo -e "  │  PASS      : ${#pass_list[@]}"
  echo -e "  │  FAIL      : ${#fail_list[@]}"
  echo -e "  └────────────────────────────────────────────"
  if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}Remediation — thêm vào spec của Pod:${NC}"
    echo    "    securityContext:"
    echo    "      seccompProfile:"
    echo    "        type: RuntimeDefault"
  fi
}

audit_4_6_4() {
  divider "CIS 4.6.4 | Default Namespace không được sử dụng (Level 2)"
  info "Quét tất cả resource trong namespace default..."
  echo ""
  local resources
  resources=$(kubectl get \
    all,configmaps,secrets,serviceaccounts,networkpolicies \
    -n default -o json 2>/dev/null)
  local user_res
  user_res=$(echo "$resources" | jq -r '
    .items[]
    | select(
         ((.kind == "Service"        and .metadata.name == "kubernetes")       or
          (.kind == "ServiceAccount" and .metadata.name == "default")          or
          (.kind == "ConfigMap"      and .metadata.name == "kube-root-ca.crt"))
         | not
      )
    | "[\(.kind)] \(.metadata.name)"')
  local count
  count=$(echo "$user_res" | grep -c '\[' 2>/dev/null || true)
  if [[ $count -gt 0 ]]; then
    echo -e "  ${RED}${BOLD}❌ Phát hiện $count resource người dùng trong namespace default:${NC}"
    echo ""
    printf "  %-30s %s\n" "KIND" "NAME"
    printf "  %-30s %s\n" "──────────────────────────────" "──────────────────────"
    echo "$user_res" | while IFS= read -r line; do
      [[ -n "$line" ]] && fail "$line"
    done
    echo ""
    warn "Hãy chuyển workload sang namespace riêng biệt."
    echo "    kubectl create namespace <ten-namespace>"
  else
    pass "Namespace default không có workload người dùng — Đạt CIS 4.6.4."
  fi
  echo ""
  info "Resource hệ thống mặc định (bỏ qua khi đánh giá):"
  echo "    [Service]        kubernetes"
  echo "    [ServiceAccount] default"
  echo "    [ConfigMap]      kube-root-ca.crt"
}

audit_5_2_1() {
  divider "CIS 5.2.1 | Không dùng Compute Engine Default SA (Level 2)"
  info "Lấy thông tin serviceAccount từ cluster config..."
  echo ""
  local cluster_json
  cluster_json=$(gcloud container clusters describe "$CLUSTER_NAME" \
    --location "$LOCATION" \
    --project  "$PROJECT_ID" \
    --format   json 2>/dev/null)
  local sa_list
  sa_list=$(echo "$cluster_json" | jq -r '
    [ .nodeConfig.serviceAccount,
      (.nodePools[]?.config.serviceAccount) ]
    | map(select(. != null))
    | unique[]' 2>/dev/null || echo "default")
  info "Danh sách Service Account tìm thấy:"
  echo ""
  printf "  %-55s %s\n" "SERVICE ACCOUNT" "TRANG THAI"
  printf "  %-55s %s\n" "───────────────────────────────────────────────────────" "──────────"
  local has_default=0
  while IFS= read -r sa; do
    [[ -z "$sa" ]] && continue
    if [[ "$sa" == "default" ]]; then
      printf "  %-55s %s\n" "$sa" "FAIL — DEFAULT SA"
      has_default=1
    else
      printf "  %-55s %s\n" "$sa" "PASS — Custom SA"
    fi
  done <<< "$sa_list"
  echo ""
  if [[ $has_default -eq 1 ]]; then
    fail "Cluster đang dùng Compute Engine Default Service Account!"
    local project_number
    project_number=$(gcloud projects describe "$PROJECT_ID" \
      --format="value(projectNumber)" 2>/dev/null || echo "???")
    warn "Default SA: ${project_number}-compute@developer.gserviceaccount.com"
    echo ""
    echo -e "  ${YELLOW}Remediation:${NC}"
    echo "    gcloud iam service-accounts create gke-node-sa \\"
    echo "      --display-name 'GKE Node SA' --project $PROJECT_ID"
    echo "    for ROLE in roles/logging.logWriter roles/monitoring.metricWriter roles/monitoring.viewer; do"
    echo "      gcloud projects add-iam-policy-binding $PROJECT_ID \\"
    echo "        --member serviceAccount:gke-node-sa@${PROJECT_ID}.iam.gserviceaccount.com \\"
    echo "        --role \$ROLE"
    echo "    done"
  else
    pass "Cluster KHÔNG dùng Default SA — Đạt CIS 5.2.1."
  fi
}

audit_5_3_1() {
  divider "CIS 5.3.1 | Kubernetes Secrets — KMS Encryption (Level 2)"
  info "Lệnh: gcloud container clusters describe ... | jq '.databaseEncryption'"
  echo ""
  local db_enc
  db_enc=$(gcloud container clusters describe "$CLUSTER_NAME" \
    --location "$LOCATION" \
    --project  "$PROJECT_ID" \
    --format   json 2>/dev/null | jq '.databaseEncryption // {}')
  echo -e "  ${BOLD}Raw output jq '.databaseEncryption':${NC}"
  echo "$db_enc" | jq . | sed 's/^/    /'
  echo ""
  local state key_name
  state=$(echo    "$db_enc" | jq -r '.state    // "DECRYPTED"')
  key_name=$(echo "$db_enc" | jq -r '.keyName  // ""')
  printf "  %-20s %s\n" "state:"   "$state"
  printf "  %-20s %s\n" "keyName:" "${key_name:-(trong)}"
  echo ""
  if [[ "$state" == "ENCRYPTED" && -n "$key_name" ]]; then
    pass "state=ENCRYPTED — Secrets duoc ma hoa bang CMEK."
    pass "KMS Key: $key_name"
    local key_state
    key_state=$(gcloud kms keys describe "$key_name" \
      --format="value(primary.state)" 2>/dev/null || echo "UNKNOWN")
    printf "  %-20s %s\n" "KMS key state:" "$key_state"
    [[ "$key_state" == "ENABLED" ]] && \
      pass "KMS key dang ENABLED — hop le." || \
      fail "KMS key state: $key_state — can kiem tra!"
  else
    fail "state=$state — Secrets Encryption CHUA bat!"
    echo ""
    echo -e "  ${YELLOW}Remediation:${NC}"
    echo "    gcloud kms keyrings create gke-keyring \\"
    echo "      --location $LOCATION --project $PROJECT_ID"
    echo "    gcloud kms keys create gke-secrets-key \\"
    echo "      --location $LOCATION --keyring gke-keyring \\"
    echo "      --purpose encryption --project $PROJECT_ID"
    echo "    KEY=projects/$PROJECT_ID/locations/$LOCATION/keyRings/gke-keyring/cryptoKeys/gke-secrets-key"
    echo "    gcloud container clusters update $CLUSTER_NAME \\"
    echo "      --location $LOCATION --database-encryption-key \$KEY --project $PROJECT_ID"
  fi
}

audit_5_6_1() {
  divider "CIS 5.6.1 | Persistent Disks — CMEK Encryption (Level 2)"
  info "Lệnh: kubectl get pv + gcloud compute disks describe | jq '.diskEncryptionKey.kmsKeyName'"
  echo ""
  local total
  total=$(kubectl get pv --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$total" -eq 0 ]]; then
    warn "Khong co Persistent Volume nao trong cluster."
    warn "GKE Autopilot chua dung PersistentDisk — CIS 5.6.1 khong ap dung."
    return
  fi
  info "Tong Persistent Volume: $total"
  echo ""
  local ok=0
  local fail_count=0
  printf "  %-30s %-30s %-40s %s\n" "PV NAME" "DISK NAME" "KMS KEY" "STATUS"
  printf "  %-30s %-30s %-40s %s\n" \
    "──────────────────────────────" \
    "──────────────────────────────" \
    "────────────────────────────────────────" \
    "──────────"
  while IFS= read -r pv_name; do
    [[ -z "$pv_name" ]] && continue
    local vol_handle disk_name disk_zone
    vol_handle=$(kubectl get pv "$pv_name" -o json | \
      jq -r '.spec.csi.volumeHandle // .spec.gcePersistentDisk.pdName // "unknown"')
    if [[ "$vol_handle" == projects/* ]]; then
      disk_zone=$(echo "$vol_handle" | cut -d'/' -f4)
      disk_name=$(echo "$vol_handle" | cut -d'/' -f6)
    else
      disk_name="$vol_handle"
      disk_zone="${LOCATION}-a"
    fi
    local kms_key
    kms_key=$(gcloud compute disks describe "$disk_name" \
      --zone    "$disk_zone" \
      --project "$PROJECT_ID" \
      --format  json 2>/dev/null \
      | jq -r '.diskEncryptionKey.kmsKeyName // ""')
    if [[ -n "$kms_key" ]]; then
      printf "  %-30s %-30s %-40s %s\n" "$pv_name" "$disk_name" "$kms_key" "PASS"
      ((ok++))
    else
      printf "  %-30s %-30s %-40s %s\n" "$pv_name" "$disk_name" "(khong co)" "FAIL"
      ((fail_count++))
    fi
  done < <(kubectl get pv -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
  echo ""
  echo -e "  ┌─ Tong ket 5.6.1 ──────────────────────────"
  echo -e "  │  Tong PV    : $total"
  echo -e "  │  Co CMEK    : $ok"
  echo -e "  │  Khong CMEK : $fail_count"
  echo -e "  └────────────────────────────────────────────"
}

summary() {
  echo -e "\n${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  KET QUA TONG HOP — CIS GKE Autopilot Audit${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${GREEN}PASS${NC} : $PASS"
  echo -e "  ${RED}FAIL${NC} : $FAIL"
  echo -e "  ${YELLOW}WARN${NC} : $WARN"
  echo ""
  echo -e "  ┌─ Chi tiet tung muc ──────────────────────────────"
  echo -e "  │  4.6.2  Seccomp RuntimeDefault"
  echo -e "  │  4.6.4  Default Namespace"
  echo -e "  │  5.2.1  Compute Engine Default SA"
  echo -e "  │  5.3.1  KMS Secrets Encryption"
  echo -e "  │  5.6.1  CMEK Persistent Disk"
  echo -e "  └──────────────────────────────────────────────────"
  echo ""
  if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✓ Cluster dat tat ca kiem tra CIS.${NC}"
  else
    echo -e "  ${RED}${BOLD}✗ Co $FAIL kiem tra THAT BAI — can khac phuc.${NC}"
  fi
  echo ""
}

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   CIS GKE Autopilot Benchmark v1.3.0 — Audit Tool   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Project : ${CYAN}${PROJECT_ID}${NC}"
echo -e "  Cluster : ${CYAN}${CLUSTER_NAME}${NC}"
echo -e "  Location: ${CYAN}${LOCATION}${NC}"
echo -e "  Thoi gian: $(date '+%Y-%m-%d %H:%M:%S')"

audit_4_6_2
audit_4_6_4
audit_5_2_1
audit_5_3_1
audit_5_6_1
summary
ENDSCRIPT
