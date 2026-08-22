# zenoh_joy_rs

[![CI](https://github.com/lazytatzv/zenoh_joy_rs/actions/workflows/ci.yml/badge.svg)](https://github.com/lazytatzv/zenoh_joy_rs/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zenoh 1.0](https://img.shields.io/badge/zenoh-1.0.0-purple.svg)](https://zenoh.io)
[![Rust](https://img.shields.io/badge/rust-1.75%2B-orange.svg)](https://www.rust-lang.org)

Production-grade, zero-latency teleoperation controller publisher for robotics and embedded systems.
Streams CDR-serialized `sensor_msgs/msg/Joy` directly over **Zenoh 1.0** with **seamless multi-link failover (Wi-Fi, Ethernet, Bluetooth PAN)** without requiring ROS 2 on the transmitter (e.g., Raspberry Pi).

---

## System Architecture

```
[ Transmitter: Raspberry Pi / Linux ]
  Gamepad (DualSense / Xbox / Custom HID)
       |
   (evdev) Non-blocking asynchronous input handling
       |
  [ zenoh_joy_rs ] (Native Rust Standalone Binary)
       | -- Zero-Copy CDR serialization (Native ROS 2 sensor_msgs/Joy)
       | -- Continuous hotplug detection and recovery
       | -- Multi-Link Redundancy (Wi-Fi + Ethernet + Bluetooth PAN)
       | -- Watchdog and E-Stop broadcast on shutdown
       |
       +======================================================+
       | Multi-Link Redundant Failover:                       |
       |  -> Primary:   Wi-Fi / Ethernet (LAN Multicast/TCP)  |
       |  -> Secondary: Bluetooth PAN (BNEP)                  |
       +======================================================+
       v (Zenoh Protocol 1.0 / Low-Latency Routing)
[ Receiver: Robot Main PC ]
  [ zenoh-bridge-ros2dds ] (Standard daemon)
       |
  /joy (Native ROS 2 Topic available immediately)
```

- **Multi-Link Redundant Failover**: Supports simultaneous multi-endpoint routing (e.g., Wi-Fi + Bluetooth PAN). Zenoh seamlessly and automatically routes packets over whichever interface is active.
- **Zero ROS 2 Footprint on Transmitter**: Builds to a single standalone binary (~8MB). No ROS 2 installation or Python runtime required on Raspberry Pi.
- **Zero Custom Node on Receiver**: The robot runs standard `zenoh-bridge-ros2dds` daemon; no custom receiver nodes to maintain.
- **Deterministic and Memory-Safe**: Pure Rust implementation with `tokio` and `evdev`. Zero garbage collection pauses and zero undefined behavior.
- **Industrial Safety**:
  - Hotplug tolerance: Automatically emits zero joy output when disconnected and resumes on reconnect.
  - Emergency Stop: Emits emergency zero joy packets on `SIGINT` / `SIGTERM` before termination.

---

## Quick Start

### 1. Build and Run

```bash
# Clone repository
git clone git@github.com:lazytatzv/zenoh_joy_rs.git
cd zenoh_joy_rs

# Run in debug mode
cargo run -- --config config/zenoh_joy.yaml

# Build optimized release binary
cargo build --release
```

The optimized static binary is placed at: `target/release/zenoh_joy_rs`

---

## Configuration (`config/zenoh_joy.yaml`)

```yaml
device:
  name_keyword: ""             # Match gamepad by name (e.g. "Wireless Controller", "Xbox"). Leave empty for first available device.
  reconnect_interval_ms: 1000  # Poll interval for reconnection when controller is disconnected

network:
  send_rate_hz: 100            # Streaming frequency in Hz

  # Redundant multi-link endpoints (Wi-Fi, Ethernet, Bluetooth PAN)
  # UDP ('udp/') is strongly recommended for real-time teleoperation to eliminate latency spikes.
  # Leave empty for LAN Multicast auto-discovery, or list endpoints:
  connect_endpoints:
    - "udp/192.168.11.100:7447" # Primary: Wi-Fi / Ethernet (Zero-Latency UDP)
    - "udp/192.168.44.2:7447"   # Secondary: Bluetooth PAN (BNEP)

ros:
  topic_name: "joy"            # Target ROS 2 topic name (/joy)
  frame_id: "teleop_joy"       # Header frame_id in sensor_msgs/msg/Joy
```

---

## Setting Up Bluetooth PAN for Redundant Link

To use Bluetooth as a transparent fallback link alongside Wi-Fi, configure a standard Bluetooth Personal Area Network (PAN).
See the complete step-by-step guide: [docs/BLUETOOTH_PAN_SETUP.md](docs/BLUETOOTH_PAN_SETUP.md)

```bash
# On Raspberry Pi (Sender)
sudo bt-network -c <ROBOT_BLUETOOTH_MAC> nap
# Creates 'bnep0' interface (e.g. 192.168.44.2)
```

Zenoh automatically manages multi-link health and failover at the session layer without dropping ROS 2 messages.

---

## Production Deployment (Raspberry Pi)

### One-Line Automated Deployment (Recommended)

Run this single command on Raspberry Pi to automatically install the binary, udev rules, and start the systemd daemon:

```bash
# Automated install & auto-start daemon
curl -sSL https://raw.githubusercontent.com/lazytatzv/zenoh_joy_rs/main/install.sh | sudo bash
```

---

### Manual Deployment

#### 1. Gamepad Device Permissions (udev)
```bash
sudo cp udev/99-gamepad-teleop.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

#### 2. Auto-Start Service (systemd)
```bash
sudo mkdir -p /usr/local/etc/zenoh_joy
sudo cp target/release/zenoh_joy_rs /usr/local/bin/
sudo cp config/zenoh_joy.yaml /usr/local/etc/zenoh_joy/
sudo cp systemd/zenoh_joy.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now zenoh_joy.service
```

---

## Robot Integration (ROS 2)

### 1. Install `zenoh-bridge-ros2dds` on Robot PC

#### Option A: Via ROS 2 APT Repository (Recommended for ROS 2 Humble/Iron/Jazzy)
```bash
# Ubuntu / Debian with ROS 2
sudo apt update
sudo apt install ros-${ROS_DISTRO}-zenoh-bridge-ros2dds
```

#### Option B: Via Eclipse Zenoh Debian Repository
```bash
echo "deb [trusted=yes] https://download.eclipse.org/zenoh/debian-repo/ /" | sudo tee -a /etc/apt/sources.list.d/zenoh.list
sudo apt update
sudo apt install zenoh-bridge-ros2dds
```

#### Option C: Via Prebuilt Standalone Binary / Cargo
```bash
# Direct binary install via cargo
cargo install zenoh-bridge-ros2dds
```

---

### 2. Run the Bridge

```bash
# Start Zenoh-ROS2 Bridge (with optional whitelist config)
zenoh-bridge-ros2dds -c examples/ros2_zenoh_bridge.json5

# Verify published Joy topic in ROS 2
ros2 topic echo /joy
```

---

## Quality Assurance & Verification

```bash
# Fast syntax check
make check

# Lint with Clippy
cargo clippy -- -D warnings

# Run test suite
cargo test
```

---

## License
MIT License. Free for open-source and commercial robotics applications.
