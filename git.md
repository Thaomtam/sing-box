# Hướng dẫn xóa toàn bộ nội dung trong nhánh `main` và đẩy các thay đổi mới lên remote

> **Chuyển đến nhánh `main`**
> ```bash
> git checkout main
> ```
>
> **Xóa toàn bộ nội dung trong thư mục làm việc**
> ```bash
> git rm -rf .
> ```
>
> **Commit các thay đổi**
> ```bash
> git commit -m "Remove all files from main"
> ```
>
> **Đẩy các thay đổi lên remote**
> ```bash
> git push origin main
> ```
>
> **Sao chép hoặc tạo các tệp mới trong thư mục làm việc của bạn**
> - (Sử dụng các lệnh sao chép hoặc tạo tệp tại đây)
>
> **Thêm các tệp vào Git**
> ```bash
> git add .
> ```
>
> **Commit các thay đổi**
> ```bash
> git commit -m "Add new files to main"
> ```
>
> **Đẩy các thay đổi lên remote**
> ```bash
> git push origin main
> ```
>
> **Kiểm tra trạng thái nhánh**
> ```bash
> git status
> ```
