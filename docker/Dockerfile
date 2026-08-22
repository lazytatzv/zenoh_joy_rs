# Multi-stage production container for testing & simulation environments
FROM rust:1.75-bookworm AS builder

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
# Pre-fetch dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release && rm -rf src

COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libevdev2 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/zenoh_joy_rs /usr/local/bin/
COPY config/zenoh_joy.yaml /usr/local/etc/zenoh_joy/zenoh_joy.yaml

ENTRYPOINT ["/usr/local/bin/zenoh_joy_rs", "--config", "/usr/local/etc/zenoh_joy/zenoh_joy.yaml"]
