#!/usr/bin/env bash
# ==============================================================================
# All-In-One Automated Production Installer for zenoh_joy_rs (Raspberry Pi & Linux)
# ==============================================================================
# Usage:
#   sudo bash install.sh                              # Standard install (Wi-Fi/LAN)
#   sudo bash install.sh --bt-robot-mac AA:BB:CC:DD:EE:FF  # Full install + Auto Bluetooth PAN
# ==============================================================================
set -euo pipefail

REPO="lazytatzv/zenoh_joy_rs"
INSTALL_BIN_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/zenoh_joy"
SYSTEMD_DIR="/etc/systemd/system"
UDEV_DIR="/etc/udev/rules.d"
ROBOT_BT_MAC=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --bt-robot-mac)
      ROBOT_BT_MAC="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "=========================================================="
echo " Starting zenoh_joy_rs All-In-One Production Deployment"
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

# 5. Setup Bluetooth PAN Client if MAC address provided or prompt
if [ -n "$ROBOT_BT_MAC" ]; then
  echo "[*] Setting up Bluetooth PAN Client connection to Robot ($ROBOT_BT_MAC)..."
  apt-get update -qq && apt-get install -y -qq bluez-tools bridge-utils iproute2 > /dev/null
  bluetoothctl trust "$ROBOT_BT_MAC" || true

  cat << SERVICE > /etc/systemd/system/bt-pan-client.service
[Unit]
Description=Bluetooth PAN Client Auto-Connect to Robot
After=bluetooth.target
Wants=bluetooth.target

[Service]
Type=forking
ExecStart=/usr/bin/bt-network -c ${ROBOT_BT_MAC} nap
ExecStartPost=/usr/bin/sleep 1
ExecStartPost=-/usr/sbin/ip addr add 192.168.44.2/24 dev bnep0
ExecStartPost=/usr/sbin/ip link set bnep0 up
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload
  systemctl enable --now bt-pan-client.service
  echo "[+] Bluetooth PAN client service enabled & started (192.168.44.2)!"
fi

# 6. Setup and Enable systemd teleop service
echo "[*] Setting up systemd teleop auto-start daemon..."
cp systemd/zenoh_joy.service "${SYSTEMD_DIR}/"
systemctl daemon-reload
systemctl enable zenoh_joy.service
systemctl restart zenoh_joy.service

echo ""
echo "=========================================================="
echo " All-In-One Deployment Complete & Services Running!"
echo "=========================================================="
echo " Teleop Daemon Status : sudo systemctl status zenoh_joy"
if [ -n "$ROBOT_BT_MAC" ]; then
echo " Bluetooth PAN Status : sudo systemctl status bt-pan-client"
fi
echo " Live Teleop Logs     : sudo journalctl -u zenoh_joy -f"
echo " Config File          : ${CONFIG_DIR}/zenoh_joy.yaml"
echo "=========================================================="
