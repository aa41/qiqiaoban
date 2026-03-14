//! VNode → Taffy 布局桥接。
//!
//! 将 VNode 树自动转换为 Taffy 布局树，执行布局计算，
//! 返回每个节点的绝对坐标和尺寸。

use std::collections::HashMap;

use crate::layout::style::*;
use crate::layout::tree::{QBLayoutResult, QBLayoutTree};

use super::node::{VNode, VNodeStyle};

/// 节点 ID → 布局结果的映射。
pub type LayoutMap = HashMap<u32, QBLayoutResult>;

/// 从 VNode 树计算布局。
///
/// # 参数
/// - `root`: VNode 树的根节点
/// - `available_width`: 可用宽度（像素，通常为屏幕宽度）
/// - `available_height`: 可用高度（像素，通常为屏幕高度）
///
/// # 返回
/// 每个节点 ID 对应的布局结果（绝对坐标）。
pub fn compute_vnode_layout(
    root: &VNode,
    available_width: f32,
    available_height: f32,
) -> LayoutMap {
    let mut tree = QBLayoutTree::new();
    let mut id_map: HashMap<u32, u64> = HashMap::new(); // VNode ID → Taffy NodeId
    let mut children_map: HashMap<u32, Vec<u32>> = HashMap::new(); // VNode ID → child VNode IDs

    // 1. 递归构建 Taffy 布局树
    let root_taffy_id = build_taffy_node(root, &mut tree, &mut id_map, &mut children_map);

    // 2. 执行布局计算
    tree.compute_layout(root_taffy_id, available_width, available_height);

    // 3. 收集布局结果（转为绝对坐标）
    let mut layout_map = LayoutMap::new();
    collect_absolute_layouts(
        root.id,
        0.0,
        0.0,
        &tree,
        &id_map,
        &children_map,
        &mut layout_map,
    );

    layout_map
}

// ---------------------------------------------------------------------------
// 内部: 递归构建 Taffy 节点
// ---------------------------------------------------------------------------

fn build_taffy_node(
    vnode: &VNode,
    tree: &mut QBLayoutTree,
    id_map: &mut HashMap<u32, u64>,
    children_map: &mut HashMap<u32, Vec<u32>>,
) -> u64 {
    // 递归处理子节点
    let child_vnode_ids: Vec<u32> = vnode.children.iter().map(|c| c.id).collect();
    let mut child_taffy_ids = Vec::new();

    for child in &vnode.children {
        let child_taffy_id = build_taffy_node(child, tree, id_map, children_map);
        child_taffy_ids.push(child_taffy_id);
    }

    // 转换样式
    let style = vnode_style_to_qb_style(&vnode.style);

    // 创建 Taffy 节点
    let taffy_id = if child_taffy_ids.is_empty() {
        tree.add_node(&style)
    } else {
        tree.add_node_with_children(&style, &child_taffy_ids)
    };

    id_map.insert(vnode.id, taffy_id);
    children_map.insert(vnode.id, child_vnode_ids);

    taffy_id
}

// ---------------------------------------------------------------------------
// 内部: VNodeStyle → QBStyle 转换
// ---------------------------------------------------------------------------

