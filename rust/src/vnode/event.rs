//! 事件数据结构 — Dart → Rust → JS 的事件传递协议。
//!
//! [`QBEvent`] 封装了用户交互事件的所有信息，
//! [`EventResult`] 描述了 JS 处理事件后的返回结果。

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use super::node::PropValue;

// ---------------------------------------------------------------------------
// QBEvent — 事件负载
// ---------------------------------------------------------------------------

/// 用户交互事件 — 从 Dart 传递到 JS。
///
/// # 支持的事件类型
/// - `tap` — 点击
/// - `doubleTap` — 双击
/// - `longPress` — 长按
/// - `input` — 输入框内容变化 (data.value = 新内容)
/// - `submit` — 表单提交
/// - `scroll` — 滚动 (data.scrollTop, data.scrollLeft)
/// - `focus` / `blur` — 获取/失去焦点
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QBEvent {
    /// 触发事件的节点 ID。
    pub node_id: u32,

    /// 事件类型名。
    pub event_type: String,

    /// 事件附带数据（如输入值、坐标等）。
    #[serde(default)]
    pub data: HashMap<String, PropValue>,

    /// 事件时间戳（毫秒）。
    #[serde(default)]
    pub timestamp: f64,
}

// ---------------------------------------------------------------------------
// EventResult — JS 处理结果
// ---------------------------------------------------------------------------

/// JS 事件处理函数的返回结果。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "result", rename_all = "camelCase")]
pub enum EventResult {
    /// 事件已处理，无 UI 变化。
    None,
    /// 事件触发了 re-render，返回新的 VNode JSON。
    #[serde(rename_all = "camelCase")]
    Rerender {
        vnode: serde_json::Value,
    },
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serialize_tap_event() {
        let event = QBEvent {
            node_id: 42,
            event_type: "tap".to_string(),
            data: HashMap::new(),
            timestamp: 1234567890.0,
        };

        let json = serde_json::to_string(&event).unwrap();
        assert!(json.contains("\"nodeId\":42"));
        assert!(json.contains("\"eventType\":\"tap\""));
    }

    #[test]
    fn serialize_input_event() {
        let mut data = HashMap::new();
        data.insert("value".to_string(), PropValue::Str("Hello".to_string()));

        let event = QBEvent {
            node_id: 5,
            event_type: "input".to_string(),
            data,
            timestamp: 0.0,
        };

        let json = serde_json::to_string(&event).unwrap();
        let restored: QBEvent = serde_json::from_str(&json).unwrap();
        assert_eq!(restored.node_id, 5);
        assert_eq!(
            restored.data.get("value"),
            Some(&PropValue::Str("Hello".to_string()))
        );
    }

    #[test]
    fn deserialize_event_result_none() {
        let json = r#"{"result":"none"}"#;
        let result: EventResult = serde_json::from_str(json).unwrap();
        assert!(matches!(result, EventResult::None));
    }

    #[test]
    fn deserialize_event_result_rerender() {
        let json = r#"{"result":"rerender","vnode":{"id":1,"type":"view"}}"#;
        let result: EventResult = serde_json::from_str(json).unwrap();
        match result {
            EventResult::Rerender { vnode } => {
                assert_eq!(vnode["id"], 1);
                assert_eq!(vnode["type"], "view");
            }
            _ => panic!("Expected Rerender"),
        }
    }
}
