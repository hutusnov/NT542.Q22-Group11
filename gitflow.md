# Gitflow
## 1. Cập nhật nhánh dev mới nhất từ remote

```
git checkout dev
git pull origin dev
```

## 2. Tạo nhánh làm việc riêng từ nhánh dev

```
git checkout -b feature/network-audit
```

## 3. Viết code, sau đó commit

```
git add .
git commit -m "feat: Thêm script kiểm tra Private Nodes và VPC Flow Logs"
```

## 4. Đẩy nhánh cá nhân lên GitHub

```
git push origin feature/network-audit
```
---
# Chạy thủ công để Test (Quy trình của Lập trình viên)
### Google Cloud Shell
Để chạy main.sh trên Cloud Shell, kéo code từ GitHub về:

- Bước 1: Mở Google Cloud Shell, kết nối project và cluster.

- Bước 2: Clone repo của về:
```
git clone https://github.com/hutusnov/NT542.Q22-Group11.git
```
- Bước 3: Di chuyển vào thư mục dự án:
```
cd NT542.Q22-Group11
```
- Bước 4: Chuyển sang nhánh dev hoặc nhánh cá nhân (nếu đang code tính năng mới):
```
git checkout dev
```
- Bước 5: Cấp quyền thực thi và chạy tool:
```
chmod +x main.sh utils/*.sh modules/*.sh
```
## Chạy tool với biến môi trường dự án Lab
```
PROJECT_ID="project-b446ffba-838e-4ec0-a4b" CLUSTER_NAME="vuln-autopilot-lab" ./main.sh
```
