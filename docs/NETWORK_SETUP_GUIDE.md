# Robotics Network Setup Guide (Wi-Fi & Bluetooth)

This guide covers recommended methods to network the Transmitter (Raspberry Pi) and Robot PC for low-latency, redundant teleoperation.

---

## 1. Primary Link: Wi-Fi Setup

### Option A: Direct Robot Hotspot (Recommended for Field & Competition)
No external router required. The Robot PC broadcasts its own 5GHz Wi-Fi network, and Raspberry Pi connects directly to it.

#### 1. On Robot PC (Create Hotspot)
```bash
# Create persistent 5GHz Wi-Fi Hotspot (SSID: Robot_Teleop, IP default: 10.42.0.1)
sudo nmcli dev wifi hotspot ifname wlan0 ssid Robot_Teleop password "robotpass123"
```

#### 2. On Raspberry Pi (Connect to Hotspot)
```bash
sudo nmcli dev wifi connect Robot_Teleop password "robotpass123"
```

*Zenoh Target Endpoint:* `udp/10.42.0.1:7447`

---

### Option B: Shared Local Router / Access Point
Both Raspberry Pi and Robot PC connect to the same existing lab/office Wi-Fi network.

#### Find Robot PC IP address:
```bash
ip -4 addr show wlan0 | grep "inet "
# Example output: inet 192.168.11.100/24
```

*Zenoh Target Endpoint:* `udp/192.168.11.100:7447`

---

## 2. Secondary Link: Bluetooth PAN Setup (Automatic Redundant Failover)

When Wi-Fi goes out of range or experiences 5GHz/2.4GHz interference, Zenoh automatically switches to Bluetooth PAN (`192.168.44.x`).

### 1. On Robot PC (Server / Access Point)
```bash
# Check Robot Bluetooth MAC address
bluetoothctl show | grep "Controller"
# Output example: Controller AA:BB:CC:DD:EE:FF

# Enable Bluetooth PAN Server daemon (IP: 192.168.44.1)
ros2 run zenoh_joy_rs setup_bt_pan.sh
```

### 2. On Raspberry Pi (Client)
When running `install.sh`, pass the `--bt-robot-mac` argument:
```bash
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash -s -- --bt-robot-mac AA:BB:CC:DD:EE:FF
```

---

## 3. Endpoints Configuration (`/usr/local/etc/zenoh_joy/zenoh_joy.yaml`)

List primary Wi-Fi first, followed by secondary Bluetooth PAN:

```yaml
network:
  send_rate_hz: 100
  connect_endpoints:
    - "udp/10.42.0.1:7447"       # Primary Link: Wi-Fi Hotspot (Zero-Latency UDP)
    - "udp/192.168.44.1:7447"   # Secondary Link: Bluetooth PAN (Automatic Fallback)
```