fn vnode_style_to_qb_style(style: &VNodeStyle) -> QBStyle {
    let mut s = QBStyle::default();

    // Flex 容器属性
    if let Some(ref dir) = style.flex_direction {
        s.flex_direction = match dir.as_str() {
            "row" => QBFlexDirection::Row,
            "column" => QBFlexDirection::Column,
            "row-reverse" => QBFlexDirection::RowReverse,
            "column-reverse" => QBFlexDirection::ColumnReverse,
            _ => QBFlexDirection::Row,
        };
    }

    if let Some(ref wrap) = style.flex_wrap {
        s.flex_wrap = match wrap.as_str() {
            "nowrap" => QBFlexWrap::NoWrap,
            "wrap" => QBFlexWrap::Wrap,
            "wrap-reverse" => QBFlexWrap::WrapReverse,
            _ => QBFlexWrap::NoWrap,
        };
    }

    if let Some(ref jc) = style.justify_content {
        s.justify_content = match jc.as_str() {
            "flex-start" => QBJustifyContent::FlexStart,
            "flex-end" => QBJustifyContent::FlexEnd,
            "center" => QBJustifyContent::Center,
            "space-between" => QBJustifyContent::SpaceBetween,
            "space-around" => QBJustifyContent::SpaceAround,
            "space-evenly" => QBJustifyContent::SpaceEvenly,
            _ => QBJustifyContent::FlexStart,
        };
    }

    if let Some(ref ai) = style.align_items {
        s.align_items = match ai.as_str() {
            "flex-start" => QBAlignItems::FlexStart,
            "flex-end" => QBAlignItems::FlexEnd,
            "center" => QBAlignItems::Center,
            "stretch" => QBAlignItems::Stretch,
            "baseline" => QBAlignItems::Baseline,
            _ => QBAlignItems::Stretch,
        };
    }

    if let Some(ref ac) = style.align_content {
        s.align_content = match ac.as_str() {
            "flex-start" => QBAlignContent::FlexStart,
            "flex-end" => QBAlignContent::FlexEnd,
            "center" => QBAlignContent::Center,
            "stretch" => QBAlignContent::Stretch,
            "space-between" => QBAlignContent::SpaceBetween,
            "space-around" => QBAlignContent::SpaceAround,
            _ => QBAlignContent::Stretch,
        };
    }

    // Flex 子项属性
    if let Some(v) = style.flex_grow {
        s.flex_grow = v;
    }
    if let Some(v) = style.flex_shrink {
        s.flex_shrink = v;
    }
    if let Some(v) = style.flex_basis {
        s.flex_basis = QBDimension::Length(v);
    }

    if let Some(ref a_self) = style.align_self {
        s.align_self = match a_self.as_str() {
            "auto" => QBAlignSelf::Auto,
            "flex-start" => QBAlignSelf::FlexStart,
            "flex-end" => QBAlignSelf::FlexEnd,
            "center" => QBAlignSelf::Center,
            "stretch" => QBAlignSelf::Stretch,
            "baseline" => QBAlignSelf::Baseline,
            _ => QBAlignSelf::Auto,
        };
    }

    // 尺寸
    if let Some(v) = style.width {
        s.width = QBDimension::Length(v);
    }
    if let Some(v) = style.height {
        s.height = QBDimension::Length(v);
    }
    if let Some(v) = style.min_width {
        s.min_width = QBDimension::Length(v);
    }
    if let Some(v) = style.min_height {
        s.min_height = QBDimension::Length(v);
    }
    if let Some(v) = style.max_width {
        s.max_width = QBDimension::Length(v);
    }
    if let Some(v) = style.max_height {
        s.max_height = QBDimension::Length(v);
    }

    // Padding — 统一值 vs 单独值
    let p_uniform = style.padding.unwrap_or(0.0);
    s.padding_top = style.padding_top.unwrap_or(p_uniform);
    s.padding_right = style.padding_right.unwrap_or(p_uniform);
    s.padding_bottom = style.padding_bottom.unwrap_or(p_uniform);
    s.padding_left = style.padding_left.unwrap_or(p_uniform);

    // Margin — 统一值 vs 单独值
    let m_uniform = style.margin.unwrap_or(0.0);
    s.margin_top =
        QBLengthPercentageAuto::Length(style.margin_top.unwrap_or(m_uniform));
    s.margin_right =
        QBLengthPercentageAuto::Length(style.margin_right.unwrap_or(m_uniform));
    s.margin_bottom =
        QBLengthPercentageAuto::Length(style.margin_bottom.unwrap_or(m_uniform));
    s.margin_left =
        QBLengthPercentageAuto::Length(style.margin_left.unwrap_or(m_uniform));

    // Gap — 统一值 vs 单独值
    let g_uniform = style.gap.unwrap_or(0.0);
    s.gap_row = style.row_gap.unwrap_or(g_uniform);
    s.gap_column = style.column_gap.unwrap_or(g_uniform);

    // 定位
    if let Some(ref pos) = style.position {
        s.position = match pos.as_str() {
            "absolute" => QBPosition::Absolute,
            _ => QBPosition::Relative,
        };
    }

    if let Some(v) = style.top {
        s.inset_top = QBLengthPercentageAuto::Length(v);
    }
    if let Some(v) = style.right {
        s.inset_right = QBLengthPercentageAuto::Length(v);
    }
    if let Some(v) = style.bottom {
        s.inset_bottom = QBLengthPercentageAuto::Length(v);
    }
    if let Some(v) = style.left {
        s.inset_left = QBLengthPercentageAuto::Length(v);
    }

    s
}

// ---------------------------------------------------------------------------
// 内部: 收集绝对坐标布局结果
// ---------------------------------------------------------------------------

