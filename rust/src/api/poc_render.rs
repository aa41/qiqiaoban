//! 三层通信 PoC API — JS 定义 UI → Rust 计算布局 → 返回渲染结果。
//!
//! # 数据流
//!
//! ```text
//! JS 代码 ──eval──→ JSON 节点树 ──parse──→ TaffyTree ──compute──→ 布局结果
//!                                                                   │
//!                                                     Flutter Dart ←─┘
//! ```
//!
//! # 架构说明
//!
//! 本模块使用 rquickjs 的 **同步** `Runtime` / `Context` API，
//! 而非 `AsyncRuntime` / `AsyncContext`。这是因为:
//! 1. flutter_rust_bridge 在独立 isolate 中执行 FFI 调用
//! 2. `block_on(async { ... })` + isolate 线程模型 → 容易出现栈/锁冲突
//! 3. PoC 渲染本质上是同步操作 (JS eval → layout → collect)
//! 4. 同步 API 零开销、零死锁风险

use std::collections::HashMap;

use crate::layout::style::*;
use crate::layout::tree::QBLayoutTree;

// ---------------------------------------------------------------------------
// 渲染节点 — 从 Rust 返回给 Dart 的扁平化数据
// ---------------------------------------------------------------------------

/// 单个渲染节点的完整信息（树结构）。
///
/// x/y 为相对父节点的坐标，children 保持树形结构。
/// `node_type` 支持: "view", "text", "scroll-view", "image", "button", "input"
#[derive(Debug, Clone)]
pub struct RenderNode {
    pub id: String,
    pub node_type: String,
    pub text: Option<String>,
    pub color: Option<String>,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub font_size: Option<f64>,
    pub text_color: Option<String>,
    pub font_weight: Option<String>,
    pub border_radius: Option<f64>,
    pub opacity: Option<f64>,
    pub extra_props: HashMap<String, String>,
    pub events: Vec<String>,
    pub children: Vec<RenderNode>,
}

// ---------------------------------------------------------------------------
// Dart 侧 API
// ---------------------------------------------------------------------------

