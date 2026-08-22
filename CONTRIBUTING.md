# Contributing to zenoh_joy_rs

We welcome issues and pull requests to improve performance, platform support, and robustness.

## Development Workflow

1. Fork and clone the repository.
2. Ensure you have the stable Rust toolchain installed:
   ```bash
   rustup default stable
   rustup component add clippy rustfmt
   ```
3. Format and verify code before committing:
   ```bash
   cargo fmt --all -- --check
   cargo clippy -- -D warnings
   cargo test
   ```
4. Submit a Pull Request with a clear description of your changes.
