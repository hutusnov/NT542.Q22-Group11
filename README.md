# GKE CIS Autopilot Benchmark v1.3.0 — Audit Tool

> **NT542.Q22 — Nhóm 11**  
> Framework kiểm tra bảo mật tự động cho Google Kubernetes Engine (Autopilot) theo tiêu chuẩn **CIS GKE Benchmark v1.3.0**.

---

## 🚀 Cách chạy

```bash
# Tiếng Việt (mặc định)
bash main.sh

# English output
AUDIT_LANG=en bash main.sh

# Chỉ định cluster cụ thể
PROJECT_ID=my-project CLUSTER_NAME=my-cluster LOCATION=asia-southeast1 bash main.sh
```

Kết quả xuất ra thư mục `output/`:
- `gke_audit_YYYYMMDD_HHMMSS.csv` — import vào Excel / Google Sheets
- `gke_audit_YYYYMMDD_HHMMSS.html` — dashboard báo cáo dark mode

---

## 📋 Phạm vi kiểm tra — 31 mục / 4 Modules

| Module | CIS IDs | Số mục |
|--------|---------|--------|
| M1: IAM & RBAC | 4.1.1, 4.1.2, 4.1.3, 4.1.4, 4.1.8, 4.1.9, 4.1.10, 5.5.1 | 8 |
| M2: Networking | 4.3.1, 5.4.1, 5.4.2, 5.4.3, 5.4.4, 5.4.5 | 6 |
| M3: Workload & Secrets | 4.6.2, 4.6.4, 5.2.1, 5.3.1, 5.6.1 | 5 |
| M4: Image Security | 5.1.1, 5.1.2, 5.1.3, 5.1.4, 5.7.1 | 5 |
| Manual-only | 4.1.5–4.1.7, 4.4.1, 4.5.1, 4.6.1, 4.6.3 | 7 |

---

## 🗂️ Cấu trúc thư mục

```
NT542.Q22-Group11/
├── main.sh                        # Entry point duy nhất
├── modules/
│   ├── module1_iam_rbac.sh        # CIS 4.1.1–4.1.10, 5.5.1
│   ├── module2_networking.sh      # CIS 4.3.1, 5.4.1–5.4.5
│   ├── module3_workload.sh        # CIS 4.6.2, 4.6.4, 5.2.1, 5.3.1, 5.6.1
│   └── module4_image.sh           # CIS 5.1.1–5.1.4, 5.7.1
├── utils/
│   ├── logger.sh                  # Màu sắc, hàm log, record_result()
│   ├── i18n.sh                    # Bilingual vi/en: cis_title(), t()
│   └── reporter.sh                # Xuất CSV & HTML
├── output/                        # Kết quả kiểm tra (tự tạo khi chạy)
└── reports/
    ├── InspectionReport.md        # Bảng 31 mục CIS chuẩn hoá
    └── TaskSchedule.md            # Lịch phân công công việc
```

---

## 🔧 Yêu cầu

- `gcloud` CLI đã xác thực (`gcloud auth login`)
- `kubectl` đã kết nối cluster
- `jq` >= 1.6

---

## 📊 Ví dụ kết quả

```
══════════════════════════════════════════════════════════════════════
  CIS GKE AUTOPILOT BENCHMARK V1.3.0 — CÔNG CỤ KIỂM TRA BẢO MẬT TỰ ĐỘNG
══════════════════════════════════════════════════════════════════════

[PASS]   Google Groups for GKE is ENABLED.
[FAIL]   Binary Authorization is NOT enabled.
[WARN]   No Persistent Volumes — CIS 5.6.1 not applicable.

  Tổng mục     ✅ PASS     ❌ FAIL     🔍 MANUAL    ⚠️  WARN
  ──────────   ──────────  ──────────  ──────────   ──────────
  24           18          4           1            1

  Tỷ lệ đạt (Automated PASS): 75%
```

---

## 📚 Tài liệu tham khảo

- [CIS Google Kubernetes Engine Autopilot Benchmark v1.3.0](https://www.cisecurity.org/benchmark/kubernetes)
- [GKE Security Best Practices](https://cloud.google.com/kubernetes-engine/docs/concepts/security-overview)
