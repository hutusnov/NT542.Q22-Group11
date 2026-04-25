# Lịch Phân Công Công Việc — NT542.Q22, Nhóm 11

**Dự án:** Framework Kiểm tra Bảo mật GKE theo CIS GKE Autopilot Benchmark v1.3.0  
**Công cụ:** `main.sh` (Bash) + 5 Modules + Utils (Logger, I18n, Reporter)

---

## Giai đoạn I — Khởi tạo

| STT | Công việc | Trạng thái |
|-----|-----------|-----------|
| 1.1 | Đọc hiểu kiến trúc GKE Autopilot (Control Plane & Worker Nodes do Google quản lý) | ✅ Hoàn thành |
| 1.2 | Tạo tài khoản GCP, thiết lập Billing / Free Tier | ✅ Hoàn thành |
| 1.3 | Dựng cụm GKE Autopilot Lab — cố tình mở Public Endpoint, gán sai quyền để có dữ liệu test | ✅ Hoàn thành |
| 1.4 | Tạo GitHub Repo, quy chuẩn Git flow (nhánh `main`, `dev`) | ✅ Hoàn thành |
| 1.5 | Viết khung Core Script: hàm kết nối GCP (`gcloud auth`), hàm ghi Log và format màu đầu ra (PASS/FAIL) | ✅ Hoàn thành |

---

## Giai đoạn II — Lập trình Module 1: IAM & RBAC

**Script:** `modules/module1_iam_rbac.sh`

| STT | Công việc | CIS ID | Trạng thái |
|-----|-----------|--------|-----------|
| 2.1 | Viết script Audit: Quét ClusterRoleBindings kiểm tra quyền cluster-admin và quyền truy cập secrets | 4.1.1, 4.1.2 | ✅ Hoàn thành |
| 2.2 | Viết script Audit: Tìm dấu wildcard (*) trong Roles và kiểm tra Default Service Accounts | 4.1.3, 4.1.4 | ✅ Hoàn thành |
| 2.3 | Viết script Audit: Quét các quyền gán cho `system:anonymous`, `system:unauthenticated`, `system:authenticated` | 4.1.8, 4.1.9, 4.1.10 | ✅ Hoàn thành |
| 2.4 | Viết script Audit: Kiểm tra xem RBAC có đang được quản lý qua Google Groups không | 5.5.1 | ✅ Hoàn thành |

---

## Giai đoạn III — Lập trình Module 2: Networking

**Script:** `modules/module2_networking.sh`

| STT | Công việc | CIS ID | Trạng thái |
|-----|-----------|--------|-----------|
| 3.1 | Viết script Audit: Kiểm tra xem TẤT CẢ namespace đã có Network Policies chưa | 4.3.1 | ✅ Hoàn thành |
| 3.2 | Viết script Audit: Dùng `gcloud` check VPC Flow Logs, Intranode Visibility và Control Plane Authorized Networks | 5.4.1, 5.4.2 | ✅ Hoàn thành |
| 3.3 | Viết script Audit: Xác minh Private Endpoint được bật (Public Access tắt), Private Nodes và SSL | 5.4.3, 5.4.4, 5.4.5 | ✅ Hoàn thành |

---

## Giai đoạn IV — Lập trình Module 3: Workload, Secrets & Storage

**Script:** `modules/module3_workload.sh`

| STT | Công việc | CIS ID | Trạng thái |
|-----|-----------|--------|-----------|
| 4.1 | Viết script Audit: Quét định nghĩa Pod xem Seccomp Profile có thiết lập RuntimeDefault không; Cảnh báo nếu dùng default namespace | 4.6.2, 4.6.4 | ✅ Hoàn thành |
| 4.2 | Viết script Audit: Xác minh cụm không chạy bằng Compute Engine default service account | 5.2.1 | ✅ Hoàn thành |
| 4.3 | Viết script Audit: Quét cụm xem Secrets có được mã hoá KMS (Customer-managed) và ổ cứng có dùng CMEK không | 5.3.1, 5.6.1 | ✅ Hoàn thành |

---

## Giai đoạn V — Lập trình Module 4: Image Security & Managed Services

