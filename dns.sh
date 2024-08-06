#!/bin/bash

# Kiểm tra quyền truy cập
if [ "$(id -u)" != "0" ]; then
  echo "Vui lòng chạy script với quyền root" 1>&2
  exit 1
fi

# Cài đặt gói resolvconf nếu chưa có
if ! dpkg -l | grep -q resolvconf; then
  apt update
  apt install -y resolvconf
fi

# Hàm để tạo hoặc ghi đè tệp cấu hình
function configure_dns() {
  local dns_servers="$1"
  local config_file="/etc/systemd/resolved.conf.d/dns_servers.conf"

  # Tạo thư mục nếu chưa tồn tại
  mkdir -p $(dirname "$config_file")

  # Tạo hoặc ghi đè tệp cấu hình
  cat << EOF > "$config_file"
  [Resolve]
  DNS=$dns_servers
  EOF
}

# Cấu hình DNS chính
configure_dns "1.1.1.1"

# Cấu hình DNS dự phòng (nếu có)
# configure_dns "1.1.1.1 8.8.8.8"

# Kiểm tra và khởi động lại dịch vụ systemd-resolved
if systemctl is-active systemd-resolved; then
  systemctl restart systemd-resolved
fi

# Tạo liên kết tượng trưng đến /etc/resolv.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Cấu hình DNS cho tất cả các giao diện mạng
for interface in $(ls /sys/class/net/ | grep -v lo); do
  echo "Cấu hình DNS cho giao diện $interface"
  resolvectl dns "$interface" 1.1.1.1
done

# Kiểm tra cấu hình
echo "Cấu hình DNS hiện tại:"
resolvectl status

# Thông báo kết quả
echo "Cấu hình DNS đã hoàn tất!"
