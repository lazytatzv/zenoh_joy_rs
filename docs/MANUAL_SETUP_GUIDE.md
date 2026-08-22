# Manual Build & Configuration Guide (Linux / PC / SBC)

This guide walks you through building, configuring, granting permissions, and deploying `zenoh_joy_rs` completely from source on any Linux machine (PC, Raspberry Pi, Jetson, Orange Pi, etc.).

---

## 1. Prerequisites (Rust Toolchain)

Ensure Rust (1.75+) is installed:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

---

## 2. Build the Binary

```bash
# Clone the repository
git clone git@github.com:lazytatzv/zenoh_joy_rs.git
cd zenoh_joy_rs

# Build maximum performance release binary
cargo build --release

# The compiled binary is located at:
# target/release/zenoh_joy_rs
```

---

## 3. Gamepad udev Permissions (Non-Root Access)

By default, Linux restricts `/dev/input/event*` to `root`. To allow regular users to access gamepads without `sudo`:

```bash
# Copy included udev rules
sudo cp udev/99-gamepad-teleop.rules /etc/udev/rules.d/

# Reload rules and trigger
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## 4. Custom Configuration (`config/zenoh_joy.yaml`)

Copy the template and edit your network endpoints:

```bash
mkdir -p ~/.config/zenoh_joy
cp config/zenoh_joy.yaml ~/.config/zenoh_joy/teleop.yaml
```

Edit `~/.config/zenoh_joy/teleop.yaml`:

```yaml
device:
  name_keyword: ""             # Empty = auto-detect first connected gamepad
  reconnect_interval_ms: 1000  # Reconnection retry interval

network:
  send_rate_hz: 100            # Streaming rate (Hz)
  connect_endpoints:
    - "udp/192.168.11.100:7447" # Robot PC Wi-Fi IP
    - "udp/192.168.44.1:7447"   # Robot PC Bluetooth PAN IP (Optional)

ros:
  topic_name: "joy"            # Target ROS 2 topic (/joy)
  frame_id: "teleop_joy"       # Header frame_id
```

---

## 5. Running the Application

### Option A: Run directly in terminal
```bash
./target/release/zenoh_joy_rs --config ~/.config/zenoh_joy/teleop.yaml
```

### Option B: Install to System PATH
```bash
cargo install --path .
# Now executable anywhere:
zenoh_joy_rs --config ~/.config/zenoh_joy/teleop.yaml
```

---

## 6. (Optional) Manual Systemd Daemon Service Setup

To have your custom build run automatically in the background on boot:

```bash
# 1. Install binary to system path
sudo cp target/release/zenoh_joy_rs /usr/local/bin/

# 2. Place config in standard system location
sudo mkdir -p /usr/local/etc/zenoh_joy
sudo cp ~/.config/zenoh_joy/teleop.yaml /usr/local/etc/zenoh_joy/zenoh_joy.yaml

# 3. Install and enable systemd service
sudo cp systemd/zenoh_joy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now zenoh_joy.service

# Check status:
sudo systemctl status zenoh_joy
sudo journalctl -u zenoh_joy -f
```
