#!/bin/bash

# Install necessary tools
apt update && apt -y install curl wget tar socat jq git openssl uuid-runtime build-essential zlib1g-dev libssl-dev libevent-dev dnsutils cron qrencode

# Ask for domain, SNI, and UUID
read -p "MY DOMAIN: " domain
read -p "SNI: " sni
read -p "UUID: " id

# SSL certificate management with acme.sh
curl https://get.acme.sh | sh && \
/root/.acme.sh/acme.sh --upgrade --auto-upgrade && \
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt && \
chown -R nobody:nogroup /etc/ssl/private && \
/root/.acme.sh/acme.sh --issue -d "$domain" --standalone --keylength ec-256 && \
/root/.acme.sh/acme.sh --install-cert -d "$domain" --ecc \
--fullchain-file /etc/ssl/private/fullchain.cer \
--key-file /etc/ssl/private/private.key

# Install Nginx
apt install -y gnupg2 ca-certificates lsb-release ubuntu-keyring
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor > /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx
apt update -y
apt install -y nginx
mkdir -p /etc/systemd/system/nginx.service.d
echo -e "[Service]\nExecStartPost=/bin/sleep 0.1" > /etc/systemd/system/nginx.service.d/override.conf
systemctl daemon-reload

# Install SING-BOX
bash -c "$(curl -L https://sing-box.vercel.app)" @ install

# Retrieve necessary files for SING-BOX
curl -Lo /usr/local/share/sing-box/geoip.db https://github.com/MetaCubeX/meta-rules-dat/raw/release/geoip-lite.db
curl -Lo /usr/local/share/sing-box/geosite.db https://github.com/MetaCubeX/meta-rules-dat/raw/release/geosite.db
curl -Lo /etc/nginx/nginx.conf https://raw.githubusercontent.com/Thaomtam/sing-box/main/nginx.conf

# Generate keys for SING-BOX
keys=$(sing-box generate reality-keypair)
pk=$(echo $keys | awk -F " " '{print $2}')
pub=$(echo $keys | awk -F " " '{print $4}')
shortid=$(openssl rand -hex 8)
serverIp=$(curl -s ipv4.wtfismyip.com/text)

# Configure SING-BOX and Nginx
rm -rf /usr/local/etc/sing-box/config.json
cat << EOF > /usr/local/etc/sing-box/config.json
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "uuid": "$id",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$sni",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "127.0.0.1",
                        "server_port": 8001
                    },
                    "private_key": "$pk",
                    "short_id": [
                        "$shortid"
                    ]
                }
            }
        },
        {
            "type": "socks",
            "tag": "socks-in",
            "listen": "::",
            "listen_port": 16557,
            "users": [
                {
                   "username": "admin",
                   "password": "admin123"
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
        }
    ]
}
EOF

# Restart SING-BOX and Nginx
systemctl restart sing-box && systemctl restart nginx

# Configure DNS settings
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

# Set timezone and network configurations
timedatectl set-timezone Asia/Ho_Chi_Minh && \
sysctl -w net.core.rmem_max=16777216 && \
sysctl -w net.core.wmem_max=16777216 && \
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf && \
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf && \
sysctl -p

# Generate SING-BOX URL and QR code
url="vless://$id@$serverIp:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$shortid&type=tcp&headerType=none#THOITIET-SINGBOX"
echo "$url"

qrencode -s 120 -t ANSIUTF8 "$url"
qrencode -s 50 -o qr.png "$url"

exit 0
