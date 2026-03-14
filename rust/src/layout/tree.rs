//! 布局树管理 — 节点操作与布局计算。
//!
//! [`QBLayoutTree`] 封装了 Taffy 的 `TaffyTree`，提供：
//! - 节点的增删改查
//! - 父子关系管理
//! - 布局计算与结果读取

use taffy::prelude::*;

use super::style::QBStyle;

/// 布局计算结果 — 单个节点的位置和尺寸。
///
/// 坐标系以父节点的 content 区域左上角为原点。
#[derive(Debug, Clone, Copy, Default)]
pub struct QBLayoutResult {
    /// 相对于父节点的 X 偏移（像素）。
    pub x: f32,
    /// 相对于父节点的 Y 偏移（像素）。
    pub y: f32,
    /// 节点宽度（像素）。
    pub width: f32,
    /// 节点高度（像素）。
    pub height: f32,
}

/// 七巧板布局树 — 管理 Flexbox 布局计算。
///
/// 内部持有一棵 `TaffyTree`，通过节点 ID (`u64`) 暴露给外部。
///
/// # 工作流程
///
/// 1. 创建布局树
/// 2. 添加节点并设置样式
/// 3. 建立父子关系
/// 4. 调用 `compute_layout()` 计算布局
/// 5. 读取每个节点的 `QBLayoutResult`
pub struct QBLayoutTree {
    inner: TaffyTree<()>,
}

impl QBLayoutTree {
    /// 创建一个空的布局树。
    pub fn new() -> Self {
        Self {
            inner: TaffyTree::new(),
        }
    }

    /// 添加一个叶子节点。
    ///
    /// 返回节点 ID（内部转换为 `u64`，方便跨 FFI 传递）。
    pub fn add_node(&mut self, style: &QBStyle) -> u64 {
        let node = self
            .inner
            .new_leaf(style.to_taffy_style())
            .expect("Failed to create leaf node");
        node_to_u64(node)
    }

    /// 添加一个容器节点（含子节点）。
    ///
    /// # 参数
    /// - `style`: 容器样式
    /// - `children_ids`: 子节点 ID 列表（有序）
    pub fn add_node_with_children(
        &mut self,
        style: &QBStyle,
        children_ids: &[u64],
    ) -> u64 {
        let children: Vec<NodeId> = children_ids.iter().map(|id| u64_to_node(*id)).collect();
        let node = self
            .inner
            .new_with_children(style.to_taffy_style(), &children)
            .expect("Failed to create container node");
        node_to_u64(node)
    }

    /// 更新指定节点的样式。
    pub fn set_style(&mut self, node_id: u64, style: &QBStyle) {
        self.inner
            .set_style(u64_to_node(node_id), style.to_taffy_style())
            .expect("Failed to set style");
    }

    /// 为指定节点设置子节点列表。
    pub fn set_children(&mut self, node_id: u64, children_ids: &[u64]) {
        let children: Vec<NodeId> = children_ids.iter().map(|id| u64_to_node(*id)).collect();
        self.inner
            .set_children(u64_to_node(node_id), &children)
            .expect("Failed to set children");
    }

    /// 向指定父节点追加一个子节点。
    pub fn add_child(&mut self, parent_id: u64, child_id: u64) {
        self.inner
            .add_child(u64_to_node(parent_id), u64_to_node(child_id))
            .expect("Failed to add child");
    }

    /// 更新指定节点的 flex_shrink 值 (不改变其他样式)。
    ///
    /// 主要用于 scroll-view: 设置子节点 flex_shrink=0 使其保持自然尺寸。
    pub fn set_flex_shrink(&mut self, node_id: u64, value: f32) {
        let nid = u64_to_node(node_id);
        let mut style = self.inner.style(nid).unwrap().clone();
        style.flex_shrink = value;
        self.inner.set_style(nid, style).expect("Failed to set flex_shrink");
    }

    /// 移除指定节点（及其子树）。
    pub fn remove_node(&mut self, node_id: u64) {
        self.inner
            .remove(u64_to_node(node_id))
            .expect("Failed to remove node");
    }

    /// 对根节点执行布局计算。
    ///
    /// # 参数
    /// - `root_id`: 根节点 ID
    /// - `available_width`: 可用宽度（像素），通常为屏幕宽度
    /// - `available_height`: 可用高度（像素），通常为屏幕高度
    pub fn compute_layout(&mut self, root_id: u64, available_width: f32, available_height: f32) {
        self.inner
            .compute_layout(
                u64_to_node(root_id),
                Size {
                    width: AvailableSpace::Definite(available_width),
                    height: AvailableSpace::Definite(available_height),
                },
            )
            .expect("Failed to compute layout");
    }

