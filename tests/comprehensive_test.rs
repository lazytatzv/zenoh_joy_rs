use serde::Serialize;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, PartialEq)]
struct RosJoyMsg {
    header: Header,
    axes: Vec<f32>,
    buttons: Vec<i32>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
struct Header {
    stamp: TimeStamp,
    frame_id: String,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
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

fn normalize_axis(raw: i32) -> f32 {
    let val = raw as f32 / 32767.0;
    val.clamp(-1.0, 1.0)
}

fn serialize_joy(msg: &RosJoyMsg) -> Result<Vec<u8>, cdr::Error> {
    let mut buf = vec![0x00, 0x01, 0x00, 0x00]; // Standard CDR Encapsulation header
    let body = cdr::serialize::<_, _, cdr::CdrLe>(&msg, cdr::Infinite)?;
    buf.extend_from_slice(&body);
    Ok(buf)
}

#[test]
fn test_axis_normalization_limits() {
    assert_eq!(normalize_axis(0), 0.0);
    assert_eq!(normalize_axis(32767), 1.0);
    assert_eq!(normalize_axis(-32767), -1.0);

    // Test clamping for values out of range (hardware anomalies)
    assert_eq!(normalize_axis(40000), 1.0);
    assert_eq!(normalize_axis(-40000), -1.0);
    assert_eq!(normalize_axis(16383), 16383.0 / 32767.0);
}

#[test]
fn test_zero_msg_generation() {
    let zero = RosJoyMsg::zero("test_frame");
    assert_eq!(zero.header.frame_id, "test_frame");
    assert_eq!(zero.axes.len(), 8);
    assert_eq!(zero.buttons.len(), 14);
    assert!(zero.axes.iter().all(|&a| a == 0.0));
    assert!(zero.buttons.iter().all(|&b| b == 0));
}

#[test]
fn test_cdr_packet_determinism_and_boundaries() {
    let msg = RosJoyMsg {
        header: Header {
            stamp: TimeStamp {
                sec: 12345,
                nanosec: 67890,
            },
            frame_id: "teleop_joy".to_string(),
        },
        axes: vec![-1.0, 0.0, 0.5, 1.0, -0.25, 0.75, 0.0, -1.0],
        buttons: vec![1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1],
    };

    let serialized = serialize_joy(&msg).expect("Serialization failed");

    // Check 4-byte CDR Encapsulation Header (Little Endian)
    assert_eq!(&serialized[0..4], &[0x00, 0x01, 0x00, 0x00]);
    assert!(serialized.len() > 60);

    // Verify determinism
    let serialized_again = serialize_joy(&msg).expect("Serialization failed");
    assert_eq!(serialized, serialized_again);
}

#[test]
fn test_endpoint_json_serialization() {
    let endpoints = vec![
        "udp/192.168.11.100:7447".to_string(),
        "udp/192.168.44.1:7447".to_string(),
    ];
    let json_str = serde_json::to_string(&endpoints).expect("JSON serialization failed");
    assert_eq!(
        json_str,
        "[\"udp/192.168.11.100:7447\",\"udp/192.168.44.1:7447\"]"
    );
}

#[test]
fn test_config_parsing_defaults() {
    let yaml_data = r#"
device:
  name_keyword: "DualSense"
network:
  send_rate_hz: 150
ros:
  topic_name: "custom_joy"
"#;
    #[derive(serde::Deserialize)]
    struct TestConfig {
        #[serde(default)]
        device: TestDevice,
        #[serde(default)]
        network: TestNetwork,
        #[serde(default)]
        ros: TestRos,
    }
    #[derive(serde::Deserialize, Default)]
    struct TestDevice {
        name_keyword: String,
        #[serde(default = "default_reconnect")]
        reconnect_interval_ms: u64,
    }
    fn default_reconnect() -> u64 {
        1000
    }

    #[derive(serde::Deserialize, Default)]
    #[allow(dead_code)]
    struct TestNetwork {
        send_rate_hz: u64,
        #[serde(default)]
        connect_endpoints: Vec<String>,
    }
    #[derive(serde::Deserialize, Default)]
    struct TestRos {
        topic_name: String,
        #[serde(default = "default_frame")]
        frame_id: String,
    }
    fn default_frame() -> String {
        "teleop_joy".into()
    }

    let cfg: TestConfig = serde_yaml::from_str(yaml_data).expect("YAML parsing failed");
    assert_eq!(cfg.device.name_keyword, "DualSense");
    assert_eq!(cfg.device.reconnect_interval_ms, 1000);
    assert_eq!(cfg.network.send_rate_hz, 150);
    assert_eq!(cfg.ros.topic_name, "custom_joy");
    assert_eq!(cfg.ros.frame_id, "teleop_joy");
}
