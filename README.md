
-- Lệnh cài sing-box
```
 bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/install.sh)"
```
-- Lệnh Update core sing-box
```
 bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/update-core.sh)"
```
-- Lệnh Update hidify-core sing-box
```
 bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/hiddify-core.sh)"
```
-- Lệnh workdlists hack wifi
```
 curl -Lo /usr/share/dict/wordlist-probable.txt https://raw.githubusercontent.com/lucthienphong1120/wordlists-vi/main/wordlists-vn-wifi.txt.txt
```
-- SingBox
```
bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/singbox.sh)"
```
-- DNS
```
bash -c "$(curl -L https://raw.githubusercontent.com/Thaomtam/sing-box/main/dns.sh)"
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
