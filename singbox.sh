#!/bin/bash

# Xác định kiến trúc của máy chủ
export ARCH=$(case "$(uname -m)" in 
    'x86_64') echo 'amd64' ;;
    'x86' | 'i686' | 'i386') echo '386' ;;
    'aarch64' | 'arm64') echo 'arm64' ;;
    'armv7l') echo 'armv7' ;;
    's390x') echo 's390x' ;;
    *) echo 'Unsupported server architecture'; exit 1 ;;
esac)
echo -e "\nMy server architecture is: $ARCH"

# Cập nhật danh sách gói và cài đặt unzip nếu chưa có
apt update && apt install -y unzip

# Cài đặt múi giờ nếu chưa được thiết lập
timedatectl set-timezone Asia/Ho_Chi_Minh

# Tạo thư mục tạm thời
TMP_DIR=$(mktemp -d)
if [ ! -d "$TMP_DIR" ]; then
  echo "Failed to create temporary directory"
  exit 1
fi

# Loại bỏ phiên bản sing-box cũ nếu có
rm -f /usr/bin/sing-box

# Lấy tag phiên bản mới nhất từ kho lưu trữ của bạn
LATEST_TAG=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/Thaomtam/hiddify-singbox/releases/latest | awk -F/ '{print $NF}')

# Tạo URL tải xuống cho tệp ZIP
DOWNLOAD_URL="https://github.com/Thaomtam/hiddify-singbox/releases/download/${LATEST_TAG}/sing-box-linux-$ARCH.zip"

# Tải xuống và giải nén gói sing-box
curl -L -o "$TMP_DIR/sing-box-linux-$ARCH.zip" "$DOWNLOAD_URL" || { echo "Failed to download sing-box"; exit 1; }
unzip "$TMP_DIR/sing-box-linux-$ARCH.zip" -d "$TMP_DIR" || { echo "Failed to extract sing-box"; exit 1; }

# Di chuyển tệp thực thi vào thư mục /usr/bin
mv "$TMP_DIR/sing-box" /usr/bin || { echo "Failed to move sing-box binary"; exit 1; }

# Xóa các tệp tạm thời
rm -rf "$TMP_DIR"

# Tạo thư mục cấu hình
mkdir -p /etc/sing-box

# Tạo tệp cấu hình mặc định (có thể tuỳ chỉnh theo yêu cầu của bạn)
echo '{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "8.8.8.8",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "cloudflare"
      }
    ],
    "final": "cloudflare",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "socks",
      "listen": "::",
      "listen_port": 16557,
      "users": [
        {
          "Username": "admin123",
          "Password": "admin123123"
        }
      ]
    },
    {
      "type": "trojan",
      "listen": "::",
      "listen_port": 8443,
      "users": [
        {
          "password": "thoitiet"
        }
      ],
      "tls": {
        "enabled": true,
        "insecure": true,
        "certificate_path": "/etc/sing-box/bing.com.crt",
        "key_path": "/etc/sing-box/bing.com.key"
      },
      "multiplex": {
        "enabled": true,
        "brutal": {
          "enabled": true,
          "up_mbps": 150,
          "down_mbps": 50
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "d5tlrad8-in",
      "listen": "::",
      "listen_port": 443,
      "sniff": true,
      "sniff_override_destination": true,
      "up_mbps": 150,
      "down_mbps": 50,
      "users": [
        {
          "name": "EQUR9AK+",
          "password": "WqzGKnmZ9UaB"
        }
      ],
      "ignore_client_bandwidth": false,
      "masquerade": "https://www.bing.com",
      "tls": {
        "enabled": true,
        "insecure": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "/etc/sing-box/bing.com.crt",
        "key_path": "/etc/sing-box/bing.com.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "direct",
      "tag": "direct-fragment",
      "tls_fragment": {
        "enabled": true,
        "size": "10-30",
        "sleep": "2-8"
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "network": [
          "udp","tcp"
        ],
        "outbound": "direct"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "cache.db"
    }
  }
}' > /etc/sing-box/config.json

# Tạo tệp dịch vụ systemd cho sing-box
cat <<EOF> /etc/systemd/system/sing-box.service
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=512
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Tải lại daemon và kích hoạt dịch vụ
systemctl daemon-reload && systemctl enable sing-box && systemctl restart sing-box
echo "Setup complete."