# zenoh_joy_rs (Rust Native Teleop Publisher)

Raspberry Pi上で動作する、**超低遅延・高信頼・メモリ安全なZenohコントローラー送信機**です。

---

## 🌟 特徴

1. **シングルバイナリ・超軽量:**
   - ビルドすると `zenoh_joy_rs` 単一の実行ファイルになり、RasPi側にランタイムや外部依存が一切不要。
2. **ROS 2ノード不要 (Zenoh-ROS2 Bridge直接連携):**
   - ROS 2の標準形式（CDRシリアライズされた `sensor_msgs/msg/Joy`）をネイティブ出力。ロボット側は `zenoh-bridge-ros2dds` を通すだけで `/joy` トピックが自動出現します。
3. **完全なホットプラグ対応:**
   - コントローラーのケーブルが抜けてもクラッシュせず、切断中は安全な `axes=0` を出力しながら自動再接続を監視。
4. **自動 E-Stop (緊急停止):**
   - `Ctrl+C` や `SIGTERM` を検知すると、即座に停止用Joyパケットを連射して安全にシャットダウン。

---

## 🚀 使い方

### ビルド & 実行
```bash
cd zenoh_joy_rs

# 開発実行
make run

# リリースビルド（スタンドアロン単一バイナリ作成）
make release
```

生成されたバイナリ: `target/release/zenoh_joy_rs` (RasPiにこの1ファイルだけコピーすればOK)
