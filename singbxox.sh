#!/bin/bash

# Install snapd
apt update -y && \
apt install -y snapd

# Ask for domain
read -p "MY DOMAIN: " domain

# Ask for SNI
read -p "Bug SNI: " sni

# Ask for SNI
read -p "UUID: " id

# Install certbot
snap install core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Obtain SSL certificate
certbot certonly --standalone --register-unsafely-without-email -d $domain

# Copy SSL certificate files
cp /etc/letsencrypt/archive/*/fullchain*.pem /etc/ssl/private/fullchain.cer
cp /etc/letsencrypt/archive/*/privkey*.pem /etc/ssl/private/private.key
chown -R nobody:nogroup /etc/ssl/private
chmod -R 0644 /etc/ssl/private/*

# Schedule automatic renewal
printf "0 0 1 * * /root/update_certbot.sh\n" > update && crontab update && rm update
cat > /root/update_certbot.sh << EOF
#!/usr/bin/env bash
certbot renew --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
cp /etc/letsencrypt/archive/*/fullchain*.pem /etc/ssl/private/fullchain.cer
cp /etc/letsencrypt/archive/*/privkey*.pem /etc/ssl/private/private.key
EOF
chmod +x update_certbot.sh

# Install Nginx
apt install -y gnupg2 ca-certificates lsb-release ubuntu-keyring && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor > /usr/share/keyrings/nginx-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list && echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx && apt update -y && apt install -y nginx && mkdir -p /etc/systemd/system/nginx.service.d && echo -e "[Service]\nExecStartPost=/bin/sleep 0.1" > /etc/systemd/system/nginx.service.d/override.conf && systemctl daemon-reload

# Update package index and install dependencies
apt-get install -y jq
apt-get install -y openssl
apt-get install -y qrencode

#Install SING-BOX
bash -c "$(curl -L https://sing-box.vercel.app)" @ install

json=$(curl -s https://raw.githubusercontent.com/Thaomtam/sing-box/main/config.json)

keys=$(sing-box generate reality-keypair)
pk=$(echo "$keys" | awk '/PrivateKey:/ {print $3}')
pub=$(echo "$keys" | awk '/PublicKey:/ {print $3}')
serverIp=$domain
uuid=$id
shortId=$(openssl rand -hex 8)
sni=$sni
url="vless://$id@$domain:443/?type=tcp&encryption=none&flow=xtls-rprx-vision&sni=$sni&fp=chrome&security=reality&pbk=$pub&sid=$shortId#Thoitiet"

newJson=$(cat << EOF > /usr/local/etc/sing-box/config.json
{
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
                        "$shortId"
                    ]
                }
            }
        },
	{
            "type": "socks",
            "listen": "::",
            "listen_port": 13559,
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
    ],
    "route": {
		"rules": [
		  {
			"geoip": "private",
			"outbound": "block"
		  },
		  {
			"geosite": "category-ads-all",
			"domain_keyword": [
			  "ads"
			  ],
			"outbound": "block"
		   }
		 ],
        "final": "direct"
    }
}
EOF)
	 
echo "$newJson" | sudo tee /usr/local/etc/sing-box/config.json >/dev/null	 

# Configure Nginx & Geosite and Geoip
curl -Lo /usr/local/share/sing-box/geoip.db https://github.com/MetaCubeX/meta-rules-dat/raw/release/geoip-lite.db && curl -Lo /usr/local/share/sing-box/geosite.db https://github.com/MetaCubeX/meta-rules-dat/raw/release/geosite.db && curl -Lo /etc/nginx/nginx.conf https://raw.githubusercontent.com/Thaomtam/sing-box/main/nginx.conf && systemctl restart sing-box && systemctl restart nginx
# Ask for time zone
timedatectl set-timezone Asia/Ho_Chi_Minh && \
apt install ntp && \
timedatectl set-ntp on && \
sysctl -w net.core.rmem_max=16777216 && \
sysctl -w net.core.wmem_max=16777216

echo "$url"

qrencode -s 120 -t ANSIUTF8 "$url"
qrencode -s 50 -o qr.png "$url"

exit 0