    /// 获取指定节点的布局结果。
    ///
    /// 必须在 `compute_layout()` 之后调用。
    pub fn get_layout(&self, node_id: u64) -> QBLayoutResult {
        let layout = self.inner.layout(u64_to_node(node_id)).expect("Failed to get layout");
        QBLayoutResult {
            x: layout.location.x,
            y: layout.location.y,
            width: layout.size.width,
            height: layout.size.height,
        }
    }

    /// 获取节点数量。
    pub fn node_count(&self) -> usize {
        self.inner.total_node_count()
    }
}

// ---------------------------------------------------------------------------
// NodeId ↔ u64 转换
// ---------------------------------------------------------------------------

/// 将 Taffy `NodeId` 转为 `u64`，方便跨 FFI 传递。
fn node_to_u64(node: NodeId) -> u64 {
    // NodeId 内部是 slotmap 的 DefaultKey，包含 index + version
    // 我们使用 transmute 安全转换（两者都是 64-bit）
    let bits: u64 = unsafe { std::mem::transmute(node) };
    bits
}

/// 将 `u64` 转回 Taffy `NodeId`。
fn u64_to_node(id: u64) -> NodeId {
    unsafe { std::mem::transmute(id) }
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn basic_flex_row_layout() {
        let mut tree = QBLayoutTree::new();

        // 创建两个 100x50 的子节点
        let child1 = tree.add_node(&QBStyle {
            width: super::super::style::QBDimension::Length(100.0),
            height: super::super::style::QBDimension::Length(50.0),
            ..Default::default()
        });

        let child2 = tree.add_node(&QBStyle {
            width: super::super::style::QBDimension::Length(100.0),
            height: super::super::style::QBDimension::Length(50.0),
            ..Default::default()
        });

        // 创建 flex-direction: row 的容器
        let root = tree.add_node_with_children(
            &QBStyle {
                width: super::super::style::QBDimension::Length(400.0),
                height: super::super::style::QBDimension::Length(200.0),
                flex_direction: super::super::style::QBFlexDirection::Row,
                ..Default::default()
            },
            &[child1, child2],
        );

        // 计算布局
        tree.compute_layout(root, 400.0, 200.0);

        // 验证根节点
        let root_layout = tree.get_layout(root);
        assert_eq!(root_layout.width, 400.0);
        assert_eq!(root_layout.height, 200.0);

        // 验证 child1 在左侧
        let c1_layout = tree.get_layout(child1);
        assert_eq!(c1_layout.x, 0.0);
        assert_eq!(c1_layout.width, 100.0);

        // 验证 child2 紧挨 child1 右侧
        let c2_layout = tree.get_layout(child2);
        assert_eq!(c2_layout.x, 100.0);
        assert_eq!(c2_layout.width, 100.0);
    }

    #[test]
    fn flex_column_layout() {
        let mut tree = QBLayoutTree::new();

        let child = tree.add_node(&QBStyle {
            width: super::super::style::QBDimension::Length(100.0),
            height: super::super::style::QBDimension::Length(50.0),
            ..Default::default()
        });

        let root = tree.add_node_with_children(
            &QBStyle {
                width: super::super::style::QBDimension::Length(400.0),
                height: super::super::style::QBDimension::Length(200.0),
                flex_direction: super::super::style::QBFlexDirection::Column,
                ..Default::default()
            },
            &[child],
        );

        tree.compute_layout(root, 400.0, 200.0);

        let c_layout = tree.get_layout(child);
        assert_eq!(c_layout.x, 0.0);
        assert_eq!(c_layout.y, 0.0);
        // Column 方向: 子节点设置了显式宽度 100，Taffy 优先使用显式宽度
        assert_eq!(c_layout.width, 100.0);
    }

    #[test]
    fn flex_grow_distributes_space() {
        let mut tree = QBLayoutTree::new();

        let child1 = tree.add_node(&QBStyle {
            flex_grow: 1.0,
            height: super::super::style::QBDimension::Length(50.0),
            ..Default::default()
        });

        let child2 = tree.add_node(&QBStyle {
            flex_grow: 2.0,
            height: super::super::style::QBDimension::Length(50.0),
            ..Default::default()
        });

        let root = tree.add_node_with_children(
            &QBStyle {
                width: super::super::style::QBDimension::Length(300.0),
                height: super::super::style::QBDimension::Length(100.0),
                flex_direction: super::super::style::QBFlexDirection::Row,
                ..Default::default()
            },
            &[child1, child2],
        );

        tree.compute_layout(root, 300.0, 100.0);

        let c1 = tree.get_layout(child1);
        let c2 = tree.get_layout(child2);

        // flex-grow 1:2 比例分配 300px → 100:200
        assert_eq!(c1.width, 100.0);
        assert_eq!(c2.width, 200.0);
    }
}