/// 执行 JS 代码并返回渲染树（单根节点，树结构）。
///
/// 每次调用创建独立的 **同步** QuickJS 引擎 (无 tokio/async)。
/// 返回的 RenderNode 是一棵树，x/y 为相对于父节点的坐标。
pub fn render_from_js(
    js_code: String,
    viewport_width: f64,
    viewport_height: f64,
) -> Result<RenderNode, String> {
    // ---- Step 1: 创建同步 QuickJS 引擎 ----
    eprintln!("[qb:render] Step 1: Creating sync QuickJS engine...");
    let runtime = rquickjs::Runtime::new()
        .map_err(|e| format!("[qb:render] Step 1 FAILED - runtime: {e}"))?;

    // 配置: 64MB 内存, 256MB 栈安全值
    runtime.set_memory_limit(64 * 1024 * 1024);
    runtime.set_max_stack_size(256 * 1024 * 1024);

    let context = rquickjs::Context::full(&runtime)
        .map_err(|e| format!("[qb:render] Step 1 FAILED - context: {e}"))?;

    // 注入 console 桥接
    context.with(|ctx| {
        unsafe {
            let ctx_ptr: *mut rquickjs::qjs::JSContext =
                *(&ctx as *const rquickjs::Ctx as *const *mut rquickjs::qjs::JSContext);
            let rt = rquickjs::qjs::JS_GetRuntime(ctx_ptr);
            rquickjs::qjs::JS_UpdateStackTop(rt);
        }
        ctx.eval::<rquickjs::Value, _>(r#"
            (function() {
                function noop() {}
                globalThis.console = { log: noop, warn: noop, error: noop, info: noop, debug: noop };
            })();
        "#).map(|_| ())
    }).map_err(|e| format!("[qb:render] Console bridge FAILED: {e}"))?;

    eprintln!("[qb:render] Step 1: Engine created OK (sync mode)");

    // ---- Step 2: 在 Context 中执行 JS 代码 ----
    let json_str: String = context.with(|ctx| {
        unsafe {
            let ctx_ptr: *mut rquickjs::qjs::JSContext =
                *(&ctx as *const rquickjs::Ctx as *const *mut rquickjs::qjs::JSContext);
            let rt = rquickjs::qjs::JS_GetRuntime(ctx_ptr);
            rquickjs::qjs::JS_UpdateStackTop(rt);
        }
        eprintln!("[qb:render] Step 2: Evaluating JS ({} bytes)...", js_code.len());

        // JS 层捕获错误，返回序列化的结果或错误信息
        let wrapped = format!(
            r#"(function() {{
                try {{
                    var __r = (function() {{ return {js_code} }})();
                    return JSON.stringify(__r);
                }} catch(e) {{
                    return "QB_JS_ERROR:" + String(e.message || e) + "\n" + String(e.stack || "");
                }}
            }})()"#
        );

        let result: rquickjs::Result<String> = ctx.eval(wrapped.as_str());
        match result {
            Ok(s) => {
                if s.starts_with("QB_JS_ERROR:") {
                    let detail = &s["QB_JS_ERROR:".len()..];
                    Err(format!("[qb:render] Step 2 FAILED - JS error:\n  {detail}"))
                } else {
                    eprintln!("[qb:render] Step 2: JS eval OK ({} bytes result)", s.len());
                    Ok(s)
                }
            }
            Err(e) => {
                // JS 引擎级别的错误 (try/catch 都兜不住的)
                Err(format!("[qb:render] Step 2 FAILED - engine error:\n  {e}"))
            }
        }
    })?;

    // ---- Step 3: 解析 JSON ----
    eprintln!("[qb:render] Step 3: Parsing JSON...");
    let tree_data: serde_json::Value =
        serde_json::from_str(&json_str).map_err(|e| {
            let preview = if json_str.len() > 300 { &json_str[..300] } else { &json_str };
            format!("[qb:render] Step 3 FAILED - JSON parse: {e}\n  Preview: {preview}")
        })?;
    eprintln!("[qb:render] Step 3: JSON parsed OK");

    // ---- Step 4: 构建 Taffy 布局树 ----
    eprintln!("[qb:render] Step 4: Building layout tree...");
    let mut layout_tree = QBLayoutTree::new();
    let mut node_meta: HashMap<u64, NodeMeta> = HashMap::new();

    let root_id = build_layout_node(&tree_data, &mut layout_tree, &mut node_meta, viewport_width)
        .map_err(|e| format!("[qb:render] Step 4 FAILED: {e}"))?;
    eprintln!("[qb:render] Step 4: {} nodes built", node_meta.len());

    // ---- Step 5: 计算布局 ----
    eprintln!("[qb:render] Step 5: Computing layout ({viewport_width}x{viewport_height})...");
    layout_tree.compute_layout(root_id, viewport_width as f32, viewport_height as f32);
    eprintln!("[qb:render] Step 5: Layout computed");

    // ---- Step 6: 收集渲染树 (树结构, 相对坐标) ----
    let root_node = collect_render_tree(root_id, &layout_tree, &node_meta);
    eprintln!("[qb:render] Step 6: Done! root={}", root_node.id);

    Ok(root_node)
}

/// 销毁 PoC 引擎 (兼容旧 API — 现在是 no-op)。
pub fn destroy_poc_engine() -> Result<(), String> {
    Ok(())
}

// ---------------------------------------------------------------------------
// 内部: 节点元数据
// ---------------------------------------------------------------------------

struct NodeMeta {
    id: String,
    node_type: String,
    text: Option<String>,
    color: Option<String>,
    font_size: Option<f64>,
    text_color: Option<String>,
    font_weight: Option<String>,
    border_radius: Option<f64>,
    opacity: Option<f64>,
    extra_props: HashMap<String, String>,
    children: Vec<u64>,
}

// ---------------------------------------------------------------------------
// 内部: JSON → TaffyTree 递归构建
// ---------------------------------------------------------------------------

