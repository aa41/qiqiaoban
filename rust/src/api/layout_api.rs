//! Dart 侧布局 API。
//!
//! 通过全局 LayoutStore 管理布局树实例，使用 u32 ID 跨 FFI 引用。

use std::collections::HashMap;
use std::sync::Mutex;
use std::sync::OnceLock;

use crate::layout::style::*;
use crate::layout::tree::{QBLayoutResult, QBLayoutTree};

/// 全局布局树仓库。
struct LayoutStore {
    trees: HashMap<u32, QBLayoutTree>,
    next_id: u32,
}

fn store() -> &'static Mutex<LayoutStore> {
    static STORE: OnceLock<Mutex<LayoutStore>> = OnceLock::new();
    STORE.get_or_init(|| {
        Mutex::new(LayoutStore {
            trees: HashMap::new(),
            next_id: 1,
        })
    })
}

// ---------------------------------------------------------------------------
// 暴露给 Dart 的 API
// ---------------------------------------------------------------------------

/// 创建一个新的布局树实例。
///
/// 返回布局树 ID。
#[flutter_rust_bridge::frb(sync)]
pub fn create_layout_tree() -> u32 {
    let mut guard = store().lock().expect("Lock error");
    let id = guard.next_id;
    guard.next_id += 1;
    guard.trees.insert(id, QBLayoutTree::new());
    id
}

/// 在布局树中添加一个叶子节点。
///
/// 返回节点 ID (u64)。
#[flutter_rust_bridge::frb(sync)]
pub fn layout_add_node(
    tree_id: u32,
    // --- 尺寸 ---
    width: Option<f64>,
    height: Option<f64>,
    min_width: Option<f64>,
    min_height: Option<f64>,
    max_width: Option<f64>,
    max_height: Option<f64>,
    // --- Flex 子项 ---
    flex_grow: Option<f64>,
    flex_shrink: Option<f64>,
    // --- 间距 ---
    padding_top: Option<f64>,
    padding_right: Option<f64>,
    padding_bottom: Option<f64>,
    padding_left: Option<f64>,
    margin_top: Option<f64>,
    margin_right: Option<f64>,
    margin_bottom: Option<f64>,
    margin_left: Option<f64>,
) -> u64 {
    let style = build_style(
        None, None, None, None, None, None, None,
        width, height, min_width, min_height, max_width, max_height,
        flex_grow, flex_shrink,
        padding_top, padding_right, padding_bottom, padding_left,
        margin_top, margin_right, margin_bottom, margin_left,
    );

    let mut guard = store().lock().expect("Lock error");
    let tree = guard.trees.get_mut(&tree_id).expect("Layout tree not found");
    tree.add_node(&style)
}

/// 在布局树中添加一个容器节点。
#[flutter_rust_bridge::frb(sync)]
pub fn layout_add_container(
    tree_id: u32,
    children_ids: Vec<u64>,
    // --- 容器属性 ---
    flex_direction: Option<String>,
    flex_wrap: Option<String>,
    justify_content: Option<String>,
    align_items: Option<String>,
    gap_row: Option<f64>,
    gap_column: Option<f64>,
    // --- 尺寸 ---
    width: Option<f64>,
    height: Option<f64>,
    min_width: Option<f64>,
    min_height: Option<f64>,
    max_width: Option<f64>,
    max_height: Option<f64>,
    // --- Flex 子项 ---
    flex_grow: Option<f64>,
    flex_shrink: Option<f64>,
    // --- 间距 ---
    padding_top: Option<f64>,
    padding_right: Option<f64>,
    padding_bottom: Option<f64>,
    padding_left: Option<f64>,
    margin_top: Option<f64>,
    margin_right: Option<f64>,
    margin_bottom: Option<f64>,
    margin_left: Option<f64>,
) -> u64 {
    let style = build_style(
        flex_direction, flex_wrap, justify_content, align_items,
        None, gap_row, gap_column,
        width, height, min_width, min_height, max_width, max_height,
        flex_grow, flex_shrink,
        padding_top, padding_right, padding_bottom, padding_left,
        margin_top, margin_right, margin_bottom, margin_left,
    );

    let mut guard = store().lock().expect("Lock error");
    let tree = guard.trees.get_mut(&tree_id).expect("Layout tree not found");
    tree.add_node_with_children(&style, &children_ids)
}

/// 计算布局。
#[flutter_rust_bridge::frb(sync)]
pub fn layout_compute(tree_id: u32, root_id: u64, width: f64, height: f64) {
    let mut guard = store().lock().expect("Lock error");
    let tree = guard.trees.get_mut(&tree_id).expect("Layout tree not found");
    tree.compute_layout(root_id, width as f32, height as f32);
}

/// 获取节点布局结果，返回 [x, y, width, height]。
#[flutter_rust_bridge::frb(sync)]
pub fn layout_get_result(tree_id: u32, node_id: u64) -> Vec<f64> {
    let guard = store().lock().expect("Lock error");
    let tree = guard.trees.get(&tree_id).expect("Layout tree not found");
    let result: QBLayoutResult = tree.get_layout(node_id);
    vec![
        result.x as f64,
        result.y as f64,
        result.width as f64,
        result.height as f64,
    ]
}

