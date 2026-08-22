# zenoh_joy_rs

[![CI](https://github.com/lazytatzv/zenoh_joy_rs/actions/workflows/ci.yml/badge.svg)](https://github.com/lazytatzv/zenoh_joy_rs/actions)
[![Release](https://img.shields.io/github/v/release/lazytatzv/zenoh_joy_rs)](https://github.com/lazytatzv/zenoh_joy_rs/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zenoh 1.0](https://img.shields.io/badge/zenoh-1.0.0-purple.svg)](https://zenoh.io)
[![Rust](https://img.shields.io/badge/rust-1.75%2B-orange.svg)](https://www.rust-lang.org)

Production-grade, zero-latency teleoperation controller publisher for robotics over Zenoh 1.0.  
Directly streams raw CDR-serialized `sensor_msgs/msg/Joy` over **dual redundant links (Wi-Fi + Bluetooth PAN)** without requiring ROS 2 on the transmitter (Raspberry Pi).

---

## Architecture

```
[ Transmitter: Raspberry Pi (Linux) ]
  PS5 DualSense / Gamepad (USB Connected)
       |
  [ zenoh_joy_rs ] (Native Rust Standalone Daemon / Zero ROS 2 footprint)
       |
       +==================================================================+
       | Multi-Link Redundant UDP Transport (Automatic Zero-Downtime)     |
       |  -> Primary Link:   Wi-Fi / Ethernet (udp/192.168.11.100:7447)    |
       |  -> Secondary Link: Bluetooth PAN (BNEP) (udp/192.168.44.1:7447)  |
       +==================================================================+
       v
[ Receiver: Robot PC (ROS 2) ]
  [ zenoh-bridge-ros2dds ] (Standard daemon / No custom nodes)
       v
     /joy (sensor_msgs/msg/Joy ready for teleop & navigation)
```

- **Zero ROS 2 on Transmitter**: Prebuilt single binary (~10MB) deployed via single-line installer.
- **Zero Custom Node on Robot**: Uses standard `zenoh-bridge-ros2dds` daemon.
- **Multi-Link Redundant Failover**: Automatically switches between Wi-Fi and Bluetooth PAN at the Zenoh session layer with zero packet queue lockup (UDP).
- **Industrial Safety**: Continuous hotplug monitoring with automatic zero-output fail-safe and shutdown E-Stop burst.

---

## Step-by-Step Production Setup

### Step 1: Robot PC Setup (ROS 2)

#### 1. Enable Bluetooth PAN Server (Optional for Redundant Link)
Check Robot Bluetooth MAC address:
```bash
bluetoothctl show | grep "Controller"
# Output example: Controller AA:BB:CC:DD:EE:FF (public) [default]
```

Run the automated server provisioner:
```bash
sudo bash scripts/setup_bt_pan.sh server
```

#### 2. Integrate into Robot ROS 2 Workspace via VCS
Add to your robot `.repos` file:
```yaml
repositories:
  zenoh_joy_rs:
    type: git
    url: https://github.com/lazytatzv/zenoh_joy_rs.git
    version: main
```

Import, install dependencies, and build:
```bash
cd ~/ros2_ws
vcs import src < your_robot.repos
rosdep install --from-paths src --ignore-src -r -y
colcon build --packages-select zenoh_joy_rs
source install/setup.bash
```

#### 3. Launch the Bridge
```bash
ros2 launch zenoh_joy_rs zenoh_teleop.launch.py
```
*(Or run standalone CLI: `zenoh-bridge-ros2dds -c examples/ros2_zenoh_bridge.json5`)*

---

### Step 2: Raspberry Pi Setup (Transmitter)

Connect your PS5 DualSense or gamepad via USB, then run the all-in-one automated installer on Raspberry Pi:

```bash
# Full Installation with Automatic Bluetooth PAN Link Setup:
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash -s -- --bt-robot-mac <ROBOT_BT_MAC>

# Or Standard Installation (Wi-Fi / Ethernet only):
# curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash
```

This single command automatically:
1. Downloads the prebuilt release binary (`/usr/local/bin/zenoh_joy_rs`).
2. Configures gamepad udev permission rules.
3. Sets up persistent Bluetooth PAN connection & auto-reconnect service (`bt-pan-client.service`).
4. Starts and enables the teleop daemon on boot (`zenoh_joy.service`).

---

### Step 3: Verify Streaming

On the Robot PC:

```bash
# Verify incoming joy topic
ros2 topic echo /joy

# Verify streaming rate (100 Hz)
ros2 topic hz /joy
```

---

## Configuration (`/usr/local/etc/zenoh_joy/zenoh_joy.yaml`)

```yaml
device:
  name_keyword: ""             # Gamepad name substring (e.g. "Wireless Controller", "Xbox"). Empty = auto-detect.
  reconnect_interval_ms: 1000  # Reconnect polling interval on disconnect

network:
  send_rate_hz: 100            # Streaming frequency in Hz
  connect_endpoints:
    - "udp/192.168.11.100:7447" # Primary: Wi-Fi / Ethernet (Zero-Latency UDP)
    - "udp/192.168.44.1:7447"   # Secondary: Bluetooth PAN (BNEP)

ros:
  topic_name: "joy"            # Target ROS 2 topic (/joy)
  frame_id: "teleop_joy"       # Header frame_id in sensor_msgs/msg/Joy
```

---

## Service Management (Raspberry Pi)

```bash
# Teleoperation daemon
sudo systemctl status zenoh_joy
sudo journalctl -u zenoh_joy -f

# Bluetooth PAN auto-connect client
sudo systemctl status bt-pan-client
```

---

## Manual Build (Rust)

```bash
git clone git@github.com:lazytatzv/zenoh_joy_rs.git
cd zenoh_joy_rs

# Run locally in debug mode
cargo run -- --config config/zenoh_joy.yaml

# Build standalone release binary
cargo build --release
```

---

## License

MIT License. Free for open-source and commercial robotics applications.
