# 1. Cập nhật nhánh dev mới nhất từ remote

```
git checkout dev
git pull origin dev
```

# 2. Tạo nhánh làm việc riêng từ nhánh dev

```
git checkout -b feature/network-audit
```

# 3. Viết code, sau đó commit

```
git add .
git commit -m "feat: Thêm script kiểm tra Private Nodes và VPC Flow Logs"
```

# 4. Đẩy nhánh cá nhân lên GitHub

```
git push origin feature/network-audit
```
