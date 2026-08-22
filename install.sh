#!/usr/bin/env bash
# ==============================================================================
# One-Line Automated Installer for zenoh_joy_rs (Raspberry Pi & Linux)
# ==============================================================================
set -euo pipefail

REPO="lazytatzv/zenoh_joy_rs"
INSTALL_BIN_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/zenoh_joy"
SYSTEMD_DIR="/etc/systemd/system"
UDEV_DIR="/etc/udev/rules.d"

echo "=========================================================="
echo " Starting zenoh_joy_rs Automated Production Deployment"
echo "=========================================================="

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run with sudo or as root: sudo bash install.sh"
  exit 1
fi

# 1. Detect Architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    TARGET="x86_64-unknown-linux-gnu"
    ;;
  aarch64|arm64)
    TARGET="aarch64-unknown-linux-gnu"
    ;;
  armv7l|armhf)
    TARGET="armv7-unknown-linux-gnueabihf"
    ;;
  *)
    echo "[!] Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "[*] Detected Architecture: $ARCH ($TARGET)"

# 2. Check if local release binary exists, otherwise fetch from GitHub release
if [ -f "target/release/zenoh_joy_rs" ]; then
  echo "[*] Found locally built release binary. Installing..."
  install -m 755 target/release/zenoh_joy_rs "${INSTALL_BIN_DIR}/zenoh_joy_rs"
else
  echo "[*] Downloading latest release binary from GitHub..."
  DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/zenoh_joy_rs-${TARGET}"
  if curl -fSL "$DOWNLOAD_URL" -o "${INSTALL_BIN_DIR}/zenoh_joy_rs"; then
    chmod 755 "${INSTALL_BIN_DIR}/zenoh_joy_rs"
    echo "[+] Binary successfully installed to ${INSTALL_BIN_DIR}/zenoh_joy_rs"
  else
    echo "[!] Prebuilt binary not available yet on GitHub releases. Compiling locally..."
    if ! command -v cargo &> /dev/null; then
      echo "[!] Rust / Cargo not found. Please install Rust (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)"
      exit 1
    fi
    cargo build --release
    install -m 755 target/release/zenoh_joy_rs "${INSTALL_BIN_DIR}/zenoh_joy_rs"
  fi
fi

# 3. Setup Configuration
mkdir -p "$CONFIG_DIR"
if [ ! -f "${CONFIG_DIR}/zenoh_joy.yaml" ]; then
  echo "[*] Installing default configuration..."
  cp config/zenoh_joy.yaml "${CONFIG_DIR}/zenoh_joy.yaml"
  chmod 644 "${CONFIG_DIR}/zenoh_joy.yaml"
else
  echo "[*] Configuration already exists at ${CONFIG_DIR}/zenoh_joy.yaml (Skipping overwrite)"
fi

# 4. Setup udev rules for Gamepad permissions
echo "[*] Configuring udev rules for gamepad access..."
cp udev/99-gamepad-teleop.rules "${UDEV_DIR}/"
udevadm control --reload-rules
udevadm trigger

# 5. Setup and Enable systemd service
echo "[*] Setting up systemd auto-start daemon..."
cp systemd/zenoh_joy.service "${SYSTEMD_DIR}/"
systemctl daemon-reload
systemctl enable zenoh_joy.service
systemctl restart zenoh_joy.service

echo ""
echo "=========================================================="
echo " Deployment Complete & Daemon Running!"
echo "=========================================================="
echo " Service Status : sudo systemctl status zenoh_joy"
echo " Live Logs      : sudo journalctl -u zenoh_joy -f"
echo " Config File    : ${CONFIG_DIR}/zenoh_joy.yaml"
echo "=========================================================="
