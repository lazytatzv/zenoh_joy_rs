# Automated Bluetooth PAN Setup Guide

You can fully automate Bluetooth PAN configuration and auto-reconnect systemd services with the included setup script:

---

## 1. Robot PC Setup (Server: 192.168.44.1)

Run this once on the Robot PC:

```bash
sudo bash scripts/setup_bt_pan.sh server
```

---

## 2. Raspberry Pi Setup (Client: 192.168.44.2)

Run this on Raspberry Pi with your Robot PC's Bluetooth MAC:

```bash
sudo bash scripts/setup_bt_pan.sh client <ROBOT_BLUETOOTH_MAC>
```

This automatically configures the network adapter, sets up persistent auto-reconnection via systemd, and brings up the `bnep0` interface.

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
