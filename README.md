# zenoh_joy_rs

[![CI](https://github.com/lazytatzv/zenoh_joy_rs/actions/workflows/ci.yml/badge.svg)](https://github.com/lazytatzv/zenoh_joy_rs/actions)
[![Release](https://img.shields.io/github/v/release/lazytatzv/zenoh_joy_rs)](https://github.com/lazytatzv/zenoh_joy_rs/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zenoh 1.0](https://img.shields.io/badge/zenoh-1.0.0-purple.svg)](https://zenoh.io)
[![Rust](https://img.shields.io/badge/rust-1.75%2B-orange.svg)](https://www.rust-lang.org)

Zero-latency, fail-safe teleoperation controller publisher for robotics over Zenoh 1.0.  
Directly streams raw CDR-serialized `sensor_msgs/msg/Joy` over **dual redundant links (Wi-Fi + Bluetooth PAN)** with zero ROS 2 footprint on Raspberry Pi.

---

## 3-Step Quick Start

### 1. Robot PC Setup (ROS 2)

Inside your ROS 2 workspace (e.g. `~/ros2_ws`):

```bash
# 1. Import repository directly via vcs
vcs import src --input https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/zenoh_joy.repos

# 2. Install dependencies & build
rosdep install --from-paths src --ignore-src -r -y
colcon build --packages-select zenoh_joy_rs && source install/setup.bash

# 3. One-command: Configures Bluetooth PAN Server + Launches Teleop Bridge
make robot
```

---

### 2. Raspberry Pi Setup (Transmitter / Client)

Plug in your PS5 DualSense / Gamepad via USB, then run on Raspberry Pi:

```bash
# Remote one-command deployment:
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash -s -- --bt-robot-mac <ROBOT_BT_MAC>

# Or if cloned locally:
# make raspi ROBOT_BT_MAC=<ROBOT_BT_MAC>
```

---

### 3. Verify Teleop Topic

On Robot PC:

```bash
make echo
```

---

## Configuration (`/usr/local/etc/zenoh_joy/zenoh_joy.yaml`)

```yaml
device:
  name_keyword: ""             # Gamepad name (empty = auto-detect first connected)
  reconnect_interval_ms: 1000  # Reconnect polling interval on disconnect

network:
  send_rate_hz: 100            # Streaming frequency in Hz
  connect_endpoints:
    - "udp/192.168.11.100:7447" # Primary: Wi-Fi / Ethernet (Zero-Latency UDP)
    - "udp/192.168.44.1:7447"   # Secondary: Bluetooth PAN (Automatic Failover)

ros:
  topic_name: "joy"            # Target ROS 2 topic (/joy)
  frame_id: "teleop_joy"       # Header frame_id in sensor_msgs/msg/Joy
```

---

## Daemon Management (Raspberry Pi)

```bash
# View live teleop streaming logs
sudo journalctl -u zenoh_joy -f

# Check status
sudo systemctl status zenoh_joy
```

---

## Documentation & Guides

- [Wi-Fi & Bluetooth Networking Guide](docs/NETWORK_SETUP_GUIDE.md)
- [Bluetooth PAN Setup Details](docs/BLUETOOTH_PAN_SETUP.md)

---

## License

MIT License. Free for open-source and commercial robotics applications.
