#!/bin/bash

# Đặt phiên bản sing-box và xác định kiến trúc của máy chủ
export SING_BOX_VERSION=1.9.3
export ARCH=$(case "$(uname -m)" in 
    'x86_64') echo 'amd64';; 
    'x86' | 'i686' | 'i386') echo '386';; 
    'aarch64' | 'arm64') echo 'arm64';; 
    'armv7l') echo 'armv7';; 
    's390x') echo 's390x';; 
    *) echo '不支持的服务器架构'; exit 1;; 
esac)

echo -e "\n我的服务器架构是：$ARCH"

# Tải về và giải nén gói sing-box
wget https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
tar -zxf sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Di chuyển tệp thực thi vào thư mục /usr/bin
mv sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box /usr/bin
rm -rf ./sing-box-$SING_BOX_VERSION-linux-$ARCH
rm -f ./sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Tạo thư mục cấu hình và tạo tệp config.json
mkdir /etc/sing-box
echo '{
  "inbounds": [
    {
      "type": "vless",
      "listen": "127.0.0.1",
      "listen_port": 8001,
      "sniff": true,
      "users": [
        {
          "uuid": "thoitiet"
        }
      ],
      "multiplex": {
        "enabled": true
      },
      "transport": {
        "type": "ws",
        "path": "/gists/cache",
        "early_data_header_name": "Sec-WebSocket-Protocol",
        "headers": {
          "Host": "m.tiktok.com"
        }
      }
    },
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": 16557,
      "users": [
        {
          "Username": "thoitiet",
          "Password": "thoitiet"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}' > /etc/sing-box/config.json

# Tạo tệp dịch vụ systemd cho sing-box
cat <<EOF> /etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
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

# Tải lại daemon và kích hoạt dịch vụ
systemctl daemon-reload
echo "Tập lệnh đã hoàn thành. Bạn có thể khởi động dịch vụ sing-box bằng cách chạy: systemctl start sing-box"
