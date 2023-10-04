# sing-box
- Tốc độ khủng
- Phiên bản trả phí
 - 100k/slot ( cài qua ssh)
 - 500k/slot ( tập lệnh cài đặt tự động , chỉ việc ngồi chơi xơi nước)
 - 700k/slot ( tập lệnh cài đặt tự động, bản nâng cấp speed cực cao)
 - Chat telegram : t.me/openwrtthoitiet
# Build trực tiếp

```
bash -c "$(curl -L https://sing-box.vercel.app)" @ install --go
```

# Cấu hình server
```
cat << EOF > /usr/local/etc/sing-box/config.json
{
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
                        "server": "",
                        "server_port": 
                    },
                    "private_key": "",
                    "short_id": [
                        ""
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
