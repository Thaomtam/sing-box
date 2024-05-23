#!/bin/bash

# Hỏi người dùng nhập domain
read -p "Nhập domain: " domain

# Cài đặt Socat
apt install -y socat

# Cài đặt acme.sh
curl https://get.acme.sh | sh
source ~/.bashrc
acme.sh --upgrade --auto-upgrade
acme.sh --set-default-ca --server letsencrypt
acme.sh --issue -d $domain --standalone --keylength ec-256
acme.sh --install-cert -d $domain --ecc \
--fullchain-file /etc/ssl/private/fullchain.cer \
--key-file /etc/ssl/private/private.key
chown -R nobody:nogroup /etc/ssl/private

# Cài đặt GnuPG2, ca-certificates, lsb-release, và ubuntu-keyring
apt install -y gnupg2 ca-certificates lsb-release ubuntu-keyring

# Thêm kho lưu trữ Nginx và cài đặt Nginx
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor > /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx
apt update -y
apt install -y nginx

# Tạo thư mục và file override cho Nginx service
mkdir -p /etc/systemd/system/nginx.service.d
echo -e "[Service]\nExecStartPost=/bin/sleep 0.1" > /etc/systemd/system/nginx.service.d/override.conf
systemctl daemon-reload

# Tải xuống và thay thế cấu hình Nginx từ repository
curl -Lo /etc/nginx/nginx.conf https://raw.githubusercontent.com/Thaomtam/sing-box/main/nginx.conf

# Kích hoạt Nginx khi khởi động
systemctl enable nginx

echo "Hoàn tất cài đặt Nginx và cấu hình SSL với acme.sh cho domain $domain"