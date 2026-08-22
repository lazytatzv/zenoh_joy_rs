# Automated Bluetooth PAN Setup Guide

You can fully automate Bluetooth PAN configuration and auto-reconnect systemd services using the unified `install.sh` provisioner.

---

## 1. Robot PC Setup (Server: 192.168.44.1)

Run this single command once on the Robot PC:

```bash
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash -s -- --robot-pan
```

This creates the `pan0` network interface with IP `192.168.44.1` and enables the `bt-pan-server.service` system daemon.

---

## 2. Raspberry Pi Setup (Client: 192.168.44.2)

Run this single command on Raspberry Pi with your Robot PC's Bluetooth MAC address:

```bash
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash -s -- --bt-robot-mac <ROBOT_BT_MAC>
```

This pairs with the Robot PC, configures the `bnep0` interface with IP `192.168.44.2`, and enables persistent auto-reconnection on boot (`bt-pan-client.service`).

---

## 3. Verify Connectivity

From Raspberry Pi:
```bash
ping -c 3 192.168.44.1
```
