# Bluetooth PAN (Personal Area Network) Setup Guide

This guide walks you through configuring a redundant Bluetooth link (`bnep0`) between Raspberry Pi and Robot PC.

---

## 1. Robot PC (PAN Access Point / Server)

Run this once on the Robot PC to allow incoming Bluetooth network connections:

```bash
# 1. Install bridge & network tools
sudo apt install -y bluez-tools bridge-utils

# 2. Configure Bluetooth daemon for Network Access Point (NAP)
sudo bt-adapter --set Discoverable 1

# 3. Start PAN server on Robot PC (assigns IP 192.168.44.1)
sudo bt-network -s nap pan0 &
sudo ip addr add 192.168.44.1/24 dev pan0
sudo ip link set pan0 up
```

---

## 2. Raspberry Pi (PAN Client / Sender)

Connect Raspberry Pi to the Robot PC over Bluetooth:

```bash
# 1. Pair with Robot PC (replace with Robot PC Bluetooth MAC)
bluetoothctl
# Inside bluetoothctl:
# scan on
# pair <ROBOT_BT_MAC>
# trust <ROBOT_BT_MAC>
# exit

# 2. Connect to PAN network
sudo bt-network -c <ROBOT_BT_MAC> nap

# 3. Assign client IP (192.168.44.2)
sudo ip addr add 192.168.44.2/24 dev bnep0
sudo ip link set bnep0 up

# 4. Verify connectivity
ping -c 3 192.168.44.1
```

---

## 3. Persistent Auto-Connect on Boot (Systemd)

Create `/etc/systemd/system/bt-pan-client.service` on Raspberry Pi:

```ini
[Unit]
Description=Bluetooth PAN Client Auto-Connect
After=bluetooth.target

[Service]
Type=forking
ExecStart=/usr/bin/bt-network -c <ROBOT_BT_MAC> nap
ExecStartPost=/usr/sbin/ip addr add 192.168.44.2/24 dev bnep0
ExecStartPost=/usr/sbin/ip link set bnep0 up
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
sudo systemctl enable --now bt-pan-client.service
```