fn build_layout_node(
    node_json: &serde_json::Value,
    tree: &mut QBLayoutTree,
    meta_map: &mut HashMap<u64, NodeMeta>,
    viewport_width: f64,
) -> Result<u64, String> {
    let obj = node_json
        .as_object()
        .ok_or("Node must be a JSON object")?;

    let id = obj.get("id").and_then(|v| v.as_str()).unwrap_or("anon").to_string();
    let node_type = obj.get("type").and_then(|v| v.as_str()).unwrap_or("view").to_string();
    let text = obj.get("text").and_then(|v| v.as_str()).map(String::from);

    let style_val = obj.get("style").cloned()
        .unwrap_or(serde_json::Value::Object(serde_json::Map::new()));
    let mut style = parse_style(&style_val);

    let color = style_val.get("backgroundColor").and_then(|v| v.as_str()).map(String::from);
    let font_size = style_val.get("fontSize").and_then(|v| v.as_f64());
    let text_color = style_val.get("color").and_then(|v| v.as_str()).map(String::from);
    let font_weight = style_val.get("fontWeight").and_then(|v| v.as_str()).map(String::from);
    let border_radius = style_val.get("borderRadius").and_then(|v| v.as_f64());
    let opacity = style_val.get("opacity").and_then(|v| v.as_f64());

    // ---- 提取组件特有属性 (JSON 顶层除 id/type/text/style/children 之外的字段) ----
    let mut extra_props = HashMap::new();
    let reserved_keys = ["id", "type", "text", "style", "children"];
    for (key, val) in obj.iter() {
        if reserved_keys.contains(&key.as_str()) {
            continue;
        }
        let str_val = match val {
            serde_json::Value::String(s) => s.clone(),
            serde_json::Value::Bool(b) => b.to_string(),
            serde_json::Value::Number(n) => n.to_string(),
            serde_json::Value::Null => "null".to_string(),
            other => other.to_string(),
        };
        extra_props.insert(key.clone(), str_val);
    }

    // ---- 提取 style 内的渲染属性到 extra_props (Dart 侧需要) ----
    let rendering_style_keys = [
        "textAlign", "overflow", "textOverflow",
        "justifyContent", "alignItems", "alignSelf",
        "whiteSpace", "wordBreak", "lineClamp",
        "fontWeight",
    ];
    for key in &rendering_style_keys {
        if let Some(val) = style_val.get(*key).and_then(|v| v.as_str()) {
            extra_props.insert(key.to_string(), val.to_string());
        }
    }

    // ---- scroll-view: 设置 overflow 让子节点使用自然尺寸 ----
    if node_type == "scroll-view" {
        style.overflow_x = crate::layout::style::QBOverflow::Scroll;
        style.overflow_y = crate::layout::style::QBOverflow::Scroll;
    }

    // ---- 固定尺寸节点不压缩 ----
    // 有显式 height 且没有 flexGrow 的节点，默认 flex_shrink=0
    // 防止 bottomNav 等固定高度组件被 Taffy 压缩
    // 但 text 节点除外 — text 需要能被父容器约束宽度以实现换行
    let has_explicit_height = !matches!(style.height, QBDimension::Auto);
    let has_flex_grow = style.flex_grow > 0.0;
    let user_set_shrink = style_val.get("flexShrink").is_some();
    if has_explicit_height && !has_flex_grow && !user_set_shrink && node_type != "text" {
        style.flex_shrink = 0.0;
    }

    // ---- 文本尺寸估算 (宽度 + 多行高度) ----
    // Taffy 是纯布局引擎，没有文本测量能力。
    // 1) 短文本 (宽度 <= 容器) → 使用估算宽度，单行高度
    // 2) 长文本 (宽度 > 容器) → 宽度设为容器可用宽度，高度按换行行数估算
    if node_type == "text" {
        if let Some(ref txt) = text {
            let fs = font_size.unwrap_or(14.0) as f32;
            let estimated_width = estimate_text_width(txt, fs);
            let max_line_width = (viewport_width as f32) * 0.85;
            let line_height = fs * 1.4;

            if matches!(style.width, QBDimension::Auto) {
                if estimated_width <= max_line_width {
                    // 短文本: 使用估算宽度
                    style.width = QBDimension::Length(estimated_width);
                } else {
                    // 长文本: 使用 100% 宽度 (让 Taffy 按父容器约束)
                    style.width = QBDimension::Percent(100.0);
                }
            }

            if matches!(style.height, QBDimension::Auto) {
                if estimated_width <= max_line_width {
                    // 短文本: 单行高度
                    style.height = QBDimension::Length(line_height);
                } else if max_line_width > 0.0 {
                    // 长文本: 按换行行数估算高度
                    let num_lines = (estimated_width / max_line_width).ceil();
                    style.height = QBDimension::Length(num_lines * line_height);
                } else {
                    style.height = QBDimension::Length(line_height);
                }
            }
        }
    }

    let children_json = obj.get("children").and_then(|v| v.as_array()).cloned().unwrap_or_default();
    let mut child_ids = Vec::new();
    for child_json in &children_json {
        child_ids.push(build_layout_node(child_json, tree, meta_map, viewport_width)?);
    }

    // scroll-view: 子节点 flex_shrink=0，保持自然尺寸不压缩
    // 这样内容总高度 > 容器高度，Dart 侧 SingleChildScrollView 可滚动
    if node_type == "scroll-view" {
        for &child_id in &child_ids {
            tree.set_flex_shrink(child_id, 0.0);
        }
    }

    let node_id = if child_ids.is_empty() {
        tree.add_node(&style)
    } else {
        tree.add_node_with_children(&style, &child_ids)
    };

    meta_map.insert(node_id, NodeMeta {
        id, node_type, text, color, font_size, text_color,
        font_weight, border_radius, opacity, extra_props,
        children: child_ids,
    });
    Ok(node_id)
}

