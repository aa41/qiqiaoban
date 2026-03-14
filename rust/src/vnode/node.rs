//! VNode 核心数据结构 — UI 树的轻量级描述。
//!
//! [`VNode`] 是 JS 逻辑层输出的虚拟节点树，经过 Diff → Patch → Flutter Widget 映射。
//!
//! # 数据流
//!
//! ```text
//! JS render() → JSON → VNode Tree → Diff → PatchSet → Dart Widget Factory
//! ```

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// VNode — 虚拟节点
// ---------------------------------------------------------------------------

/// 虚拟节点 — UI 树的核心数据结构。
///
/// 每个 VNode 描述一个 UI 元素，包含类型、属性、样式和子节点。
/// JS 侧通过 render 函数生成 VNode 树，Rust 侧进行 Diff 和布局计算。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VNode {
    /// 节点唯一标识。
    ///
    /// 用于 Diff 算法中的节点匹配和 Dart 侧的 Widget Key。
    pub id: u32,

    /// 节点类型。
    #[serde(rename = "type")]
    pub node_type: VNodeType,

    /// 动态属性（文本内容、图片 URL 、placeholder 等）。
    #[serde(default)]
    pub props: HashMap<String, PropValue>,

    /// 样式属性（Flex 布局 + 视觉样式）。
    #[serde(default)]
    pub style: VNodeStyle,

    /// 已绑定的事件映射（事件类型 → 方法名，如 {"tap": "increment"}）。
    #[serde(default)]
    pub events: HashMap<String, String>,

    /// 子节点列表。
    #[serde(default)]
    pub children: Vec<VNode>,
}

// ---------------------------------------------------------------------------
// VNodeType — 节点类型枚举
// ---------------------------------------------------------------------------

/// 支持的节点类型。
///
/// 每种类型对应一组 Flutter Widget 映射策略。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum VNodeType {
    /// 通用容器 → `Container` / `Flex`
    View,
    /// 文本节点 → `Text`
    Text,
    /// 图片节点 → `Image`
    Image,
    /// 输入框 → `TextField`
    Input,
    /// 按钮 → `ElevatedButton` / `TextButton`
    Button,
    /// 滚动容器 → `ListView` / `SingleChildScrollView`
    ScrollView,
    /// 高性能列表 → `ListView.builder`
    List,
    /// 轮播 → `PageView`
    Swiper,
}

// ---------------------------------------------------------------------------
// PropValue — 属性值
// ---------------------------------------------------------------------------

/// 动态属性值 — 支持多种 JS 原始类型。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum PropValue {
    /// 字符串值。
    Str(String),
    /// 数值（JS 中所有数字都是 f64）。
    Num(f64),
    /// 布尔值。
    Bool(bool),
    /// null。
    Null,
}

impl PropValue {
    /// 尝试获取字符串值。
    pub fn as_str(&self) -> Option<&str> {
        match self {
            PropValue::Str(s) => Some(s),
            _ => None,
        }
    }

    /// 尝试获取数值。
    pub fn as_f64(&self) -> Option<f64> {
        match self {
            PropValue::Num(n) => Some(*n),
            _ => None,
        }
    }

    /// 尝试获取布尔值。
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            PropValue::Bool(b) => Some(*b),
            _ => None,
        }
    }
}

// ---------------------------------------------------------------------------
// VNodeStyle — 节点样式
// ---------------------------------------------------------------------------

