#!/usr/bin/env bash
# ==============================================================================
# Unified All-In-One Production Provisioner for zenoh_joy_rs (Robot PC & RasPi)
# ==============================================================================
# Usage:
#   sudo bash install.sh --robot-pan                     # On Robot PC (Setup Bluetooth PAN Server)
#   sudo bash install.sh                                 # On RasPi (Standard Teleop Daemon)
#   sudo bash install.sh --bt-robot-mac AA:BB:CC:DD:EE:FF # On RasPi (Teleop + Bluetooth PAN Client)
# ==============================================================================
set -euo pipefail

REPO="lazytatzv/zenoh_joy_rs"
INSTALL_BIN_DIR="/usr/local/bin"
CONFIG_DIR="/usr/local/etc/zenoh_joy"
SYSTEMD_DIR="/etc/systemd/system"
UDEV_DIR="/etc/udev/rules.d"
ROBOT_BT_MAC=""
IS_ROBOT_PAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --robot-pan)
      IS_ROBOT_PAN=true
      shift
      ;;
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
echo " Starting zenoh_joy_rs Unified Production Provisioner"
echo "=========================================================="

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run with sudo or as root: sudo bash install.sh"
  exit 1
fi

# ------------------------------------------------------------------------------
# Mode 1: Robot PC Bluetooth PAN Server Provisioning
# ------------------------------------------------------------------------------
if [ "$IS_ROBOT_PAN" = true ]; then
  echo "[*] Configuring Robot PC as Bluetooth PAN Access Point (NAP)..."
  apt-get update -qq && apt-get install -y -qq bluez-tools bridge-utils iproute2 > /dev/null

  bt-adapter --set Discoverable 1 || true

  cat << 'SERVICE' > /etc/systemd/system/bt-pan-server.service
[Unit]
Description=Bluetooth PAN NAP Server
After=bluetooth.target
Wants=bluetooth.target

[Service]
Type=simple
ExecStartPre=-/usr/sbin/ip link del pan0
ExecStartPre=/usr/bin/bt-network -s nap pan0
ExecStartPost=/usr/bin/sleep 1
ExecStartPost=/usr/sbin/ip addr add 192.168.44.1/24 dev pan0
ExecStartPost=/usr/sbin/ip link set pan0 up
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload
  systemctl enable --now bt-pan-server.service
  echo ""
  echo "=========================================================="
  echo " Robot PC Bluetooth PAN Server Active!"
  echo " Server IP       : 192.168.44.1"
  echo " Service Status  : sudo systemctl status bt-pan-server"
  echo "=========================================================="
  exit 0
fi

# ------------------------------------------------------------------------------
# Mode 2: Raspberry Pi / Transmitter Teleop Daemon Provisioning
# ------------------------------------------------------------------------------

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

# 5. Setup Bluetooth PAN Client if MAC address provided
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
  echo "[+] Bluetooth PAN client service active (192.168.44.2)!"
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
