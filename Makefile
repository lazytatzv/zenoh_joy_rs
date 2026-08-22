.PHONY: help build release run check test clean

help:
	@echo "=========================================================="
	@echo " zenoh_joy_rs - Native Teleoperation Controller Publisher"
	@echo "=========================================================="
	@echo " make run       : Run in debug mode"
	@echo " make release   : Build optimized standalone binary"
	@echo " make check     : Fast compile check"
	@echo " make test      : Run test suite"
	@echo " make clean     : Clean build artifacts"
	@echo "=========================================================="

check:
	cargo check

build:
	cargo build

release:
	cargo build --release

run:
	cargo run -- --config config/zenoh_joy.yaml

test:
	cargo test

clean:
	cargo clean
