#!/bin/bash

# Set sing-box version and architecture
export SING_BOX_VERSION=v1.8.8.h4
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
curl -L -o "$TMP_DIR/sing-box-linux-$ARCH.zip" "https://github.com/hiddify/hiddify-sing-box/releases/download/$SING_BOX_VERSION/sing-box-linux-$ARCH.zip" || { echo "Failed to download sing-box"; exit 1; }
unzip "$TMP_DIR/sing-box-linux-$ARCH.zip" -d "$TMP_DIR" || { echo "Failed to extract sing-box"; exit 1; }

# Move sing-box binary
mv "$TMP_DIR/sing-box" /usr/bin || { echo "Failed to move sing-box binary"; exit 1; }

# Clean up
rm -rf "$TMP_DIR"
systemctl restart sing-box || { echo "Failed to restart sing-box service"; exit 1; }

echo "sing-box updated successfully"
