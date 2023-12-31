#!/bin/bash

# Install snapd
apt update -y 

# Ask for SNI
read -p "SNI: " sni

# Ask for SNI
read -p "UUID: " id

# Update package index and install dependencies
apt-get install -y jq
apt-get install -y openssl
apt-get install -y qrencode
#Install SING-BOX
bash -c "$(curl -L https://sing-box.vercel.app)" @ install

keys=$(sing-box generate reality-keypair)
pk=$(echo $keys | awk -F " " '{print $2}')
pub=$(echo $keys | awk -F " " '{print $4}')

shortid=$(openssl rand -hex 8)
echo $shortid

serverIp=$(curl -s ipv4.wtfismyip.com/text)
echo $serverIp

# Xóa file cấu hình mặc định và ghi cấu hình Reality
rm -rf /usr/local/etc/sing-box/config.json
cat << EOF > /usr/local/etc/sing-box/config.json
{
    "log": {
        "level": "trace",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "uuid": "$id",
                    "flow": "xtls-rprx-visiom"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$sni",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "1.1.1.1",
                        "server_port": 443
                    },
                    "private_key": "$pk",
                    "short_id": [
                        "$shortid"
                    ]
                }
            }
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
        }
    ]
}
EOF

systemctl restart sing-box

url="vless://$id@$serverIp:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$shortid&type=tcp&headerType=none#THOITIET-SINGBOX"
echo "$url"

qrencode -s 120 -t ANSIUTF8 "$url"
qrencode -s 50 -o qr.png "$url"

exit 0
