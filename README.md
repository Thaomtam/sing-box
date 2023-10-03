# sing-box
- Tốc độ khủng
# Build trực tiếp

```
bash -c "$(curl -L https://sing-box.vercel.app)" @ install --go
```

# Cấu hình server
```
cat << EOF > /usr/local/etc/sing-box/config.json
{
   "dns": {
      "servers": [
        {
          "address": "1.1.1.1",
          "detour": "direct"
        }
      ]
    },
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "uuid": "thoi-tiet-openwrt",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "dl.kgvn.garenanow.com",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "1.1.1.1",
                        "server_port": 443
                    },
                    "private_key": "sELUHVtMZVXnBVNLOJYOR9NdpZbR7QVjS5b9X0F6iGU",
                    "short_id": [
                        "e9455277471d0a78"
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
EOF
```

# Khởi động lại

```
systemctl restart sing-box
```
# Xem nhật kí

```
systemctl status sing-box
```
# Cập nhật thời gian thực

```
journalctl -u sing-box -o cat -f
```

# Thời tiết TCP

```
 bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/Oneclick-Xray-Reality/main/thoitiet.sh)"
```
