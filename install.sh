#!/bin/bash

# Tắt kịch bản nếu gặp lỗi
set -e

# Cập nhật danh sách gói
apt update

# Thiết lập phiên bản mặc định và kiến trúc
DEFAULT_SING_BOX_VERSION="1.8.14"
echo -e "Phiên bản mặc định của sing-box: $DEFAULT_SING_BOX_VERSION"
read -p "Nhập phiên bản sing-box hoặc bấm Enter để sử dụng phiên bản mặc định: " SING_BOX_VERSION_INPUT

SING_BOX_VERSION=${SING_BOX_VERSION_INPUT:-$DEFAULT_SING_BOX_VERSION}

ARCH=$(case "$(uname -m)" in 
    'x86_64') echo 'amd64' ;;
    'x86' | 'i686' | 'i386') echo '386' ;;
    'aarch64' | 'arm64') echo 'arm64' ;;
    'armv7l') echo 'armv7' ;;
    's390x') echo 's390x' ;;
    *) echo 'Kiến trúc máy chủ không được hỗ trợ'; exit 1 ;;
esac)
echo -e "\nKiến trúc máy chủ của tôi là: $ARCH"

# Dừng và xóa các dịch vụ và gói cũ
systemctl stop sing-box.service || true
systemctl disable sing-box.service || true
systemctl stop nginx || true
systemctl disable nginx || true
systemctl daemon-reload

rm -rf /etc/sing-box /var/lib/sing-box /usr/bin/sing-box /etc/systemd/system/sing-box.service
apt purge -y nginx nginx-common nginx-full || true
rm -rf /etc/nginx /var/www/html /var/log/nginx /etc/systemd/system/nginx.service.d/
systemctl daemon-reload

# Hỏi người dùng về các cấu hình tùy chọn
read -p "Bạn muốn thiết lập cấu hình DNS không? (y/n): " dns_choice
read -p "Bạn muốn thiết lập cấu hình mạng không? (y/n): " network_choice
read -p "Bạn muốn thiết lập múi giờ không? (y/n): " timezone_choice
read -p "Bạn có muốn cài đặt Nginx không? (y/n): " nginx_choice
read -p "Bạn có muốn chạy kịch bản tối ưu hóa TCP không? (y/n): " tcp_choice

# Cấu hình DNS nếu người dùng chọn
if [ "$dns_choice" == "y" ]; then
    rm -f /etc/resolv.conf
    cat << EOF > /etc/resolv.conf
nameserver 1.1.1.1
options edns0
EOF
    apt -y install resolvconf
    cat << EOF > /etc/resolvconf/resolv.conf.d/head
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
    service resolvconf restart
fi

# Cấu hình mạng nếu người dùng chọn
if [ "$network_choice" == "y" ]; then
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
fi

# Cấu hình múi giờ nếu người dùng chọn
if [ "$timezone_choice" == "y" ]; then
    timedatectl set-timezone Asia/Ho_Chi_Minh
    echo "Múi giờ được thiết lập thành Asia/Ho_Chi_Minh"
fi

# Cài đặt và cấu hình Nginx nếu người dùng chọn
if [ "$nginx_choice" == "y" ]; then
    # Hỏi người dùng nhập domain
    read -p "Nhập domain: " domain

    # Cài đặt Socat
    apt install -y socat

    # Cài đặt acme.sh
    curl https://get.acme.sh | sh
    source ~/.bashrc  # Sourcing .bashrc to add acme.sh to PATH in the current session
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d $domain --standalone --keylength ec-256
    ~/.acme.sh/acme.sh --install-cert -d $domain --ecc \
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
fi

# Tải xuống và cài đặt sing-box
wget https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
tar -zxf sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
mv sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box /usr/bin
rm -rf sing-box-$SING_BOX_VERSION-linux-$ARCH
rm -f sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Cấu hình sing-box
read -p "Nhập uuid: " ID
read -p "Nhập SNI_443: " SNI
read -p "Nhập SNI_80: " SNI_WS
read -p "Nhập Path_WS: " P_S

mkdir -p /etc/sing-box
cat <<EOF > /etc/sing-box/config.json
{
  "log": {
    "level": "debug",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "local",
        "address": "https://1.1.1.1/dns-query"
      },
      {
        "tag": "block",
        "address": "rcode://refused"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "local",
        "disable_cache": true
      },
      {
        "geosite": "Geosite-vn",
        "server": "block",
        "disable_cache": true
      }
    ]
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": 443,
      "sniff": true,
      "users": [
        {
          "uuid": "$ID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "127.0.0.1",
            "server_port": 8001
          },
          "private_key": "eGyAX6wB-aevcyD0vVW9-6SbIf5MHjOyowGKdIltVk0",
          "short_id": "94d0bf9f111e2aae"
        }
      }
    },
    {
      "type": "vless",
      "listen": "::",
      "listen_port": 80,
      "sniff": true,
      "users": [
        {
          "uuid": "$ID"
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "ws",
        "path": "$P_S",
        "headers": {
          "Host": "$SNI_WS"
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geoip": "private",
        "outbound": "block"
      },
      {
        "geosite": "Geosite-vn",
        "outbound": "block"
      },
      {
        "port_range": "0:65535",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "Geosite-vn",
        "format": "binary",
        "url": "https://github.com/Thaomtam/Geosite-vn/raw/rule-set/Geosite-vn.srs",
        "download_detour": "direct"
      }
    ],
    "final": "direct"
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "cache.db"
    }
  }
}
EOF

# Tạo dịch vụ và kích hoạt sing-box
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

systemctl daemon-reload
systemctl enable --now sing-box

# Tối ưu hóa TCP nếu người dùng chọn
if [ "$tcp_choice" == "y" ]; then
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh"
    chmod +x tcp.sh
    ./tcp.sh
    rm -f tcp.sh
fi

echo "Hoàn tất cài đặt và cấu hình của Thời Tiết"
