#!/bin/bash

# Định nghĩa các màu sắc và hàm in thông báo.
# Việc quy chuẩn hóa đầu ra giúp báo cáo cuối cùng thống nhất và dễ đọc trên Terminal.

# Định nghĩa mã màu ANSI
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Hàm in thông báo trạng thái chung
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Hàm in kết quả ĐẠT
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

# Hàm in kết quả KHÔNG ĐẠT
log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Hàm in kết quả CẦN KIỂM TRA THỦ CÔNG
log_manual() {
    echo -e "${YELLOW}[MANUAL]${NC} $1"
}

# Hàm in lỗi hệ thống (ví dụ: thiếu dependency)
log_error() {
    echo -e "${BOLD}${RED}[ERROR]${NC} $1" >&2
}

# Hàm in tiêu đề cho từng phần kiểm tra
log_header() {
    echo ""
    echo -e "${CYAN}${BOLD}======================================================================${NC}"
    echo -e "${CYAN}${BOLD} $1 ${NC}"
    echo -e "${CYAN}${BOLD}======================================================================${NC}"
}