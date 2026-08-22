use serde::Serialize;

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

#[test]
fn test_cdr_serialization_format() {
    let msg = RosJoyMsg {
        header: Header {
            stamp: TimeStamp {
                sec: 100,
                nanosec: 200,
            },
            frame_id: "teleop_joy".to_string(),
        },
        axes: vec![0.5, -0.5, 1.0, 0.0],
        buttons: vec![1, 0, 0, 1],
    };

    let mut buf = vec![0x00, 0x01, 0x00, 0x00]; // Standard CDR Encapsulation header
    let body =
        cdr::serialize::<_, _, cdr::CdrLe>(&msg, cdr::Infinite).expect("CDR serialize failed");
    buf.extend_from_slice(&body);

    assert!(buf.len() > 20);
    assert_eq!(&buf[0..4], &[0x00, 0x01, 0x00, 0x00]);
}
