#!/usr/bin/env bash
# ==============================================================================
# Automated Bluetooth PAN Provisioner (Robot PC Server / RasPi Client)
# Usage:
#   sudo bash scripts/setup_bt_pan.sh                     # On Robot PC (Auto Server: 192.168.44.1)
#   sudo bash scripts/setup_bt_pan.sh server              # On Robot PC (Explicit Server: 192.168.44.1)
#   sudo bash scripts/setup_bt_pan.sh <ROBOT_BT_MAC>      # On RasPi (Auto Client: 192.168.44.2)
#   sudo bash scripts/setup_bt_pan.sh client <ROBOT_MAC> # On RasPi (Explicit Client: 192.168.44.2)
# ==============================================================================
set -euo pipefail

ARG1="${1:-}"
ARG2="${2:-}"

if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run with sudo: sudo bash scripts/setup_bt_pan.sh [<ROBOT_BT_MAC>]"
  exit 1
fi

apt-get update -qq && apt-get install -y -qq bluez-tools bridge-utils iproute2 > /dev/null

# Determine Server vs Client
if [ -z "$ARG1" ] || [ "$ARG1" == "server" ]; then
  # Configure as Robot PC PAN Server (192.168.44.1)
  echo "=========================================================="
  echo " Configuring Robot PC as Bluetooth PAN Access Point (NAP)"
  echo " IP Address: 192.168.44.1/24"
  echo "=========================================================="

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
  echo "[+] Bluetooth PAN Server active on Robot PC (192.168.44.1)!"

else
  # Configure as RasPi PAN Client (192.168.44.2)
  ROBOT_MAC="$ARG1"
  if [ "$ARG1" == "client" ]; then
    ROBOT_MAC="$ARG2"
  fi

  if [ -z "$ROBOT_MAC" ]; then
    echo "[!] Error: Missing Robot PC Bluetooth MAC address."
    echo "    Usage: sudo bash scripts/setup_bt_pan.sh <ROBOT_BT_MAC>"
    exit 1
  fi

  echo "=========================================================="
  echo " Configuring Raspberry Pi as Bluetooth PAN Client"
  echo " Target Robot MAC: $ROBOT_MAC"
  echo " IP Address: 192.168.44.2/24"
  echo "=========================================================="

  bluetoothctl trust "$ROBOT_MAC" || true

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
  echo "[+] Bluetooth PAN Client active on Raspberry Pi (192.168.44.2)!"
fi
