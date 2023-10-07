#!/bin/bash

# Install snapd
apt update -y

ufw dissable

# Ask for SNI
read -p "SNI: " sni

# Ask for SNI
read -p "UUID: " id

# Update package index and install dependencies
apt-get install -y jq
apt-get install -y openssl
apt-get install -y qrencode
#Install SING-BOX
bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/phuc.sh)"
curl -Lo /usr/local/share/sing-box/geoip.db https://github.com/MetaCubeX/meta-rules-dat/raw/release/geoip-lite.db && curl -Lo /usr/local/share/sing-box/geosite.db https://github.com/MetaCubeX/meta-rules-dat/raw/release/geosite.db

keys=$(sing-box generate reality-keypair)
pk=$(echo $keys | awk -F " " '{print $2}')
pub=$(echo $keys | awk -F " " '{print $4}')

shortid=$(openssl rand -hex 8)
echo $shortid

serverIp=$(curl -s ipv4.wtfismyip.com/text)
echo $serverIp

# Xóa file cấu hình mặc định và ghi cấu hình XRAY
rm -rf /usr/local/etc/xray/config.json
cat << EOF > /usr/local/etc/xray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "port": "443",
                "network": "udp",
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$id",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": "8004",
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "1.1.1.1:443",
                    "serverNames": [
                        "$sni"
                    ],
                    "privateKey": "$pk",
                    "shortIds": [
                        "$shortid"
                    ]
                }
            },
            "sniffing": {
                "enabled": false,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        },
        {
            "listen": "127.0.0.1",
            "port": 8004,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$id",
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "h2",
                "sockopt": {
                    "acceptProxyProtocol": true
                }
            },
            "sniffing": {
                "enabled": false,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        },
        {
			"port": 80,
			"protocol": "vmess",
			"settings": {
				"clients": [
					{
						"$id",
						"alterId": 0
					}
				]
			},
			"streamSettings": {
			"network": "ws",
			"security": "none",
			"wsSettings": {
				"path": "/",
				"headers": {
					"Host": "$sni"
				}
			},
			"quicSettings": {}
		}
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ],
    "policy": {
        "levels": {
            "0": {
                "handshake": 2,
                "connIdle": 120
            }
        }
    }
}
EOF

systemctl restart xray

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

url="vless://$id@$serverIp:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$shortid&type=tcp&headerType=none#THOITIET-XRAY"
echo "$url"

qrencode -s 120 -t ANSIUTF8 "$url"
qrencode -s 50 -o qr.png "$url"

exit 0
