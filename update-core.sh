#!/bin/bash

# Set sing-box version
export SING_BOX_VERSION=1.9.3
export ARCH=$(case "$(uname -m)" in 
    'x86_64') echo 'amd64' ;;
    'x86' | 'i686' | 'i386') echo '386' ;;
    'aarch64' | 'arm64') echo 'arm64' ;;
    'armv7l') echo 'armv7' ;;
    's390x') echo 's390x' ;;
    *) echo 'Unsupported server architecture'; exit 1 ;;
esac)
echo -e "\nMy server architecture is: $ARCH"

# Create a temporary directory
TMP_DIR=$(mktemp -d)
if [ ! -d "$TMP_DIR" ]; then
  echo "Failed to create temporary directory"
  exit 1
fi

# Remove old sing-box installation
rm -f /usr/bin/sing-box

# Download and extract sing-box
curl -L -o "$TMP_DIR/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz" \
"https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz" || { echo "Failed to download sing-box"; exit 1; }
tar -zxf "$TMP_DIR/sing-box-$SING_BOX_VERSION-linux-$ARCH.tar.gz" -C "$TMP_DIR" || { echo "Failed to extract sing-box"; exit 1; }

# Move sing-box binary
mv "$TMP_DIR/sing-box-$SING_BOX_VERSION-linux-$ARCH/sing-box" /usr/bin || { echo "Failed to move sing-box binary"; exit 1; }

# Clean up
rm -rf "$TMP_DIR"
systemctl restart sing-box || { echo "Failed to restart sing-box service"; exit 1; }

echo "sing-box updated successfully"
