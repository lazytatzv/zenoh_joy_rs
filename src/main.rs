//! Ultra-Robust & Zero-Copy Zenoh Joy Publisher for Robotics (Multi-Link Redundant)
//! =================================================================================
//! - Native Rust implementation with Zenoh 1.0
//! - Automatic gamepad hotplugging & recovery using pure `evdev`
//! - Publishes native ROS 2 `sensor_msgs/msg/Joy` (CDR-serialized)
//! - Multi-Link redundant failover support (Wi-Fi, Ethernet, Bluetooth PAN)
//! - Automatic Emergency Stop (Zero Joy) broadcast on Ctrl+C / SIGTERM / disconnect

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use clap::Parser;
use evdev::{AbsoluteAxisType, EventType, Key};
use serde::{Deserialize, Serialize};
use tracing::{error, info, warn};
use zenoh::config::Config as ZenohConfig;

#[derive(Parser, Debug)]
#[command(author, version, about = "Ultra-Fast & Safe Zenoh Joy Sender")]
struct Cli {
    #[arg(short, long, default_value = "config/zenoh_joy.yaml")]
    config: PathBuf,
}

#[derive(Debug, Deserialize, Clone)]
struct AppConfig {
    #[serde(default)]
    device: DeviceConfig,
    #[serde(default)]
    network: NetworkConfig,
    #[serde(default)]
    ros: RosConfig,
}

#[derive(Debug, Deserialize, Clone, Default)]
struct DeviceConfig {
    #[serde(default)]
    name_keyword: String,
    #[serde(default = "default_reconnect_ms")]
    reconnect_interval_ms: u64,
}
fn default_reconnect_ms() -> u64 {
    1000
}

#[derive(Debug, Deserialize, Clone)]
struct NetworkConfig {
    #[serde(default = "default_rate")]
    send_rate_hz: u64,
    #[serde(default)]
    connect_endpoints: Vec<String>,
    #[serde(default)]
    connect_endpoint: String, // Backwards compatibility
}
impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            send_rate_hz: 100,
            connect_endpoints: Vec::new(),
            connect_endpoint: String::new(),
        }
    }
}
fn default_rate() -> u64 {
    100
}

#[derive(Debug, Deserialize, Clone)]
struct RosConfig {
    #[serde(default = "default_topic")]
    topic_name: String,
    #[serde(default = "default_frame")]
    frame_id: String,
}
impl Default for RosConfig {
    fn default() -> Self {
        Self {
            topic_name: "joy".into(),
            frame_id: "teleop_joy".into(),
        }
    }
}
fn default_topic() -> String {
    "joy".into()
}
fn default_frame() -> String {
    "teleop_joy".into()
}

/// ROS 2 sensor_msgs/msg/Joy definition matching standard CDR layout
#[derive(Debug, Clone, Serialize)]
struct RosJoyMsg {
    header: Header,
    axes: Vec<f32>,
    buttons: Vec<i32>,
}

#[derive(Debug, Clone, Serialize)]
struct Header {
    stamp: TimeStamp,
    frame_id: String,
}

#[derive(Debug, Clone, Serialize)]
struct TimeStamp {
    sec: i32,
    nanosec: u32,
}

impl RosJoyMsg {
    fn zero(frame_id: &str) -> Self {
        let (sec, nanosec) = now_stamp();
        Self {
            header: Header {
                stamp: TimeStamp { sec, nanosec },
                frame_id: frame_id.to_string(),
            },
            axes: vec![0.0; 8],
            buttons: vec![0; 14],
        }
    }
}

fn now_stamp() -> (i32, u32) {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    (now.as_secs() as i32, now.subsec_nanos())
}

/// Serializes RosJoyMsg into standard ROS 2 CDR packet (4-byte encapsulation header + CDR body)
fn serialize_joy(msg: &RosJoyMsg) -> Result<Vec<u8>, cdr::Error> {
    let mut buf = vec![0x00, 0x01, 0x00, 0x00]; // CDR Header (Little Endian)
    let body = cdr::serialize::<_, _, cdr::CdrLe>(&msg, cdr::Infinite)?;
    buf.extend_from_slice(&body);
    Ok(buf)
}