/// 销毁布局树。
#[flutter_rust_bridge::frb(sync)]
pub fn destroy_layout_tree(tree_id: u32) {
    let mut guard = store().lock().expect("Lock error");
    guard.trees.remove(&tree_id);
}

// ---------------------------------------------------------------------------
// 样式构建辅助函数
// ---------------------------------------------------------------------------

#[allow(clippy::too_many_arguments)]
fn build_style(
    flex_direction: Option<String>,
    flex_wrap: Option<String>,
    justify_content: Option<String>,
    align_items: Option<String>,
    align_content: Option<String>,
    gap_row: Option<f64>,
    gap_column: Option<f64>,
    width: Option<f64>,
    height: Option<f64>,
    min_width: Option<f64>,
    min_height: Option<f64>,
    max_width: Option<f64>,
    max_height: Option<f64>,
    flex_grow: Option<f64>,
    flex_shrink: Option<f64>,
    padding_top: Option<f64>,
    padding_right: Option<f64>,
    padding_bottom: Option<f64>,
    padding_left: Option<f64>,
    margin_top: Option<f64>,
    margin_right: Option<f64>,
    margin_bottom: Option<f64>,
    margin_left: Option<f64>,
) -> QBStyle {
    let mut style = QBStyle::default();

    if let Some(dir) = flex_direction {
        style.flex_direction = match dir.as_str() {
            "row" => QBFlexDirection::Row,
            "column" => QBFlexDirection::Column,
            "row-reverse" => QBFlexDirection::RowReverse,
            "column-reverse" => QBFlexDirection::ColumnReverse,
            _ => QBFlexDirection::Row,
        };
    }

    if let Some(wrap) = flex_wrap {
        style.flex_wrap = match wrap.as_str() {
            "nowrap" => QBFlexWrap::NoWrap,
            "wrap" => QBFlexWrap::Wrap,
            "wrap-reverse" => QBFlexWrap::WrapReverse,
            _ => QBFlexWrap::NoWrap,
        };
    }

    if let Some(jc) = justify_content {
        style.justify_content = match jc.as_str() {
            "flex-start" => QBJustifyContent::FlexStart,
            "flex-end" => QBJustifyContent::FlexEnd,
            "center" => QBJustifyContent::Center,
            "space-between" => QBJustifyContent::SpaceBetween,
            "space-around" => QBJustifyContent::SpaceAround,
            "space-evenly" => QBJustifyContent::SpaceEvenly,
            _ => QBJustifyContent::FlexStart,
        };
    }

    if let Some(ai) = align_items {
        style.align_items = match ai.as_str() {
            "flex-start" => QBAlignItems::FlexStart,
            "flex-end" => QBAlignItems::FlexEnd,
            "center" => QBAlignItems::Center,
            "stretch" => QBAlignItems::Stretch,
            "baseline" => QBAlignItems::Baseline,
            _ => QBAlignItems::Stretch,
        };
    }

    if let Some(ac) = align_content {
        style.align_content = match ac.as_str() {
            "flex-start" => QBAlignContent::FlexStart,
            "flex-end" => QBAlignContent::FlexEnd,
            "center" => QBAlignContent::Center,
            "stretch" => QBAlignContent::Stretch,
            "space-between" => QBAlignContent::SpaceBetween,
            "space-around" => QBAlignContent::SpaceAround,
            _ => QBAlignContent::Stretch,
        };
    }

    if let Some(v) = gap_row { style.gap_row = v as f32; }
    if let Some(v) = gap_column { style.gap_column = v as f32; }

    if let Some(v) = width { style.width = QBDimension::Length(v as f32); }
    if let Some(v) = height { style.height = QBDimension::Length(v as f32); }
    if let Some(v) = min_width { style.min_width = QBDimension::Length(v as f32); }
    if let Some(v) = min_height { style.min_height = QBDimension::Length(v as f32); }
    if let Some(v) = max_width { style.max_width = QBDimension::Length(v as f32); }
    if let Some(v) = max_height { style.max_height = QBDimension::Length(v as f32); }

    if let Some(v) = flex_grow { style.flex_grow = v as f32; }
    if let Some(v) = flex_shrink { style.flex_shrink = v as f32; }

    if let Some(v) = padding_top { style.padding_top = v as f32; }
    if let Some(v) = padding_right { style.padding_right = v as f32; }
    if let Some(v) = padding_bottom { style.padding_bottom = v as f32; }
    if let Some(v) = padding_left { style.padding_left = v as f32; }

    if let Some(v) = margin_top { style.margin_top = QBLengthPercentageAuto::Length(v as f32); }
    if let Some(v) = margin_right { style.margin_right = QBLengthPercentageAuto::Length(v as f32); }
    if let Some(v) = margin_bottom { style.margin_bottom = QBLengthPercentageAuto::Length(v as f32); }
    if let Some(v) = margin_left { style.margin_left = QBLengthPercentageAuto::Length(v as f32); }

    style
}
