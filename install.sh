#!/bin/bash

# Tắt kịch bản nếu gặp lỗi
set -e

# Cập nhật danh sách gói
apt update

# Thiết lập phiên bản mặc định của sing-box và xác định kiến trúc hệ thống
DEFAULT_SING_BOX_VERSION="1.8.14"
echo -e "Phiên bản mặc định của sing-box: $DEFAULT_SING_BOX_VERSION"
read -p "Nhập phiên bản sing-box hoặc bấm Enter để sử dụng phiên bản mặc định: " SING_BOX_VERSION_INPUT

# Kiểm tra xem người dùng đã nhập gì không
if [ -z "$SING_BOX_VERSION_INPUT" ]; then
    SING_BOX_VERSION=$DEFAULT_SING_BOX_VERSION
else
    SING_BOX_VERSION=$SING_BOX_VERSION_INPUT
fi

export ARCH=$(case "$(uname -m)" in 
    'x86_64') echo 'amd64' ;;
    'x86' | 'i686' | 'i386') echo '386' ;;
    'aarch64' | 'arm64') echo 'arm64' ;;
    'armv7l') echo 'armv7' ;;
    's390x') echo 's390x' ;;
    *) echo 'Kiến trúc máy chủ không được hỗ trợ'; exit 1 ;;
esac)
echo -e "\nKiến trúc máy chủ của tôi là: $ARCH"

# Dừng và vô hiệu hóa dịch vụ sing-box và nginx cũ
systemctl stop sing-box.service || true
systemctl disable sing-box.service || true
systemctl stop nginx || true
systemctl disable nginx || true

# Tải lại máy chủ systemd
systemctl daemon-reload

# Gỡ bỏ cài đặt cũ của sing-box và nginx
rm -rf /etc/sing-box
rm -rf /var/lib/sing-box
rm -f /usr/bin/sing-box
rm -f /etc/systemd/system/sing-box.service
apt purge -y nginx nginx-common nginx-full || true
rm -rf /etc/nginx
rm -rf /var/www/html
rm -rf /var/log/nginx
rm -rf /etc/systemd/system/nginx.service.d/

# Tải lại máy chủ systemd
systemctl daemon-reload

# Hỏi người dùng về việc cấu hình DNS
read -p "Bạn muốn thiết lập cấu hình DNS không? (y/n): " dns_choice
if [ "$dns_choice" == "y" ]; then
    # Cấu hình cài đặt DNS
    rm -f /etc/resolv.conf
    cat << EOF > /etc/resolv.conf
    nameserver 1.1.1.1
    options edns0
EOF
    # Cài đặt và cấu hình resolvconf
    apt -y install resolvconf
    cat << EOF > /etc/resolvconf/resolv.conf.d/head
    nameserver 1.1.1.1
    nameserver 1.0.0.1
EOF
    # Khởi động lại dịch vụ resolvconf
    service resolvconf restart
fi

# Hỏi người dùng về việc cấu hình mạng
read -p "Bạn muốn thiết lập cấu hình mạng không? (y/n): " network_choice
if [ "$network_choice" == "y" ]; then
    # Thiết lập cấu hình mạng
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
fi

# Hỏi người dùng về việc cấu hình múi giờ
read -p "Bạn muốn thiết lập múi giờ không? (y/n): " timezone_choice
if [ "$timezone_choice" == "y" ]; then
    # Thiết lập múi giờ mặc định thành Asia/Ho_Chi_Minh
    timedatectl set-timezone Asia/Ho_Chi_Minh
    echo "Múi giờ được thiết lập thành Asia/Ho_Chi_Minh"
fi

# Hỏi người dùng về việc cài đặt Nginx
read -p "Bạn có muốn cài đặt Nginx không? (y/n): " nginx_choice
if [ "$nginx_choice" == "y" ]; then
    bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/install-nginx.sh)"
fi

# Cài đặt phiên bản mới của sing-box
wget https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
tar -zxf sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
mv sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box /usr/bin
rm -rf sing-box-$SING_BOX_VERSION-linux-$ARCH
rm -f sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Tạo thư mục và tệp cấu hình cho sing-box
mkdir /etc/sing-box
echo "{}" > /etc/sing-box/config.json

# Tạo tệp dịch vụ cho sing-box
cat <<EOF > /etc/systemd/system/sing-box.service
[Unit]
Description=Dịch vụ sing-box
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Cấu hình sing-box với các thiết lập mới
curl -Lo /etc/sing-box/config.json https://raw.githubusercontent.com/Thaomtam/sing-box/main/httpupgrade.json
systemctl daemon-reload
systemctl enable --now sing-box

# Hỏi người dùng về việc chạy kịch bản tối ưu hóa TCP
read -p "Bạn có muốn chạy kịch bản tối ưu hóa TCP không? (y/n): " choice
if [ "$choice" == "y" ]; then
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh"
    chmod +x tcp.sh
    ./tcp.sh
    rm -f tcp.sh
fi

echo "Cài đặt hoàn tất."