/// 估算文本渲染宽度 (像素)。
///
/// 使用简单的启发式规则:
/// - ASCII 字符宽度 ≈ fontSize × 0.6
/// - CJK / emoji / 全角字符宽度 ≈ fontSize × 1.0
/// - 最终结果向上取整并加一点 padding
fn estimate_text_width(text: &str, font_size: f32) -> f32 {
    let narrow_ratio = 0.6;   // 英文/数字/标点
    let wide_ratio = 1.05;    // 中日韩/emoji
    let mut width: f32 = 0.0;

    for ch in text.chars() {
        if is_wide_char(ch) {
            width += font_size * wide_ratio;
        } else {
            width += font_size * narrow_ratio;
        }
    }

    // 加上额外 padding 确保不被截断
    (width + 2.0).ceil()
}

/// 判断字符是否为"宽字符"（CJK、emoji 等全角字符）。
fn is_wide_char(ch: char) -> bool {
    let cp = ch as u32;
    // CJK Unified Ideographs
    (0x4E00..=0x9FFF).contains(&cp)
    // CJK Ext-A
    || (0x3400..=0x4DBF).contains(&cp)
    // CJK Compatibility Ideographs
    || (0xF900..=0xFAFF).contains(&cp)
    // Fullwidth Forms
    || (0xFF01..=0xFF60).contains(&cp)
    || (0xFFE0..=0xFFE6).contains(&cp)
    // Hangul
    || (0xAC00..=0xD7AF).contains(&cp)
    // Hiragana / Katakana
    || (0x3040..=0x309F).contains(&cp)
    || (0x30A0..=0x30FF).contains(&cp)
    // CJK Symbols
    || (0x3000..=0x303F).contains(&cp)
    // Emoji (rough range)
    || (0x1F300..=0x1F9FF).contains(&cp)
    || (0x2600..=0x27BF).contains(&cp)
}

// ---------------------------------------------------------------------------
// 内部: 解析 style
// ---------------------------------------------------------------------------

/// 解析尺寸值: 支持数字 (200) 和百分比字符串 ("100%")。
fn parse_dimension_value(val: &serde_json::Value) -> Option<QBDimension> {
    if let Some(v) = val.as_f64() {
        return Some(QBDimension::Length(v as f32));
    }
    if let Some(s) = val.as_str() {
        let trimmed = s.trim();
        if trimmed == "auto" {
            return Some(QBDimension::Auto);
        }
        if let Some(pct) = trimmed.strip_suffix('%') {
            if let Ok(v) = pct.trim().parse::<f32>() {
                return Some(QBDimension::Percent(v));
            }
        }
        // 尝试纯数字字符串
        if let Ok(v) = trimmed.parse::<f32>() {
            return Some(QBDimension::Length(v));
        }
    }
    None
}

