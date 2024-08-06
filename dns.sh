#!/bin/bash

# Kiểm tra quyền truy cập
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Xóa tệp /etc/resolv.conf hiện tại và cấu hình DNS mới
rm -f /etc/resolv.conf
cat << EOF > /etc/resolv.conf
nameserver 1.1.1.1
options edns0
EOF

# Kiểm tra và cài đặt gói resolvconf nếu chưa cài đặt
if ! dpkg -l | grep -q resolvconf; then
    apt update
    apt -y install resolvconf
fi

# Cấu hình resolvconf
cat << EOF > /etc/resolvconf/resolv.conf.d/head
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Khởi động lại dịch vụ resolvconf
systemctl restart resolvconf

echo "DNS configuration is complete."

# Hiển thị DNS hiện tại
echo "Current DNS settings:"
cat /etc/resolv.conf