**Script:** `modules/module4_image.sh`

| STT | Công việc | CIS ID | Trạng thái |
|-----|-----------|--------|-----------|
| 5.1 | Viết script Audit: Kiểm tra Container/Artifact Registry xem Image Vulnerability Scanning đã bật chưa | 5.1.1 | ✅ Hoàn thành |
| 5.2 | Viết script Audit: Quét quyền truy cập của user và cluster vào Image repositories | 5.1.2, 5.1.3 | ✅ Hoàn thành |
| 5.3 | Viết script Audit: Xác minh cấu hình Binary Authorization và Security Posture | 5.1.4, 5.7.1 | ✅ Hoàn thành |

---

## Giai đoạn VI — Lập trình Module 5: Auto Remediation

**Script:** `modules/module5_remediation.sh`

| STT | Công việc | Trạng thái |
|-----|-----------|-----------|
| 6.1 | Lập trình tính năng đọc mảng kết quả kiểm tra `AUDIT_RESULTS` | ✅ Hoàn thành |
| 6.2 | Tự động sinh `output/remediation.sh` với các lệnh gcloud/kubectl vá lỗi cho các mục bị FAIL | ✅ Hoàn thành |

---

## Giai đoạn VII — Hoàn thiện Framework

| STT | Công việc | Trạng thái |
|-----|-----------|-----------|
| 7.1 | Viết `utils/i18n.sh`: hệ thống quản lý ngôn ngữ đầu ra (vi/en) với `cis_title()`, `mod_header()`, `t()` | ✅ Hoàn thành |
| 7.2 | Ráp 5 module vào Core Framework (`main.sh`) — entry point duy nhất, hỗ trợ `AUDIT_LANG=en` | ✅ Hoàn thành |
| 7.3 | Viết `utils/reporter.sh`: xuất báo cáo CSV (Excel-compatible) và HTML (dark mode dashboard) | ✅ Hoàn thành |
| 7.4 | System Test: Chạy tool trên cụm Lab — lưu output HTML/CSV/Remediation làm bằng chứng cho báo cáo | ⏳ Đang thực hiện |
| 7.5 | Chuẩn hoá thư mục: xoá file cũ, đổi tên module, đồng bộ Git | ✅ Hoàn thành |

---

## Giai đoạn VIII — Báo cáo

| STT | Công việc | Trạng thái |
|-----|-----------|-----------|
| 8.1 | Viết báo cáo kỹ thuật: mô tả kiến trúc, phương pháp, kết quả từng mục CIS | ⏳ Đang thực hiện |
| 8.2 | Tổng hợp file Word, làm Slide thuyết trình & quay video demo | ⬜ Chưa bắt đầu |
| 8.3 | Kiểm tra format, review nội dung nhóm | ⬜ Chưa bắt đầu |

---

## Cấu trúc thư mục dự án

```
NT542.Q22-Group11/
├── main.sh                        # Entry point — AUDIT_LANG=en bash main.sh
├── modules/
│   ├── module1_iam_rbac.sh        # CIS 4.1.1–4.1.10, 5.5.1 (8 mục)
│   ├── module2_networking.sh      # CIS 4.3.1, 5.4.1–5.4.5  (6 mục)
│   ├── module3_workload.sh        # CIS 4.6.2, 4.6.4, 5.2.1, 5.3.1, 5.6.1 (5 mục)
│   ├── module4_image.sh           # CIS 5.1.1–5.1.4, 5.7.1  (5 mục)
│   └── module5_remediation.sh     # Sinh file remediation.sh
├── utils/
│   ├── logger.sh                  # Màu sắc, hàm log, record_result
│   ├── i18n.sh                    # Bilingual: cis_title(), mod_header(), t()
│   └── reporter.sh                # Xuất CSV & HTML
├── output/                        # Kết quả kiểm tra (tạo khi chạy)
│   ├── gke_audit_YYYYMMDD_HHMMSS.csv
│   └── gke_audit_YYYYMMDD_HHMMSS.html
└── reports/
    ├── InspectionReport.md        # Bảng 31 mục CIS chuẩn hoá
    └── TaskSchedule.md            # File này
```