fn parse_style(style: &serde_json::Value) -> QBStyle {
    let mut s = QBStyle::default();

    if let Some(v) = style.get("flexDirection").and_then(|v| v.as_str()) {
        s.flex_direction = match v {
            "row" => QBFlexDirection::Row,
            "column" => QBFlexDirection::Column,
            "row-reverse" => QBFlexDirection::RowReverse,
            "column-reverse" => QBFlexDirection::ColumnReverse,
            _ => QBFlexDirection::Row,
        };
    }
    if let Some(v) = style.get("flexWrap").and_then(|v| v.as_str()) {
        s.flex_wrap = match v { "wrap" => QBFlexWrap::Wrap, _ => QBFlexWrap::NoWrap };
    }
    if let Some(v) = style.get("justifyContent").and_then(|v| v.as_str()) {
        s.justify_content = match v {
            "flex-start" => QBJustifyContent::FlexStart,
            "flex-end" => QBJustifyContent::FlexEnd,
            "center" => QBJustifyContent::Center,
            "space-between" => QBJustifyContent::SpaceBetween,
            "space-around" => QBJustifyContent::SpaceAround,
            "space-evenly" => QBJustifyContent::SpaceEvenly,
            _ => QBJustifyContent::FlexStart,
        };
    }
    if let Some(v) = style.get("alignItems").and_then(|v| v.as_str()) {
        s.align_items = match v {
            "flex-start" => QBAlignItems::FlexStart,
            "flex-end" => QBAlignItems::FlexEnd,
            "center" => QBAlignItems::Center,
            "stretch" => QBAlignItems::Stretch,
            "baseline" => QBAlignItems::Baseline,
            _ => QBAlignItems::Stretch,
        };
    }

    // 尺寸 — 支持数字和百分比字符串
    if let Some(val) = style.get("width") {
        if let Some(dim) = parse_dimension_value(val) { s.width = dim; }
    }
    if let Some(val) = style.get("height") {
        if let Some(dim) = parse_dimension_value(val) { s.height = dim; }
    }
    if let Some(val) = style.get("minWidth") {
        if let Some(dim) = parse_dimension_value(val) { s.min_width = dim; }
    }
    if let Some(val) = style.get("minHeight") {
        if let Some(dim) = parse_dimension_value(val) { s.min_height = dim; }
    }
    if let Some(val) = style.get("maxWidth") {
        if let Some(dim) = parse_dimension_value(val) { s.max_width = dim; }
    }
    if let Some(val) = style.get("maxHeight") {
        if let Some(dim) = parse_dimension_value(val) { s.max_height = dim; }
    }
    if let Some(v) = style.get("flexGrow").and_then(|v| v.as_f64()) { s.flex_grow = v as f32; }
    if let Some(v) = style.get("flexShrink").and_then(|v| v.as_f64()) { s.flex_shrink = v as f32; }

    if let Some(v) = style.get("padding").and_then(|v| v.as_f64()) {
        let p = v as f32;
        s.padding_top = p; s.padding_right = p; s.padding_bottom = p; s.padding_left = p;
    }
    if let Some(v) = style.get("paddingTop").and_then(|v| v.as_f64()) { s.padding_top = v as f32; }
    if let Some(v) = style.get("paddingRight").and_then(|v| v.as_f64()) { s.padding_right = v as f32; }
    if let Some(v) = style.get("paddingBottom").and_then(|v| v.as_f64()) { s.padding_bottom = v as f32; }
    if let Some(v) = style.get("paddingLeft").and_then(|v| v.as_f64()) { s.padding_left = v as f32; }

    if let Some(v) = style.get("margin").and_then(|v| v.as_f64()) {
        let m = QBLengthPercentageAuto::Length(v as f32);
        s.margin_top = m; s.margin_right = m; s.margin_bottom = m; s.margin_left = m;
    }
    if let Some(v) = style.get("marginTop").and_then(|v| v.as_f64()) { s.margin_top = QBLengthPercentageAuto::Length(v as f32); }
    if let Some(v) = style.get("marginRight").and_then(|v| v.as_f64()) { s.margin_right = QBLengthPercentageAuto::Length(v as f32); }
    if let Some(v) = style.get("marginBottom").and_then(|v| v.as_f64()) { s.margin_bottom = QBLengthPercentageAuto::Length(v as f32); }
    if let Some(v) = style.get("marginLeft").and_then(|v| v.as_f64()) { s.margin_left = QBLengthPercentageAuto::Length(v as f32); }

    if let Some(v) = style.get("gap").and_then(|v| v.as_f64()) { s.gap_row = v as f32; s.gap_column = v as f32; }
    if let Some(v) = style.get("rowGap").and_then(|v| v.as_f64()) { s.gap_row = v as f32; }
    if let Some(v) = style.get("columnGap").and_then(|v| v.as_f64()) { s.gap_column = v as f32; }

    s
}

