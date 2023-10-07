#!/bin/bash

apt-get install -y jq
apt-get install -y openssl
apt-get install -y qrencode

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

[[ $EUID -ne 0 ]] && red "Note: Please run the script as root user" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && red "VPS system is currently not supported, please use a universal operating system" && exit 1

# Detect VPS processor architecture
archAffix() {
    case "$(uname -m)" in
        x86_64 | amd64) echo 'amd64' ;;
        armv8 | arm64 | aarch64) echo 'arm64' ;;
        s390x) echo 's390x' ;;
        *) red "Unsupported CPU architecture!" && exit 1 ;;
    esac
}

install_base(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo tar openssl
}

install_singbox(){
    install_base

    last_version=$(curl -s https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | sed -n 4p | tr -d ',"' | awk '{print $1}')
    if [[ -z $last_version ]]; then
        red "Unable to get version information, please check VPS network status!"
        exit 1
    fi

    if [[ $SYSTEM == "CentOS" ]]; then
        wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$(archAffix).rpm -O sing-box.rpm
        rpm -ivh sing-box.rpm
        rm -f sing-box.rpm
    else
        wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$(archAffix).deb -O sing-box.deb
        dpkg -i sing-box.deb
        rm -f sing-box.deb
    fi

    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        green "Sing-box has been installed successfully!"
    else
        red "Sing-box không thành công！"
        exit 1
    fi

    # Hỏi người dùng về cổng Reality, UUID và tên miền dự phòng
    read -p "setting Sing-box port [1-65535]（Enter to assign random ports）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} port Already occupied by other programs, please change the port and try again!"
            read -p "setting Sing-box port [1-65535]（Enter to assign random ports）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done
    read -rp "Please enter UUID [Can be left blank to create a script]: " UUID
    [[ -z $UUID ]] && UUID=$(sing-box generate uuid)
    read -rp "Please enterConfigure a backup domain [Sega's default official website]: " dest_server
    [[ -z $dest_server ]] && dest_server="www.sega.com"

    # Reality short-id
    short_id=$(openssl rand -hex 8)

    # Reality public and private 
    keys=$(sing-box generate reality-keypair)
    private_key=$(echo $keys | awk -F " " '{print $2}')
    public_key=$(echo $keys | awk -F " " '{print $4}')

    # Xóa file cấu hình mặc định và ghi cấu hình Reality
    rm -f /etc/sing-box/config.json
    cat << EOF > /etc/sing-box/config.json
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
            "listen_port": $port,
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "uuid": "$UUID",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$dest_server",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "1.1.1.1",
                        "server_port": 443
                    },
                    "private_key": "$private_key",
                    "short_id": [
                        "$short_id"
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
    ],
    "route": {
        "rules": [
            {
                "outbound": "block"
            },
            {
                "geosite": "category-ads-all",
                "outbound": "block"
            }
        ],
        "final": "direct"
    }
}
EOF

systemctl restart sing-box

url="vless://$UUID@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#THOITIET-SINGBOX"
echo "$url"

qrencode -s 120 -t ANSIUTF8 "$url"
qrencode -s 50 -o qr.png "$url"

exit 0