/// 节点样式 — 合并 Flex 布局属性和视觉样式。
///
/// 对应 JS 侧 VNode 的 `style` 字段，包含两类属性：
/// 1. **Flex 布局属性** — 传递给 Taffy 进行布局计算
/// 2. **视觉样式属性** — 传递给 Flutter Widget 进行渲染
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VNodeStyle {
    // === Flex 容器属性 ===
    #[serde(default)]
    pub flex_direction: Option<String>,
    #[serde(default)]
    pub flex_wrap: Option<String>,
    #[serde(default)]
    pub justify_content: Option<String>,
    #[serde(default)]
    pub align_items: Option<String>,
    #[serde(default)]
    pub align_content: Option<String>,

    // === Flex 子项属性 ===
    #[serde(default)]
    pub flex_grow: Option<f32>,
    #[serde(default)]
    pub flex_shrink: Option<f32>,
    #[serde(default)]
    pub flex_basis: Option<f32>,
    #[serde(default)]
    pub align_self: Option<String>,

    // === 尺寸 ===
    #[serde(default)]
    pub width: Option<f32>,
    #[serde(default)]
    pub height: Option<f32>,
    #[serde(default)]
    pub min_width: Option<f32>,
    #[serde(default)]
    pub min_height: Option<f32>,
    #[serde(default)]
    pub max_width: Option<f32>,
    #[serde(default)]
    pub max_height: Option<f32>,

    // === 间距 ===
    /// 统一 padding（当 paddingTop/Right/Bottom/Left 未指定时使用）。
    #[serde(default)]
    pub padding: Option<f32>,
    #[serde(default)]
    pub padding_top: Option<f32>,
    #[serde(default)]
    pub padding_right: Option<f32>,
    #[serde(default)]
    pub padding_bottom: Option<f32>,
    #[serde(default)]
    pub padding_left: Option<f32>,

    /// 统一 margin。
    #[serde(default)]
    pub margin: Option<f32>,
    #[serde(default)]
    pub margin_top: Option<f32>,
    #[serde(default)]
    pub margin_right: Option<f32>,
    #[serde(default)]
    pub margin_bottom: Option<f32>,
    #[serde(default)]
    pub margin_left: Option<f32>,

    /// 统一 gap。
    #[serde(default)]
    pub gap: Option<f32>,
    #[serde(default)]
    pub row_gap: Option<f32>,
    #[serde(default)]
    pub column_gap: Option<f32>,

    // === 定位 ===
    #[serde(default)]
    pub position: Option<String>,
    #[serde(default)]
    pub top: Option<f32>,
    #[serde(default)]
    pub right: Option<f32>,
    #[serde(default)]
    pub bottom: Option<f32>,
    #[serde(default)]
    pub left: Option<f32>,

    // === 视觉样式 ===
    /// 背景颜色（#RRGGBB 或 #AARRGGBB）。
    #[serde(default)]
    pub background_color: Option<String>,
    /// 圆角半径。
    #[serde(default)]
    pub border_radius: Option<f32>,
    /// 不透明度 (0.0 - 1.0)。
    #[serde(default)]
    pub opacity: Option<f32>,

    // === 文本样式 ===
    /// 字体大小。
    #[serde(default)]
    pub font_size: Option<f32>,
    /// 字重（"normal"、"bold"、"100"-"900"）。
    #[serde(default)]
    pub font_weight: Option<String>,
    /// 文本颜色。
    #[serde(default)]
    pub color: Option<String>,
    /// 文本对齐（"left"、"center"、"right"）。
    #[serde(default)]
    pub text_align: Option<String>,
    /// 行高。
    #[serde(default)]
    pub line_height: Option<f32>,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deserialize_simple_vnode() {
        let json = r##"{
            "id": 1,
            "type": "view",
            "style": {
                "flexDirection": "column",
                "width": 300,
                "height": 400,
                "backgroundColor": "#FFFFFF"
            },
            "children": [
                {
                    "id": 2,
                    "type": "text",
                    "props": { "content": "Hello 七巧板!" },
                    "style": { "fontSize": 24, "color": "#333333" }
                }
            ]
        }"##;

        let vnode: VNode = serde_json::from_str(json).expect("Failed to parse VNode");

        assert_eq!(vnode.id, 1);
        assert_eq!(vnode.node_type, VNodeType::View);
        assert_eq!(vnode.style.flex_direction.as_deref(), Some("column"));
        assert_eq!(vnode.style.width, Some(300.0));
        assert_eq!(vnode.style.background_color.as_deref(), Some("#FFFFFF"));
        assert_eq!(vnode.children.len(), 1);

        let child = &vnode.children[0];
        assert_eq!(child.id, 2);
        assert_eq!(child.node_type, VNodeType::Text);
        assert_eq!(
            child.props.get("content"),
            Some(&PropValue::Str("Hello 七巧板!".to_string()))
        );
        assert_eq!(child.style.font_size, Some(24.0));
    }

    #[test]
    fn serialize_vnode_roundtrip() {
        let vnode = VNode {
            id: 10,
            node_type: VNodeType::View,
            props: HashMap::new(),
            style: VNodeStyle {
                width: Some(200.0),
                height: Some(100.0),
                background_color: Some("#FF0000".to_string()),
                ..Default::default()
            },
            events: {
                let mut m = HashMap::new();
                m.insert("tap".to_string(), "handleTap".to_string());
                m
            },
            children: vec![VNode {
                id: 11,
                node_type: VNodeType::Text,
                props: {
                    let mut m = HashMap::new();
                    m.insert("content".to_string(), PropValue::Str("Test".to_string()));
                    m
                },
                style: VNodeStyle::default(),
                events: HashMap::new(),
                children: vec![],
            }],
        };

        let json = serde_json::to_string(&vnode).expect("Serialize failed");
        let restored: VNode = serde_json::from_str(&json).expect("Deserialize failed");

        assert_eq!(restored.id, vnode.id);
        assert_eq!(restored.node_type, vnode.node_type);
        assert_eq!(restored.children.len(), 1);
        assert_eq!(restored.events.get("tap").unwrap(), "handleTap");
        assert_eq!(restored.events.len(), 1);
    }

    #[test]
    fn deserialize_all_node_types() {
        let types = [
            ("view", VNodeType::View),
            ("text", VNodeType::Text),
            ("image", VNodeType::Image),
            ("input", VNodeType::Input),
            ("button", VNodeType::Button),
            ("scroll-view", VNodeType::ScrollView),
            ("list", VNodeType::List),
            ("swiper", VNodeType::Swiper),
        ];

        for (name, expected) in types {
            let json = format!(r#"{{"id": 1, "type": "{}"}}"#, name);
            let vnode: VNode = serde_json::from_str(&json).expect(&format!("Parse {name} failed"));
            assert_eq!(vnode.node_type, expected, "Type mismatch for {name}");
        }
    }

    #[test]
    fn prop_value_helpers() {
        assert_eq!(PropValue::Str("hello".into()).as_str(), Some("hello"));
        assert_eq!(PropValue::Num(42.0).as_f64(), Some(42.0));
        assert_eq!(PropValue::Bool(true).as_bool(), Some(true));
        assert_eq!(PropValue::Null.as_str(), None);
    }
}
