#!/bin/bash

# Update package lists
apt update

# Set sing-box version
export SING_BOX_VERSION=1.8.14
export ARCH=$(case "$(uname -m)" in 
    'x86_64') echo 'amd64' ;;
    'x86' | 'i686' | 'i386') echo '386' ;;
    'aarch64' | 'arm64') echo 'arm64' ;;
    'armv7l') echo 'armv7' ;;
    's390x') echo 's390x' ;;
    *) echo 'Unsupported server architecture'; exit 1 ;;
esac)
echo -e "\nMy server architecture is: $ARCH"

# Stop and disable old sing-box service
systemctl stop sing-box.service
systemctl disable sing-box.service

# Reload systemd daemon
systemctl daemon-reload

# Remove old sing-box installation
rm -rf /etc/sing-box
rm -rf /var/lib/sing-box
rm -f /usr/bin/sing-box
rm -f /etc/systemd/system/sing-box.service

# Configure DNS settings
rm -f /etc/resolv.conf
cat << EOF > /etc/resolv.conf
nameserver 1.1.1.1
options edns0
EOF

# Install resolvconf and configure
apt -y install resolvconf
cat << EOF > /etc/resolvconf/resolv.conf.d/head
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Restart resolvconf service
service resolvconf restart

# Set network configurations
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216

# Set default timezone to Asia/Ho_Chi_Minh
timedatectl set-timezone Asia/Ho_Chi_Minh
echo "Timezone set to Asia/Ho_Chi_Minh"

# Install new sing-box version
wget https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
tar -zxf sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz
mv sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box /usr/bin
rm -rf sing-box-$SING_BOX_VERSION-linux-$ARCH
rm -f sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Create configuration directory and file
mkdir /etc/sing-box
echo "{}" > /etc/sing-box/config.json

# Create sing-box service file
cat <<EOF > /etc/systemd/system/sing-box.service
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

# Configure sing-box with new settings
curl -Lo /etc/sing-box/config.json https://raw.githubusercontent.com/Thaomtam/sing-box/main/httpupgrade.json
systemctl daemon-reload
systemctl enable --now sing-box

# Prompt user for TCP optimization script
read -p "Do you want to run the TCP optimization script? (y/n): " choice
if [ "$choice" == "y" ]; then
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh"
    chmod +x tcp.sh
    ./tcp.sh
fi