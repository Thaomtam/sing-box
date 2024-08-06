#!/bin/bash

# Kiểm tra quyền truy cập
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Kiểm tra và cài đặt gói resolvconf nếu chưa cài đặt
if ! dpkg -l | grep -q resolvconf; then
    apt update
    apt -y install resolvconf
fi

# Cấu hình systemd-resolved
echo "Configuring systemd-resolved to use DNS 1.1.1.1"

# Tạo thư mục /etc/systemd/resolved.conf.d nếu chưa tồn tại
mkdir -p /etc/systemd/resolved.conf.d

# Tạo tệp cấu hình DNS
cat << EOF > /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=1.1.1.1
FallbackDNS=1.0.0.1
EOF

# Khởi động lại dịch vụ systemd-resolved
systemctl restart systemd-resolved

# Tạo liên kết tượng trưng đến /run/systemd/resolve/resolv.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Cấu hình DNS cho tất cả các giao diện mạng
for interface in $(ls /sys/class/net/ | grep -v lo); do
    echo "Configuring DNS for interface $interface"
    resolvectl dns "$interface" 1.1.1.1
    resolvectl dns "$interface" 1.0.0.1 --fallback
done

echo "DNS configuration is complete."

# Hiển thị DNS hiện tại
echo "Current DNS settings:"
resolvectl status
