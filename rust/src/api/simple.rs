//! 七巧板基础 API — 用于验证 Dart ↔ Rust 通信链路。
//!
//! 本模块提供最小化的 API 集合，验证以下通信模式：
//! - **同步调用**: Dart → Rust，立即返回结果
//! - **异步调用**: Dart → Rust，返回 Future
//! - **Stream 推送**: Rust → Dart，持续推送数据流

use std::thread;
use std::time::Duration;

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

// ---------------------------------------------------------------------------
// 初始化
// ---------------------------------------------------------------------------

/// 初始化七巧板 Rust 运行时环境。
///
/// 在应用启动时调用一次，设置日志、默认 panic handler 等基础设施。
/// 由 `flutter_rust_bridge` 自动在首次调用前触发。
#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// ---------------------------------------------------------------------------
// 同步 API — Dart → Rust 即时调用
// ---------------------------------------------------------------------------

/// 返回一条问候消息。
///
/// 这是最简单的同步调用示例，用于验证 Dart → Rust FFI 链路连通性。
///
/// # 参数
/// - `name`: 被问候者的名字
///
/// # 返回
/// 格式化的问候字符串
///
/// # 示例 (Dart 侧)
/// ```dart
/// final message = greet(name: "七巧板");
/// // => "Hello, 七巧板! 来自 Rust 🦀"
/// ```
#[frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}! 来自 Rust 🦀")
}

/// 返回 Rust 侧的版本信息。
///
/// 用于在 Dart 侧展示 Rust core 的版本号，方便调试和版本追踪。
#[frb(sync)]
pub fn rust_core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

// ---------------------------------------------------------------------------
// 异步 API — Dart → Rust，返回 Future<T>
// ---------------------------------------------------------------------------

/// 异步累加计算。
///
/// 模拟一个耗时的 Rust 计算任务。在独立线程执行，不会阻塞 Dart UI 线程。
///
/// # 参数
/// - `n`: 累加上限（计算 1 + 2 + ... + n）
///
/// # 返回
/// 累加结果
pub fn sum_to_n(n: i64) -> i64 {
    // 使用高斯公式，但模拟一小段延迟以验证异步行为
    thread::sleep(Duration::from_millis(100));
    n * (n + 1) / 2
}

// ---------------------------------------------------------------------------
// Stream API — Rust → Dart，持续推送
// ---------------------------------------------------------------------------

/// 每秒推送一个递增整数，用于验证 Stream 通信模式。
///
/// 此函数会在独立线程中持续运行，通过 `StreamSink` 向 Dart 侧推送数据。
/// Dart 侧会收到一个 `Stream<i32>`，可通过 `listen` 订阅。
///
/// # 参数
/// - `sink`: 由 `flutter_rust_bridge` 自动注入的 Stream 推送通道
/// - `count`: 推送总次数（推送完毕后 Stream 自动关闭）
///
/// # 示例 (Dart 侧)
/// ```dart
/// tickStream(count: 10).listen((tick) {
///   print('Tick: $tick');
/// });
/// ```
pub fn tick_stream(
    sink: StreamSink<i32>,
    count: i32,
) {
    // 在独立线程中执行，避免阻塞 Rust 的 async runtime
    thread::spawn(move || {
        for i in 1..=count {
            // 推送当前计数值到 Dart
            sink.add(i).expect("Failed to send tick to Dart StreamSink");

            // 每秒推送一次
            if i < count {
                thread::sleep(Duration::from_secs(1));
            }
        }
        // Stream 在 sink drop 时自动关闭
    });
}
