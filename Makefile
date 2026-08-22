.PHONY: help build release run check test clean

help:
	@echo "=========================================================="
	@echo " Zenoh Joy (Rust Edition) - Zero-Latency Teleop"
	@echo "=========================================================="
	@echo " make run       : Run in debug mode"
	@echo " make release   : Build optimized standalone single binary"
	@echo " make check     : Fast compile check"
	@echo " make clean     : Clean build artifacts"
	@echo "=========================================================="

check:
	cargo check

build:
	cargo build

release:
	cargo build --release
	@echo "✔ Binary built at target/release/zenoh_joy_rs (Deployable single file!)"

run:
	cargo run -- --config config/zenoh_joy.yaml

clean:
	cargo clean
