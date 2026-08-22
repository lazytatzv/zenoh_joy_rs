.PHONY: help build release run test check robot-pan raspi-install launch echo clean

ROBOT_BT_MAC ?=

help:
	@echo "=========================================================="
	@echo " zenoh_joy_rs - One-Command Operations"
	@echo "=========================================================="
	@echo " [Robot PC]"
	@echo "   make robot-pan        : Provision Robot as Bluetooth PAN server"
	@echo "   make launch           : Launch teleop bridge (zenoh_teleop.launch.py)"
	@echo "   make echo             : Monitor /joy topic"
	@echo ""
	@echo " [Raspberry Pi / Transmitter]"
	@echo "   make raspi-install    : Deploy teleop daemon (+ optional ROBOT_BT_MAC=...)"
	@echo ""
	@echo " [Development]"
	@echo "   make run              : Run locally in debug mode"
	@echo "   make release          : Build release binary"
	@echo "   make test             : Run test suite"
	@echo "   make check            : Syntax & clippy check"
	@echo "=========================================================="

robot-pan:
	sudo bash install.sh --robot-pan

raspi-install:
	@if [ -n "$(ROBOT_BT_MAC)" ]; then \
		sudo bash install.sh --bt-robot-mac $(ROBOT_BT_MAC); \
	else \
		sudo bash install.sh; \
	fi

launch:
	ros2 launch zenoh_joy_rs zenoh_teleop.launch.py

echo:
	ros2 topic echo /joy

run:
	cargo run -- --config config/zenoh_joy.yaml

release:
	cargo build --release

test:
	cargo test

check:
	cargo fmt --all -- --check
	cargo clippy -- -D warnings

clean:
	cargo clean
