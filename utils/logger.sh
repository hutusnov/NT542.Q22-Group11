#!/bin/bash
# =============================================================================
# utils/logger.sh — Logging, Color Output & Result Tracking
# CIS GKE Autopilot Benchmark v1.3.0 Audit Tool
# =============================================================================
# Biến môi trường:
#   AUDIT_LANG="vi"  (mặc định) | "en"  — ngôn ngữ đầu ra
# =============================================================================

# Nạp i18n nếu chưa nạp
if ! declare -f cis_title > /dev/null 2>&1; then
    _logger_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils/i18n.sh
    source "${_logger_dir}/i18n.sh" 2>/dev/null || true
fi

# --- Mã màu ANSI ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Bộ đếm toàn cục ---
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_MANUAL=0
TOTAL_WARN=0

# --- Mảng lưu kết quả cho CSV/HTML (dùng § làm dấu phân cách) ---
declare -a AUDIT_RESULTS=()

# =============================================================================
# Hàm log cơ bản
# =============================================================================
log_info()   { echo -e "${BLUE}[INFO]${NC}   $1"; }
log_pass()   { echo -e "${GREEN}[PASS]${NC}   $1"; }
log_fail()   { echo -e "${RED}[FAIL]${NC}   $1"; }
log_manual() { echo -e "${YELLOW}[MANUAL]${NC} $1"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC}   $1"; }
log_error()  { echo -e "${BOLD}${RED}[ERROR]${NC}  $1" >&2; }

log_header() {
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════${NC}"
}

log_subheader() {
    echo ""
    echo -e "${BLUE}${BOLD}  ▶ $1${NC}"
    echo -e "${BLUE}  ────────────────────────────────────────────────────────────────────${NC}"
}

# =============================================================================
# record_result <cis_id> <title> <status: PASS|FAIL|MANUAL|WARN> <detail>
# Ghi kết quả vào mảng AUDIT_RESULTS để reporter.sh xuất CSV/HTML
# =============================================================================
record_result() {
    local cis_id="$1"
    local title="$2"
    local status="$3"
    local detail="${4:-}"

    case "$status" in
        PASS)   ((TOTAL_PASS++))   ;;
        FAIL)   ((TOTAL_FAIL++))   ;;
        MANUAL) ((TOTAL_MANUAL++)) ;;
        WARN)   ((TOTAL_WARN++))   ;;
    esac

    AUDIT_RESULTS+=("${cis_id}§${title}§${status}§${detail}")
}