// ---------------------------------------------------------------------------
// 内部: 收集渲染节点
// ---------------------------------------------------------------------------

/// 递归构建渲染树 (树结构，x/y 为相对父节点的坐标)。
fn collect_render_tree(
    node_id: u64,
    tree: &QBLayoutTree,
    meta_map: &HashMap<u64, NodeMeta>,
) -> RenderNode {
    let layout = tree.get_layout(node_id);

    let meta = meta_map.get(&node_id);

    let children: Vec<RenderNode> = meta
        .map(|m| &m.children)
        .unwrap_or(&Vec::new())
        .iter()
        .map(|&cid| collect_render_tree(cid, tree, meta_map))
        .collect();

    match meta {
        Some(m) => RenderNode {
            id: m.id.clone(),
            node_type: m.node_type.clone(),
            text: m.text.clone(),
            color: m.color.clone(),
            x: layout.x as f64,
            y: layout.y as f64,
            width: layout.width as f64,
            height: layout.height as f64,
            font_size: m.font_size,
            text_color: m.text_color.clone(),
            font_weight: m.font_weight.clone(),
            border_radius: m.border_radius,
            opacity: m.opacity,
            extra_props: m.extra_props.clone(),
            events: vec![],
            children,
        },
        None => RenderNode {
            id: "unknown".to_string(),
            node_type: "view".to_string(),
            text: None,
            color: None,
            x: layout.x as f64,
            y: layout.y as f64,
            width: layout.width as f64,
            height: layout.height as f64,
            font_size: None,
            text_color: None,
            font_weight: None,
            border_radius: None,
            opacity: None,
            extra_props: HashMap::new(),
            events: vec![],
            children,
        },
    }
}

#[cfg(test)]
mod render_debug_tests {
    use super::*;

    fn collect_all_text_nodes(node: &RenderNode) -> Vec<&RenderNode> {
        let mut result = Vec::new();
        if node.node_type == "text" { result.push(node); }
        for child in &node.children { result.extend(collect_all_text_nodes(child)); }
        result
    }

