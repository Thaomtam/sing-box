#!/bin/bash

export SING_BOX_VERSION=latest
export ARCH=$(case "$(uname -m)" in 'x86_64') echo 'amd64';; 'x86' | 'i686' | 'i386') echo '386';; 'aarch64' | 'arm64') echo 'arm64';; 'armv7l') echo 'armv7';; 's390x') echo 's390x';; *) echo 'Unsupported server architecture';; esac)
echo -e "\nMy server architecture is: "$ARCH

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

apt -y install resolvconf

cat << EOF > /etc/resolvconf/resolv.conf.d/head
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

service resolvconf restart

# Set timezone and network configurations
timedatectl set-timezone Asia/Ho_Chi_Minh && \
sysctl -w net.core.rmem_max=16777216 && \
sysctl -w net.core.wmem_max=16777216

# Install new sing-box version
wget https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

tar -zxf sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

mv sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box /usr/bin

rm -rf ./sing-box-$SING_BOX_VERSION-linux-$ARCH
rm -f ./sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz

# Create sing-box service file
cat <<EOF> /etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Configure sing-box with new settings
curl -Lo /etc/sing-box/config.json https://raw.githubusercontent.com/Thaomtam/sing-box/main/httpupgrade.json && systemctl daemon-reload && systemctl enable --now sing-box