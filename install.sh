#!/bin/bash

# Tắt kịch bản nếu gặp lỗi
set -e

# Cập nhật danh sách gói
apt update

# Thiết lập phiên bản mặc định của sing-box và xác định kiến trúc hệ thống
DEFAULT_SING_BOX_VERSION="1.8.14"
echo -e "Phiên bản mặc định của sing-box: $DEFAULT_SING_BOX_VERSION"
read -p "Nhập phiên bản sing-box hoặc bấm Enter để sử dụng phiên bản mặc định: " SING_BOX_VERSION_INPUT

if [ -z "$SING_BOX_VERSION_INPUT" ]; then
    SING_BOX_VERSION=$DEFAULT_SING_BOX_VERSION
else
    SING_BOX_VERSION=$SING_BOX_VERSION_INPUT
fi

ARCH=$(case "$(uname -m)" in 
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
rm -rf /etc/sing-box /var/lib/sing-box /usr/bin/sing-box /etc/systemd/system/sing-box.service
apt purge -y nginx nginx-common nginx-full || true
rm -rf /etc/nginx /var/www/html /var/log/nginx /etc/systemd/system/nginx.service.d/

# Tải lại máy chủ systemd
systemctl daemon-reload

# Hỏi người dùng về các cấu hình tùy chọn
read -p "Bạn muốn thiết lập cấu hình DNS không? (y/n): " dns_choice
read -p "Bạn muốn thiết lập cấu hình mạng không? (y/n): " network_choice
read -p "Bạn muốn thiết lập múi giờ không? (y/n): " timezone_choice
read -p "Bạn có muốn cài đặt Nginx không? (y/n): " nginx_choice
read -p "Bạn có muốn chạy kịch bản tối ưu hóa TCP không? (y/n): " tcp_choice

# Thiết lập cấu hình DNS nếu người dùng chọn
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

# Thiết lập cấu hình mạng nếu người dùng chọn
if [ "$network_choice" == "y" ]; then
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
fi

# Thiết lập múi giờ nếu người dùng chọn
if [ "$timezone_choice" == "y" ]; then
    timedatectl set-timezone Asia/Ho_Chi_Minh
    echo "Múi giờ được thiết lập thành Asia/Ho_Chi_Minh"
fi

# Cài đặt Nginx nếu người dùng chọn
if [ "$nginx_choice" == "y" ]; then
    bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/install-nginx.sh)"
fi

# Tải và cài đặt phiên bản mới của sing-box
wget https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
tar -zxf sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
mv sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box /usr/bin
rm -rf sing-box-$SING_BOX_VERSION-linux-$ARCH
rm -f sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Nhập các thông tin cần thiết cho cấu hình sing-box
read -p "Nhập uuid: " ID
read -p "Nhập SNI_443: " SNI
read -p "Nhập SNI_80: " SNI_WS
read -p "Nhập Path_WS: " P_S

# Tạo thư mục và tệp cấu hình cho sing-box
mkdir /etc/sing-box
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
    },
    {
      "type": "socks",
      "listen": "::",
      "listen_port": 16557,
      "sniff": true,
      "users": [
        {
          "Username": "admin",
          "Password": "admin123"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
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