    #[test]
    fn test_render_tree_structure() {
        let tree_data = serde_json::json!({
            "id": "root", "type": "view",
            "style": { "flexDirection": "column", "width": 375, "height": 812 },
            "children": [
                {
                    "id": "header", "type": "view",
                    "style": { "flexDirection": "row", "alignItems": "center", "height": 44 },
                    "children": [
                        { "id": "title", "type": "text", "text": "Hello", "style": { "height": 18, "fontSize": 14 } }
                    ]
                },
                {
                    "id": "scroll", "type": "scroll-view",
                    "style": { "flexDirection": "column", "flexGrow": 1 },
                    "children": [
                        { "id": "item1", "type": "text", "text": "Feed 1", "style": { "height": 60, "fontSize": 16 } },
                        { "id": "item2", "type": "text", "text": "Feed 2", "style": { "height": 60, "fontSize": 16 } }
                    ]
                },
                {
                    "id": "footer", "type": "view",
                    "style": { "height": 56 },
                    "children": [
                        { "id": "tab1", "type": "text", "text": "Home", "style": { "fontSize": 12, "height": 16 } }
                    ]
                }
            ]
        });

        let mut layout_tree = QBLayoutTree::new();
        let mut node_meta: HashMap<u64, NodeMeta> = HashMap::new();
        let root_id = build_layout_node(&tree_data, &mut layout_tree, &mut node_meta, 375.0).unwrap();
        layout_tree.compute_layout(root_id, 375.0, 812.0);
        let root = collect_render_tree(root_id, &layout_tree, &node_meta);

        // Tree structure
        assert_eq!(root.width, 375.0);
        assert_eq!(root.children.len(), 3);
        assert_eq!(root.children[0].id, "header");
        assert_eq!(root.children[1].id, "scroll");
        assert_eq!(root.children[1].node_type, "scroll-view");
        assert_eq!(root.children[2].id, "footer");

        // Relative coords
        assert_eq!(root.x, 0.0);
        assert_eq!(root.y, 0.0);
        assert!(root.children[1].y > 0.0, "scroll y should be > 0");

        // Debug print tree for inspection
        fn print_tree(node: &RenderNode, depth: usize) {
            let indent = "  ".repeat(depth);
            eprintln!(
                "{}[{}] type={:10} x={:6.1} y={:6.1} w={:6.1} h={:6.1} children={}",
                indent, node.id, node.node_type, node.x, node.y, node.width, node.height, node.children.len()
            );
            for child in &node.children {
                print_tree(child, depth + 1);
            }
        }
        eprintln!("\n=== RENDER TREE ===");
        print_tree(&root, 0);
        eprintln!("=== END ===\n");

        // scroll-view has children
        assert_eq!(root.children[1].children.len(), 2);

        // Footer should have height > 0
        eprintln!("Footer: y={} h={}", root.children[2].y, root.children[2].height);
        assert!(root.children[2].height > 0.0, "footer height should be > 0!");

        // All text nodes have width > 0
        for t in collect_all_text_nodes(&root) {
            assert!(t.width > 0.0, "text '{}' width=0!", t.id);
        }
    }

    #[test]
    fn test_scrollview_overflow_with_many_items() {
        let mut children = Vec::new();
        for i in 0..10 {
            children.push(serde_json::json!({
                "id": format!("item{}", i), "type": "view",
                "style": { "height": 100 }, "children": []
            }));
            children.push(serde_json::json!({
                "id": format!("gap{}", i), "type": "view",
                "style": { "height": 8 }, "children": []
            }));
        }

        let tree_data = serde_json::json!({
            "id": "root", "type": "view",
            "style": { "flexDirection": "column", "width": 375, "height": 700 },
            "children": [
                { "id": "header", "type": "view", "style": { "height": 44 }, "children": [] },
                { "id": "scroll", "type": "scroll-view",
                  "style": { "flexDirection": "column", "flexGrow": 1 },
                  "children": children },
                { "id": "footer", "type": "view", "style": { "height": 56 }, "children": [] }
            ]
        });

        let mut layout_tree = QBLayoutTree::new();
        let mut node_meta: HashMap<u64, NodeMeta> = HashMap::new();
        let root_id = build_layout_node(&tree_data, &mut layout_tree, &mut node_meta, 375.0).unwrap();
        layout_tree.compute_layout(root_id, 375.0, 700.0);
        let root = collect_render_tree(root_id, &layout_tree, &node_meta);

        let scroll = &root.children[1];
        let footer = &root.children[2];

        eprintln!("\n=== OVERFLOW TEST ===");
        eprintln!("scroll: y={} h={} children={}", scroll.y, scroll.height, scroll.children.len());
        let last = scroll.children.last().unwrap();
        let content_height = last.y + last.height;
        eprintln!("last child: y={} h={}", last.y, last.height);
        eprintln!("content_height = {} (scroll h={})", content_height, scroll.height);
        eprintln!("footer: y={} h={}", footer.y, footer.height);
        eprintln!("=== END ===\n");

        assert_eq!(footer.height, 56.0, "footer h");
        assert!(content_height > scroll.height,
            "content {} should exceed container {}", content_height, scroll.height);
    }
}

