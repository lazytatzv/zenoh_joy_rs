#!/usr/bin/env bash
# ==============================================================================
# Automated Bluetooth PAN Setup & Systemd Auto-Connect Daemon Provisioner
# Usage:
#   sudo bash scripts/setup_bt_pan.sh server              # On Robot PC (Server: 192.168.44.1)
#   sudo bash scripts/setup_bt_pan.sh client <ROBOT_MAC> # On RasPi (Client: 192.168.44.2)
# ==============================================================================
set -euo pipefail

ROLE="${1:-}"
ROBOT_MAC="${2:-}"

if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run with sudo: sudo bash scripts/setup_bt_pan.sh [server|client <MAC>]"
  exit 1
fi

# Ensure bluez and networking tools are installed
apt-get update -qq && apt-get install -y -qq bluez-tools bridge-utils iproute2 > /dev/null

if [ "$ROLE" == "server" ]; then
  echo "=========================================================="
  echo " Configuring Robot PC as Bluetooth PAN Access Point (NAP)"
  echo " IP Address: 192.168.44.1/24"
  echo "=========================================================="

  # Enable Bluetooth discoverable
  bt-adapter --set Discoverable 1 || true

  # Setup systemd service for PAN NAP server
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
  echo "[+] Bluetooth PAN Server successfully configured and running on Robot PC (192.168.44.1)!"

elif [ "$ROLE" == "client" ]; then
  if [ -z "$ROBOT_MAC" ]; then
    echo "[!] Error: Missing Robot PC Bluetooth MAC address."
    echo "    Usage: sudo bash scripts/setup_bt_pan.sh client AA:BB:CC:DD:EE:FF"
    exit 1
  fi

  echo "=========================================================="
  echo " Configuring Raspberry Pi as Bluetooth PAN Client"
  echo " Target Robot MAC: $ROBOT_MAC"
  echo " IP Address: 192.168.44.2/24"
  echo "=========================================================="

  # Trust device
  bluetoothctl trust "$ROBOT_MAC" || true

  # Setup systemd client service with auto-reconnect
  cat << SERVICE > /etc/systemd/system/bt-pan-client.service
[Unit]
Description=Bluetooth PAN Client Auto-Connect to Robot
After=bluetooth.target
Wants=bluetooth.target

[Service]
Type=forking
ExecStart=/usr/bin/bt-network -c ${ROBOT_MAC} nap
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
  echo "[+] Bluetooth PAN Client successfully configured on Raspberry Pi (192.168.44.2)!"

else
  echo "[!] Invalid argument."
  echo "Usage:"
  echo "  Robot PC (Server): sudo bash scripts/setup_bt_pan.sh server"
  echo "  RasPi (Client)   : sudo bash scripts/setup_bt_pan.sh client <ROBOT_BT_MAC>"
  exit 1
fi
