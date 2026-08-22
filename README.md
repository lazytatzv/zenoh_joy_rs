# zenoh_joy_rs

[![CI](https://github.com/lazytatzv/zenoh_joy_rs/actions/workflows/ci.yml/badge.svg)](https://github.com/lazytatzv/zenoh_joy_rs/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zenoh 1.0](https://img.shields.io/badge/zenoh-1.0.0-purple.svg)](https://zenoh.io)
[![Rust](https://img.shields.io/badge/rust-1.75%2B-orange.svg)](https://www.rust-lang.org)

Production-grade, zero-latency teleoperation controller publisher for robotics over Zenoh 1.0.  
Directly streams CDR-serialized `sensor_msgs/msg/Joy` from Raspberry Pi without installing ROS 2 on the transmitter.

---

## Overview

```
[ Transmitter: Raspberry Pi (Linux) ]
  Gamepad (DualSense / Xbox / Custom HID)
       |
  [ zenoh_joy_rs ] (Native Rust Single-Binary / No ROS 2 needed)
       |
       +======================================================+
       | Multi-Link Redundant UDP Transport                   |
       |  -> Primary:   Wi-Fi / Ethernet                      |
       |  -> Secondary: Bluetooth PAN (BNEP)                  |
       +======================================================+
       v (Automatic Zero-Downtime Failover)
[ Receiver: Robot PC (ROS 2) ]
  [ zenoh-bridge-ros2dds ] (Standard daemon / No custom nodes)
       v
     /joy (sensor_msgs/msg/Joy ready for navigation & control)
```

- **Zero ROS 2 on Transmitter**: Single standalone binary (~8MB) on Raspberry Pi.
- **Zero Custom Node on Robot**: Uses standard `zenoh-bridge-ros2dds` daemon.
- **Multi-Link Redundancy**: Seamless automatic failover between Wi-Fi and Bluetooth PAN.
- **Fail-Safe & E-Stop**: Auto-zeros joy output on disconnect and emits emergency stop packets on shutdown.

---

## Quick Usage

### 1. Transmitter Setup (Raspberry Pi)

Install and run as an auto-starting system daemon with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash
```

To configure target endpoints or streaming rate, edit `/usr/local/etc/zenoh_joy/zenoh_joy.yaml`:

```yaml
network:
  send_rate_hz: 100
  connect_endpoints:
    - "udp/192.168.11.100:7447" # Primary: Wi-Fi / Ethernet
    # - "udp/192.168.44.1:7447" # Secondary: Bluetooth PAN (See docs/BLUETOOTH_PAN_SETUP.md)
```

Manage the service:
```bash
sudo systemctl status zenoh_joy    # Check status
sudo journalctl -u zenoh_joy -f    # View live logs
```

---

### 2. Robot PC Setup (ROS 2)

#### Option A: Integrate via VCS / colcon (Recommended)

Add to your robot `.repos` file:

```yaml
repositories:
  zenoh_joy_rs:
    type: git
    url: https://github.com/lazytatzv/zenoh_joy_rs.git
    version: main
```

Import and build inside your ROS 2 workspace:

```bash
cd ~/ros2_ws
vcs import src < robot.repos
rosdep install --from-paths src --ignore-src -r -y
colcon build --packages-select zenoh_joy_rs
source install/setup.bash
```

Launch the bridge:
```bash
ros2 launch zenoh_joy_rs zenoh_teleop.launch.py
```

#### Option B: Standalone CLI (Without building)

Install `zenoh-bridge-ros2dds`:
```bash
sudo apt install ros-${ROS_DISTRO}-zenoh-bridge-ros2dds
```

Run bridge directly:
```bash
zenoh-bridge-ros2dds -c examples/ros2_zenoh_bridge.json5
```

---

### 3. Verify Joy Topic

```bash
# Echo incoming teleop joy data
ros2 topic echo /joy

# Verify streaming rate (100 Hz)
ros2 topic hz /joy
```

---

## Manual Build (Rust)

```bash
# Clone & run locally in debug mode
git clone git@github.com:lazytatzv/zenoh_joy_rs.git
cd zenoh_joy_rs
cargo run -- --config config/zenoh_joy.yaml

# Build standalone release binary
cargo build --release
```

---

## Documentation

- [Bluetooth PAN Redundant Link Setup Guide](docs/BLUETOOTH_PAN_SETUP.md)

---

## License

MIT License. Free for open-source and commercial robotics applications.