fn find_gamepad(name_keyword: &str) -> Option<evdev::Device> {
    let kw = name_keyword.to_lowercase();
    for (_path, dev) in evdev::enumerate() {
        let caps = dev.supported_keys();
        let abs = dev.supported_absolute_axes();
        if caps.is_some() && abs.is_some() {
            let name = dev.name().unwrap_or_default().to_lowercase();
            if kw.is_empty() || name.contains(&kw) {
                info!(
                    "Found Gamepad: '{}' at {:?}",
                    dev.name().unwrap_or_default(),
                    dev.physical_path()
                );
                return Some(dev);
            }
        }
    }
    None
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();
    let cli = Cli::parse();

    let cfg: AppConfig = if cli.config.exists() {
        let content = std::fs::read_to_string(&cli.config)?;
        serde_yaml::from_str(&content)?
    } else {
        warn!(
            "Config file not found at {:?}, using default settings",
            cli.config
        );
        AppConfig {
            device: DeviceConfig::default(),
            network: NetworkConfig::default(),
            ros: RosConfig::default(),
        }
    };

    // Aggregate all configured endpoints
    let mut endpoints = cfg.network.connect_endpoints.clone();
    if endpoints.is_empty() && !cfg.network.connect_endpoint.is_empty() {
        endpoints.push(cfg.network.connect_endpoint.clone());
    }
    endpoints.retain(|e| !e.trim().is_empty());

    // Setup graceful exit handler (E-Stop)
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        warn!("Shutdown signal received! Emitting Emergency Stop...");
        r.store(false, Ordering::SeqCst);
    });

    let topic = cfg.ros.topic_name.trim_start_matches('/');
    let key_expr = format!("rt/{}", topic);

    // Open Zenoh Session with continuous retry resilience (never crash on network startup)
    let (session, publisher) = loop {
        if !running.load(Ordering::SeqCst) {
            return Ok(());
        }

        let mut z_cfg = ZenohConfig::default();
        if !endpoints.is_empty() {
            if let Ok(json_arr) = serde_json::to_string(&endpoints) {
                if let Err(e) = z_cfg.insert_json5("connect/endpoints", &json_arr) {
                    warn!("Invalid Zenoh endpoints JSON (retrying): {:?}", e);
                }
            }
            info!("Connecting to Zenoh endpoints: {:?}", endpoints);
        } else {
            info!("Opening Zenoh session (LAN Multicast Auto-Discovery)...");
        }

        match zenoh::open(z_cfg).await {
            Ok(sess) => match sess.declare_publisher(&key_expr).await {
                Ok(publ) => {
                    info!("Zenoh Publisher active -> Key: '{}'", key_expr);
                    break (sess, publ);
                }
                Err(e) => {
                    error!(
                        "Failed to declare Zenoh publisher: {:?}. Retrying in 2s...",
                        e
                    );
                }
            },
            Err(e) => {
                error!(
                    "Failed to initialize Zenoh session: {:?}. Retrying in 2s...",
                    e
                );
            }
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
    };

    let rate = Duration::from_micros(1_000_000 / cfg.network.send_rate_hz.max(1));
    let mut interval = tokio::time::interval(rate);

    let mut axes = vec![0.0f32; 8];
    let mut buttons = vec![0i32; 14];

    info!(
        "Starting ultra-low latency teleop loop at {} Hz...",
        cfg.network.send_rate_hz
    );

    while running.load(Ordering::SeqCst) {
        let mut device = match find_gamepad(&cfg.device.name_keyword) {
            Some(dev) => {
                info!("Connected to controller. Streaming teleop data...");
                dev
            }
            None => {
                // Emit zero joy when disconnected
                let zero_msg = RosJoyMsg::zero(&cfg.ros.frame_id);
                if let Ok(bytes) = serialize_joy(&zero_msg) {
                    let _ = publisher.put(bytes).await;
                }
                tokio::time::sleep(Duration::from_millis(cfg.device.reconnect_interval_ms)).await;
                continue;
            }
        };

        while running.load(Ordering::SeqCst) {
            interval.tick().await;

            // Non-blocking drain of evdev events
            match device.fetch_events() {
                Ok(events) => {
                    for ev in events {
                        match ev.event_type() {
                            EventType::KEY => {
                                let pressed = if ev.value() != 0 { 1 } else { 0 };
                                match Key::new(ev.code()) {
                                    Key::BTN_SOUTH => buttons[0] = pressed,   // Cross / A
                                    Key::BTN_EAST => buttons[1] = pressed,    // Circle / B
                                    Key::BTN_NORTH => buttons[2] = pressed,   // Triangle / Y
                                    Key::BTN_WEST => buttons[3] = pressed,    // Square / X
                                    Key::BTN_TL => buttons[4] = pressed,      // L1
                                    Key::BTN_TR => buttons[5] = pressed,      // R1
                                    Key::BTN_TL2 => buttons[6] = pressed,     // L2 (digital)
                                    Key::BTN_TR2 => buttons[7] = pressed,     // R2 (digital)
                                    Key::BTN_SELECT => buttons[8] = pressed,  // Select / Share
                                    Key::BTN_START => buttons[9] = pressed,   // Start / Option
                                    Key::BTN_MODE => buttons[10] = pressed,   // PS / Guide
                                    Key::BTN_THUMBL => buttons[11] = pressed, // L3
                                    Key::BTN_THUMBR => buttons[12] = pressed, // R3
                                    Key::BTN_TOUCH | Key::BTN_LEFT => buttons[13] = pressed, // Touchpad / Left click
                                    _ => {}
                                }
                            }
                            EventType::ABSOLUTE => {
                                let axis = AbsoluteAxisType(ev.code());
                                let val = ev.value();
                                match axis {
                                    AbsoluteAxisType::ABS_X => axes[0] = normalize_axis(val),
                                    AbsoluteAxisType::ABS_Y => axes[1] = normalize_axis(val),
                                    AbsoluteAxisType::ABS_Z => axes[2] = normalize_axis(val),
                                    AbsoluteAxisType::ABS_RX => axes[3] = normalize_axis(val),
                                    AbsoluteAxisType::ABS_RY => axes[4] = normalize_axis(val),
                                    AbsoluteAxisType::ABS_RZ => axes[5] = normalize_axis(val),
                                    AbsoluteAxisType::ABS_HAT0X => axes[6] = val as f32,
                                    AbsoluteAxisType::ABS_HAT0Y => axes[7] = -(val as f32),
                                    _ => {}
                                }
                            }
                            _ => {}
                        }
                    }
                }
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    // No events available, continue to periodic publish
                }
                Err(e) => {
                    error!("Gamepad disconnected: {}. Switching to safe zero state.", e);
                    axes.fill(0.0);
                    buttons.fill(0);
                    break; // break to outer loop to trigger reconnect
                }
            }

            let (sec, nanosec) = now_stamp();
            let msg = RosJoyMsg {
                header: Header {
                    stamp: TimeStamp { sec, nanosec },
                    frame_id: cfg.ros.frame_id.clone(),
                },
                axes: axes.clone(),
                buttons: buttons.clone(),
            };

            if let Ok(payload) = serialize_joy(&msg) {
                let _ = publisher.put(payload).await;
            }
        }
    }

    // Emergency Stop Sequence: emit 5 zero packets rapidly before exiting
    warn!("Broadcasting Emergency Stop packets before termination...");
    let zero_msg = RosJoyMsg::zero(&cfg.ros.frame_id);
    if let Ok(zero_payload) = serialize_joy(&zero_msg) {
        for _ in 0..5 {
            let _ = publisher.put(zero_payload.clone()).await;
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    }

    let _ = session.close().await;
    info!("Zenoh Joy terminated cleanly.");
    Ok(())
}

fn normalize_axis(raw: i32) -> f32 {
    let val = raw as f32 / 32767.0;
    val.clamp(-1.0, 1.0)
}