fn collect_absolute_layouts(
    vnode_id: u32,
    parent_abs_x: f32,
    parent_abs_y: f32,
    tree: &QBLayoutTree,
    id_map: &HashMap<u32, u64>,
    children_map: &HashMap<u32, Vec<u32>>,
    layout_map: &mut LayoutMap,
) {
    let Some(&taffy_id) = id_map.get(&vnode_id) else {
        return;
    };

    let layout = tree.get_layout(taffy_id);
    let abs_x = parent_abs_x + layout.x;
    let abs_y = parent_abs_y + layout.y;

    layout_map.insert(
        vnode_id,
        QBLayoutResult {
            x: abs_x,
            y: abs_y,
            width: layout.width,
            height: layout.height,
        },
    );

    // 递归子节点
    if let Some(child_ids) = children_map.get(&vnode_id) {
        for &child_id in child_ids {
            collect_absolute_layouts(child_id, abs_x, abs_y, tree, id_map, children_map, layout_map);
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::vnode::node::{VNodeType, PropValue};

    fn make_view(id: u32, style: VNodeStyle, children: Vec<VNode>) -> VNode {
        VNode {
            id,
            node_type: VNodeType::View,
            props: HashMap::new(),
            style,
            events: HashMap::new(),
            children,
        }
    }

    fn make_text(id: u32, content: &str, style: VNodeStyle) -> VNode {
        VNode {
            id,
            node_type: VNodeType::Text,
            props: {
                let mut m = HashMap::new();
                m.insert("content".into(), PropValue::Str(content.into()));
                m
            },
            style,
            events: HashMap::new(),
            children: vec![],
        }
    }

    #[test]
    fn simple_column_layout() {
        let root = make_view(
            1,
            VNodeStyle {
                flex_direction: Some("column".into()),
                width: Some(300.0),
                height: Some(400.0),
                ..Default::default()
            },
            vec![
                make_view(
                    2,
                    VNodeStyle {
                        height: Some(60.0),
                        ..Default::default()
                    },
                    vec![],
                ),
                make_view(
                    3,
                    VNodeStyle {
                        flex_grow: Some(1.0),
                        ..Default::default()
                    },
                    vec![],
                ),
            ],
        );

        let layout = compute_vnode_layout(&root, 300.0, 400.0);

        // Root
        let root_l = layout.get(&1).expect("Root layout missing");
        assert_eq!(root_l.width, 300.0);
        assert_eq!(root_l.height, 400.0);

        // Header (60px tall)
        let header_l = layout.get(&2).expect("Header layout missing");
        assert_eq!(header_l.y, 0.0);
        assert_eq!(header_l.height, 60.0);

        // Body (fills remaining: 400 - 60 = 340px)
        let body_l = layout.get(&3).expect("Body layout missing");
        assert_eq!(body_l.y, 60.0);
        assert_eq!(body_l.height, 340.0);
    }

    #[test]
    fn row_with_flex_grow() {
        let root = make_view(
            1,
            VNodeStyle {
                flex_direction: Some("row".into()),
                width: Some(300.0),
                height: Some(100.0),
                ..Default::default()
            },
            vec![
                make_view(
                    2,
                    VNodeStyle {
                        flex_grow: Some(1.0),
                        ..Default::default()
                    },
                    vec![],
                ),
                make_view(
                    3,
                    VNodeStyle {
                        flex_grow: Some(2.0),
                        ..Default::default()
                    },
                    vec![],
                ),
            ],
        );

        let layout = compute_vnode_layout(&root, 300.0, 100.0);

        let c1 = layout.get(&2).unwrap();
        let c2 = layout.get(&3).unwrap();

        assert_eq!(c1.width, 100.0); // 1/(1+2) * 300 = 100
        assert_eq!(c2.width, 200.0); // 2/(1+2) * 300 = 200
    }

    #[test]
    fn padding_affects_children_position() {
        let root = make_view(
            1,
            VNodeStyle {
                flex_direction: Some("column".into()),
                width: Some(200.0),
                height: Some(200.0),
                padding: Some(20.0),
                ..Default::default()
            },
            vec![make_view(
                2,
                VNodeStyle {
                    height: Some(50.0),
                    ..Default::default()
                },
                vec![],
            )],
        );

        let layout = compute_vnode_layout(&root, 200.0, 200.0);

        let child = layout.get(&2).unwrap();
        // Child should be offset by padding (absolute coords)
        assert_eq!(child.x, 20.0);
        assert_eq!(child.y, 20.0);
        // Width = parent width - left padding - right padding = 200 - 20 - 20 = 160
        assert_eq!(child.width, 160.0);
    }

    #[test]
    fn nested_absolute_coordinates() {
        let root = make_view(
            1,
            VNodeStyle {
                flex_direction: Some("column".into()),
                width: Some(300.0),
                height: Some(300.0),
                padding: Some(10.0),
                ..Default::default()
            },
            vec![make_view(
                2,
                VNodeStyle {
                    height: Some(100.0),
                    padding: Some(5.0),
                    ..Default::default()
                },
                vec![make_text(
                    3,
                    "Hello",
                    VNodeStyle {
                        height: Some(20.0),
                        ..Default::default()
                    },
                )],
            )],
        );

        let layout = compute_vnode_layout(&root, 300.0, 300.0);

        let child = layout.get(&2).unwrap();
        assert_eq!(child.x, 10.0); // parent padding
        assert_eq!(child.y, 10.0); // parent padding

        let grandchild = layout.get(&3).unwrap();
        // grandchild absolute = parent(10,10) + child padding (5,5)
        assert_eq!(grandchild.x, 15.0);
        assert_eq!(grandchild.y, 15.0);
    }
}
