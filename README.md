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

Add to your robot workspace `.repos` file (or see [examples/zenoh_joy.repos](examples/zenoh_joy.repos)):

```yaml
repositories:
  zenoh_joy_rs:
    type: git
    url: https://github.com/lazytatzv/zenoh_joy_rs.git
    version: main
```

Import, build, and launch inside your ROS 2 workspace (e.g. `~/ros2_ws`):

```bash
vcs import src < your_robot.repos
rosdep install --from-paths src --ignore-src -r -y
colcon build --packages-select zenoh_joy_rs && source install/setup.bash

# One-command: Configures Bluetooth PAN Server + Launches Teleop Bridge
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

## Complete Usage & Teleop Mapping

### Button & Axis Index Mapping (Standard ROS 2 `sensor_msgs/msg/Joy`)

The raw hardware events are mapped directly into standard ROS 2 Joy indices matching `joy_linux` and DualSense/Xbox standard layout:

| Array Index | Axes (`msg.axes[i]`) | Buttons (`msg.buttons[i]`) |
| :---: | :--- | :--- |
| **0** | Left Stick X `[-1.0 (left), 1.0 (right)]` | Cross / A (`0` or `1`) |
| **1** | Left Stick Y `[-1.0 (down), 1.0 (up)]` | Circle / B (`0` or `1`) |
| **2** | L2 Trigger (Analog) `[-1.0, 1.0]` | Triangle / Y (`0` or `1`) |
| **3** | Right Stick X `[-1.0 (left), 1.0 (right)]` | Square / X (`0` or `1`) |
| **4** | Right Stick Y `[-1.0 (down), 1.0 (up)]` | L1 Bumper (`0` or `1`) |
| **5** | R2 Trigger (Analog) `[-1.0, 1.0]` | R1 Bumper (`0` or `1`) |
| **6** | D-Pad X (Hat) `[-1.0 (left), 1.0 (right)]` | L2 Trigger (Digital) (`0` or `1`) |
| **7** | D-Pad Y (Hat) `[-1.0 (down), 1.0 (up)]` | R2 Trigger (Digital) (`0` or `1`) |
| **8** | — | Select / Share / Create (`0` or `1`) |
| **9** | — | Start / Options (`0` or `1`) |
| **10** | — | PS / Xbox / Guide (`0` or `1`) |
| **11** | — | L3 (Left Stick Click) (`0` or `1`) |
| **12** | — | R3 (Right Stick Click) (`0` or `1`) |
| **13** | — | Touchpad Click (`0` or `1`) |

---

## ROS 2 Launch Usage & Integration

### 1. Launching from CLI

Launch with default configuration (`examples/ros2_zenoh_bridge.json5`):
```bash
ros2 launch zenoh_joy_rs zenoh_teleop.launch.py
```

Pass a custom bridge configuration file via launch argument:
```bash
ros2 launch zenoh_joy_rs zenoh_teleop.launch.py zenoh_config:=/path/to/custom_bridge.json5
```

---

### 2. Embedding inside your Robot Launch File

To launch the Zenoh teleop bridge automatically alongside your robot navigation or motor drivers, include it in your master `robot.launch.py`:

```python
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    zenoh_teleop_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare("zenoh_joy_rs"),
                "launch",
                "zenoh_teleop.launch.py"
            ])
        ]),
        # Optional: override config file
        # launch_arguments={"zenoh_config": "/path/to/custom.json5"}.items()
    )

    return LaunchDescription([
        zenoh_teleop_launch,
        # ... your other robot nodes (navigation, lidar, teleop_twist_joy) ...
    ])
```

---

### 3. Driving Robot with `teleop_twist_joy`

Convert incoming `/joy` to `/cmd_vel` (`geometry_msgs/msg/Twist`) velocity commands:

```bash
ros2 run teleop_twist_joy teleop_node --ros-args -r joy:=/joy
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
