# SSL Certificate
```
snap install core; snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

certbot certonly --standalone --register-unsafely-without-email --non-interactive --agree-tos -d <Your Domain Name>

cp /etc/letsencrypt/archive/*/fullchain*.pem /etc/ssl/private/fullchain.cer
cp /etc/letsencrypt/archive/*/privkey*.pem /etc/ssl/private/private.key

chown -R nobody:nogroup /etc/ssl/private
chmod -R 0644 /etc/ssl/private/*
```
# Cài Đặt Sing-Box
```
bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/singbox.sh)"
```
# Cài Đặt Nginx
```
apt install -y gnupg2 ca-certificates lsb-release ubuntu-keyring && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor > /usr/share/keyrings/nginx-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list && echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx && apt update -y && apt install -y nginx && mkdir -p /etc/systemd/system/nginx.service.d && echo -e "[Service]\nExecStartPost=/bin/sleep 0.1" > /etc/systemd/system/nginx.service.d/override.conf && systemctl daemon-reload
```
# Xem nhật kí
```
systemctl status sing-box
```
# Cập nhật thời gian thực
```
journalctl -u sing-box -o cat -f
```
# Hạt nhân tuỳ chỉnh BBRPLUS
```
bash -c "$(curl -L https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)"
```
# Hạt nhân tuỳ chỉnh TCP Brutal
```
bash <(curl -fsSL https://tcp.hy2.sh/)
```

[Singbox+nginx example](https://github.com/Thaomtam/Sing-box-example-)

[GeositeVN for singbox](https://github.com/Thaomtam/Geosite-vn)

[GeositeVN for xray](https://github.com/Thaomtam/domain-list-community)

[Docker-Sing-Box](https://github.com/Thaomtam/Docker-Sing-Box)

[Docker--xray](https://github.com/Thaomtam/Docker--xray)

[hiddify-singbox](https://github.com/Thaomtam/hiddify-singbox)

# Gỡ Cài Đặt Sing-Box
```
systemctl stop sing-box.service
systemctl disable sing-box.service
systemctl daemon-reload
rm -rf /etc/sing-box
rm -rf /var/lib/sing-box
rm -f /usr/bin/sing-box
rm -f /etc/systemd/system/sing-box.service
```
# Gỡ Cài Đặt Nginx
```
systemctl stop nginx && apt purge -y nginx && rm -r /etc/systemd/system/nginx.service.d/
```
