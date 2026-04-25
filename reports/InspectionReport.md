# Báo cáo Kiểm tra & Đánh giá — CIS GKE Autopilot Benchmark v1.3.0

**Dự án:** NT542.Q22 — Nhóm 11  
**Tiêu chuẩn áp dụng:** [CIS Google Kubernetes Engine (GKE) Autopilot Benchmark v1.3.0](https://www.cisecurity.org/benchmark/kubernetes)  
**Tổng số mục kiểm tra:** 31 mục / 4 modules  

---

## Quy ước trạng thái

| Ký hiệu | Ý nghĩa |
|---------|---------|
| ✅ Automated | Script tự động kiểm tra và cho kết quả PASS/FAIL |
| 🔍 Manual | Cần kiểm tra thủ công thêm (script hỗ trợ thu thập dữ liệu) |
| ⬜ Chưa làm | Chưa triển khai |

---

## Module 1 — Quản lý Danh tính & Quyền hạn (IAM & RBAC)

**Script:** `modules/module1_iam_rbac.sh`

| STT | CIS ID | Tên mục (EN — theo tài liệu gốc) | Loại | Tiến độ |
|-----|--------|----------------------------------|------|---------|
| 1 | 4.1.1 | Ensure that the cluster-admin role is only used where required | 🔍 Manual | ✅ Có script |
| 2 | 4.1.2 | Minimize access to secrets | 🔍 Manual | ✅ Có script |
| 3 | 4.1.3 | Minimize wildcard use in Roles and ClusterRoles | 🔍 Manual | ✅ Có script |
| 4 | 4.1.4 | Ensure that default service accounts are not actively used | ✅ Automated | ✅ Có script |
| 5 | 4.1.8 | Avoid bindings to system:anonymous | ✅ Automated | ✅ Có script |
| 6 | 4.1.9 | Avoid non-default bindings to system:unauthenticated | ✅ Automated | ✅ Có script |
| 7 | 4.1.10 | Avoid non-default bindings to system:authenticated | ✅ Automated | ✅ Có script |
| 8 | 5.5.1 | Manage Kubernetes RBAC users with Google Groups for GKE | 🔍 Manual | ✅ Có script |

---

## Module 2 — Mạng & Cách ly (Networking & CNI)

**Script:** `modules/module2_networking.sh`

| STT | CIS ID | Tên mục (EN — theo tài liệu gốc) | Loại | Tiến độ |
|-----|--------|----------------------------------|------|---------|
| 9 | 4.3.1 | Ensure that all Namespaces have Network Policies defined | ✅ Automated | ✅ Có script |
| 10 | 5.4.1 | Enable VPC Flow Logs and Intranode Visibility | ✅ Automated | ✅ Có script |
| 11 | 5.4.2 | Ensure Control Plane Authorized Networks is Enabled | 🔍 Manual | ✅ Có script |
| 12 | 5.4.3 | Ensure clusters are created with Private Endpoint Enabled and Public Access Disabled | ✅ Automated | ✅ Có script |
| 13 | 5.4.4 | Ensure clusters are created with Private Nodes | ✅ Automated | ✅ Có script |
| 14 | 5.4.5 | Ensure use of Google-managed SSL Certificates | ✅ Automated | ✅ Có script |

---

## Module 3 — Workload, Secrets & Storage

**Script:** `modules/module3_workload.sh`

| STT | CIS ID | Tên mục (EN — theo tài liệu gốc) | Loại | Tiến độ |
|-----|--------|----------------------------------|------|---------|
| 15 | 4.6.2 | Ensure that the seccomp profile is set to RuntimeDefault in the pod definitions | ✅ Automated | ✅ Có script |
| 16 | 4.6.4 | The default namespace should not be used | ✅ Automated | ✅ Có script |
| 17 | 5.2.1 | Ensure GKE clusters are not running using the Compute Engine default service account | ✅ Automated | ✅ Có script |
| 18 | 5.3.1 | Ensure Kubernetes Secrets are encrypted using keys managed in Cloud KMS | ✅ Automated | ✅ Có script |
| 19 | 5.6.1 | Enable Customer-Managed Encryption Keys (CMEK) for GKE Persistent Disks (PD) | 🔍 Manual | ✅ Có script |

---

## Module 4 — Bảo mật Image & Dịch vụ Quản lý

**Script:** `modules/module4_image.sh`

| STT | CIS ID | Tên mục (EN — theo tài liệu gốc) | Loại | Tiến độ |
|-----|--------|----------------------------------|------|---------|
| 20 | 5.1.1 | Ensure Image Vulnerability Scanning is enabled | ✅ Automated | ✅ Có script |
| 21 | 5.1.2 | Minimize user access to Container Image repositories | 🔍 Manual | ✅ Có script |
| 22 | 5.1.3 | Minimize cluster access to read-only for Container Image repositories | 🔍 Manual | ✅ Có script |
| 23 | 5.1.4 | Ensure only trusted container images are used (Binary Authorization) | ✅ Automated | ✅ Có script |
| 24 | 5.7.1 | Enable Security Posture | ✅ Automated | ✅ Có script |

---

## Mục cần kiểm tra thủ công (Manual-only)

> Các mục dưới đây thuộc phạm vi benchmark nhưng **không thể tự động hoá hoàn toàn** — cần xem xét tài liệu, cấu hình, hoặc quy trình vận hành.

| STT | CIS ID | Tên mục (EN — theo tài liệu gốc) | Ghi chú |
|-----|--------|----------------------------------|---------|
| 25 | 4.1.5 | Ensure that Service Account Tokens are only mounted where necessary | Kiểm tra từng Pod spec |
| 26 | 4.1.6 | Avoid use of system:masters group | Xem xét RBAC policy |
| 27 | 4.1.7 | Limit use of the Bind, Impersonate and Escalate permissions | Audit ClusterRole thủ công |
| 28 | 4.4.1 | Consider external secret storage | Kiểm tra Secret Store CSI / Vault |
| 29 | 4.5.1 | Configure Image Provenance using ImagePolicyWebhook admission controller | Kiểm tra AdmissionController |
| 30 | 4.6.1 | Create administrative boundaries between resources using namespaces | Xem xét kiến trúc namespace |
| 31 | 4.6.3 | Apply Security Context to Pods and Containers | Kiểm tra từng Deployment |

---

## Tổng kết phạm vi

| Hạng mục | Số lượng |
|---------|---------|
| Tổng mục kiểm tra | **31** |
| Tự động hoá (Automated) | **17** |
| Hỗ trợ bán tự động (Manual + Script) | **7** |
| Chỉ thủ công (Manual-only) | **7** |
| Modules script | **4** |

---

*Cập nhật lần cuối: 2026-04-25 — Nhóm 11, NT542.Q22*
