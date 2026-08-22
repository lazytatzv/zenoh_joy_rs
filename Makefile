.PHONY: help robot raspi launch echo test check release clean

ROBOT_BT_MAC ?=

help:
	@echo "=========================================================="
	@echo " zenoh_joy_rs - One-Command Master Operations"
	@echo "=========================================================="
	@echo " [Robot PC Setup & Run]"
	@echo "   make robot             : Setup Robot (PAN Server + Build + Launch)"
	@echo "   make launch            : Launch ROS 2 teleop bridge"
	@echo "   make echo              : Monitor incoming /joy topic"
	@echo ""
	@echo " [Raspberry Pi / Client Setup]"
	@echo "   make raspi             : One-command full deployment (with optional ROBOT_BT_MAC=...)"
	@echo ""
	@echo " [Development & Verification]"
	@echo "   make test              : Run comprehensive test suite"
	@echo "   make check             : Lint & code formatting check"
	@echo "   make release           : Build release binary"
	@echo "=========================================================="

# One-Command Master Robot Setup (PAN Server + Launch bridge)
robot:
	@sudo bash install.sh --robot-pan
	@ros2 launch zenoh_joy_rs zenoh_teleop.launch.py || zenoh-bridge-ros2dds -c examples/ros2_zenoh_bridge.json5

# One-Command Master Raspberry Pi Client Deployment
raspi:
	@if [ -n "$(ROBOT_BT_MAC)" ]; then \
		sudo bash install.sh --bt-robot-mac $(ROBOT_BT_MAC); \
	else \
		sudo bash install.sh; \
	fi

launch:
	@ros2 launch zenoh_joy_rs zenoh_teleop.launch.py || zenoh-bridge-ros2dds -c examples/ros2_zenoh_bridge.json5

echo:
	ros2 topic echo /joy

test:
	cargo test

check:
	cargo fmt --all -- --check
	cargo clippy -- -D warnings

release:
	cargo build --release

clean:
	cargo clean
