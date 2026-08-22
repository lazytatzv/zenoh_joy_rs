# Automated Bluetooth PAN Setup Guide

This guide walks you through setting up a redundant Bluetooth Personal Area Network (PAN) link between Raspberry Pi and Robot PC.

---

## 1. Robot PC Setup (Server: 192.168.44.1)

#### Option A: Via ROS 2 Package Command (Recommended)
After building the workspace with `colcon build`:
```bash
ros2 run zenoh_joy_rs setup_bt_pan.sh server
```

#### Option B: Standalone Script Execution
```bash
sudo bash scripts/setup_bt_pan.sh server
```

This creates the `pan0` interface with IP `192.168.44.1` and enables the `bt-pan-server.service` system daemon.

---

## 2. Raspberry Pi Setup (Client: 192.168.44.2)

#### Option A: Automated via All-In-One Installer (Recommended)
Pass the Robot PC Bluetooth MAC address directly to `install.sh`:
```bash
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash -s -- --bt-robot-mac <ROBOT_BT_MAC>
```

#### Option B: Standalone Client Script
```bash
sudo bash scripts/setup_bt_pan.sh client <ROBOT_BT_MAC>
```

This pairs with the Robot PC, configures the `bnep0` interface with IP `192.168.44.2`, and enables persistent auto-reconnection on boot (`bt-pan-client.service`).

---

## 3. Verify Connection

From Raspberry Pi:
```bash
ping -c 3 192.168.44.1
```
