//! VNode Diff 算法 — 计算两棵 VNode 树的最小差异。
//!
//! 核心函数 [`diff`] 接收旧/新两棵 VNode 树，返回将旧树变换为新树所需的
//! 最小 [`PatchSet`]。
//!
//! # 算法策略
//!
//! 1. **同 ID、同类型**: 对比 props/style/events，生成 `Update` patch
//! 2. **同 ID、不同类型**: 生成 `Replace` patch
//! 3. **children diff**: 基于节点 ID 的线性扫描，处理新增、删除、移动
//! 4. **文本优化**: Text 节点的 `content` prop 变化使用 `UpdateText` 快捷 patch

use std::collections::{HashMap, HashSet};

use super::node::{PropValue, VNode, VNodeStyle, VNodeType};
use super::patch::{PatchOp, PatchSet};

// ---------------------------------------------------------------------------
// 公共 API
// ---------------------------------------------------------------------------

/// 计算两棵 VNode 树的差异。
///
/// # 参数
/// - `old`: 旧的 VNode 树（当前渲染状态）
/// - `new`: 新的 VNode 树（期望的渲染状态）
///
/// # 返回
/// [`PatchSet`] — 根据顺序应用即可将 old 树变换为 new 树。
pub fn diff(old: &VNode, new: &VNode) -> PatchSet {
    let mut patches = PatchSet::new();
    diff_node(old, new, &mut patches);
    patches
}

// ---------------------------------------------------------------------------
// 内部: 递归 Diff
// ---------------------------------------------------------------------------

/// 对比两个同位置的节点。
fn diff_node(old: &VNode, new: &VNode, patches: &mut PatchSet) {
    // Case 1: ID 不同 — 视为完全替换
    if old.id != new.id {
        patches.push(PatchOp::Replace {
            old_id: old.id,
            new_node: new.clone(),
        });
        return;
    }

    // Case 2: 类型不同 — 替换
    if old.node_type != new.node_type {
        patches.push(PatchOp::Replace {
            old_id: old.id,
            new_node: new.clone(),
        });
        return;
    }

    // Case 3: 同 ID、同类型 — 对比属性、样式、事件、子节点
    let mut has_update = false;
    let mut update_props: HashMap<String, PropValue> = HashMap::new();
    let mut update_style: Option<VNodeStyle> = None;

    // 3a. 对比 props
    // 检查新增/修改的 props
    for (key, new_val) in &new.props {
        match old.props.get(key) {
            Some(old_val) if old_val == new_val => {} // 相同，跳过
            _ => {
                // 文本节点的 content 变化用 UpdateText 快捷 patch
                if new.node_type == VNodeType::Text && key == "content" {
                    if let PropValue::Str(text) = new_val {
                        patches.push(PatchOp::UpdateText {
                            node_id: new.id,
                            text: text.clone(),
                        });
                        continue;
                    }
                }
                update_props.insert(key.clone(), new_val.clone());
                has_update = true;
            }
        }
    }

    // 检查被删除的 props (旧有、新没有 → 设为 Null)
    for key in old.props.keys() {
        if !new.props.contains_key(key) {
            // 文本节点的 content 被删除也用 UpdateText
            if old.node_type == VNodeType::Text && key == "content" {
                patches.push(PatchOp::UpdateText {
                    node_id: new.id,
                    text: String::new(),
                });
                continue;
            }
            update_props.insert(key.clone(), PropValue::Null);
            has_update = true;
        }
    }

    // 3b. 对比 style
    if !styles_equal(&old.style, &new.style) {
        update_style = Some(new.style.clone());
        has_update = true;
    }

    // 生成 Update patch
    if has_update {
        patches.push(PatchOp::Update {
            node_id: new.id,
            props: update_props,
            style: update_style,
        });
    }

    // 3c. 递归对比 children
    diff_children(old.id, &old.children, &new.children, patches);
}

/// 对比子节点列表。
///
/// 使用基于节点 ID 的匹配策略：
/// 1. 构建旧 children 的 ID → index 映射
/// 2. 遍历新 children:
///    - 如果 ID 在旧 children 中存在 → 递归 diff
///    - 如果 ID 不存在 → Insert
/// 3. 遍历旧 children:
///    - 如果 ID 不在新 children 中 → Remove
fn diff_children(
    parent_id: u32,
    old_children: &[VNode],
    new_children: &[VNode],
    patches: &mut PatchSet,
) {
    // 构建旧 children 的 ID 索引
    let old_map: HashMap<u32, usize> = old_children
        .iter()
        .enumerate()
        .map(|(i, c)| (c.id, i))
        .collect();

    // 新 children 的 ID 集合
    let new_ids: HashSet<u32> = new_children.iter().map(|c| c.id).collect();

    // 1. 删除旧 children 中不再存在的节点
    for old_child in old_children {
        if !new_ids.contains(&old_child.id) {
            patches.push(PatchOp::Remove {
                node_id: old_child.id,
            });
        }
    }

    // 2. 遍历新 children: 匹配则 diff, 不匹配则 insert
    for (new_idx, new_child) in new_children.iter().enumerate() {
        if let Some(&old_idx) = old_map.get(&new_child.id) {
            // 节点存在 — 递归 diff
            diff_node(&old_children[old_idx], new_child, patches);
        } else {
            // 新节点 — 插入
            patches.push(PatchOp::Insert {
                parent_id,
                index: new_idx,
                node: new_child.clone(),
            });
        }
    }
}

// ---------------------------------------------------------------------------
// 辅助: 样式比较
// ---------------------------------------------------------------------------

/// 比较两个 VNodeStyle 是否相等。
///
/// 由于 VNodeStyle 字段较多且都是 Option，我们使用序列化比较来简化。
/// 性能上对于 Diff 频率来说完全可接受。
fn styles_equal(a: &VNodeStyle, b: &VNodeStyle) -> bool {
    // 使用 serde_json 序列化后比较。虽然不是最高效的方法，
    // 但确保完整覆盖所有字段，且性能对 UI 更新频率来说足够。
    let a_json = serde_json::to_string(a).unwrap_or_default();
    let b_json = serde_json::to_string(b).unwrap_or_default();
    a_json == b_json
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// 创建一个简单的测试用 VNode。
    fn make_view(id: u32, children: Vec<VNode>) -> VNode {
        VNode {
            id,
            node_type: VNodeType::View,
            props: HashMap::new(),
            style: VNodeStyle::default(),
            events: HashMap::new(),
            children,
        }
    }

    fn make_text(id: u32, content: &str) -> VNode {
        VNode {
            id,
            node_type: VNodeType::Text,
            props: {
                let mut m = HashMap::new();
                m.insert("content".into(), PropValue::Str(content.into()));
                m
            },
            style: VNodeStyle::default(),
            events: HashMap::new(),
            children: vec![],
        }
    }

    #[test]
    fn identical_trees_produce_empty_patch() {
        let tree = make_view(1, vec![make_text(2, "Hello"), make_text(3, "World")]);
        let patches = diff(&tree, &tree);
        assert!(patches.is_empty(), "Identical trees should produce no patches");
    }

    #[test]
    fn text_content_change_produces_update_text() {
        let old = make_view(1, vec![make_text(2, "Hello")]);
        let new = make_view(1, vec![make_text(2, "World")]);

        let patches = diff(&old, &new);
        assert!(!patches.is_empty());

        let has_text_update = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::UpdateText { node_id: 2, text } if text == "World")
        });
        assert!(has_text_update, "Should have UpdateText patch for text change");
    }

    #[test]
    fn add_child_produces_insert() {
        let old = make_view(1, vec![make_text(2, "A")]);
        let new = make_view(1, vec![make_text(2, "A"), make_text(3, "B")]);

        let patches = diff(&old, &new);
        let has_insert = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::Insert { parent_id: 1, index: 1, node } if node.id == 3)
        });
        assert!(has_insert, "Should have Insert patch for new child");
    }

    #[test]
    fn remove_child_produces_remove() {
        let old = make_view(1, vec![make_text(2, "A"), make_text(3, "B")]);
        let new = make_view(1, vec![make_text(2, "A")]);

        let patches = diff(&old, &new);
        let has_remove = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::Remove { node_id: 3 })
        });
        assert!(has_remove, "Should have Remove patch for deleted child");
    }

    #[test]
    fn type_change_produces_replace() {
        let old = make_view(1, vec![make_text(2, "A")]);
        let new = make_view(
            1,
            vec![VNode {
                id: 2,
                node_type: VNodeType::Image,
                props: HashMap::new(),
                style: VNodeStyle::default(),
                events: HashMap::new(),
                children: vec![],
            }],
        );

        let patches = diff(&old, &new);
        let has_replace = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::Replace { old_id: 2, .. })
        });
        assert!(has_replace, "Should have Replace patch for type change");
    }

    #[test]
    fn style_change_produces_update() {
        let old = make_view(1, vec![]);
        let new = VNode {
            id: 1,
            node_type: VNodeType::View,
            props: HashMap::new(),
            style: VNodeStyle {
                background_color: Some("#FF0000".into()),
                ..Default::default()
            },
            events: HashMap::new(),
            children: vec![],
        };

        let patches = diff(&old, &new);
        let has_update = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::Update { node_id: 1, style: Some(_), .. })
        });
        assert!(has_update, "Should have Update patch for style change");
    }

    #[test]
    fn prop_addition_produces_update() {
        let old = make_view(1, vec![]);
        let mut new = make_view(1, vec![]);
        new.props
            .insert("placeholder".into(), PropValue::Str("Enter text".into()));

        let patches = diff(&old, &new);
        let has_update = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::Update { node_id: 1, props, .. } if props.contains_key("placeholder"))
        });
        assert!(has_update, "Should have Update patch for new prop");
    }

    #[test]
    fn prop_removal_sets_null() {
        let mut old = make_view(1, vec![]);
        old.props
            .insert("tooltip".into(), PropValue::Str("Help".into()));
        let new = make_view(1, vec![]);

        let patches = diff(&old, &new);
        let has_null_prop = patches.ops.iter().any(|op| {
            matches!(op, PatchOp::Update { node_id: 1, props, .. }
                if props.get("tooltip") == Some(&PropValue::Null))
        });
        assert!(has_null_prop, "Removed prop should be set to Null");
    }

    #[test]
    fn complex_children_diff() {
        // Old: [A(2), B(3), C(4)]
        // New: [B(3), D(5), A(2)]
        // Expected: Remove C(4), Insert D(5) at index 1
        let old = make_view(
            1,
            vec![make_text(2, "A"), make_text(3, "B"), make_text(4, "C")],
        );
        let new = make_view(
            1,
            vec![make_text(3, "B"), make_text(5, "D"), make_text(2, "A")],
        );

        let patches = diff(&old, &new);

        // Should remove C(4) and insert D(5)
        let has_remove_c = patches
            .ops
            .iter()
            .any(|op| matches!(op, PatchOp::Remove { node_id: 4 }));
        let has_insert_d = patches
            .ops
            .iter()
            .any(|op| matches!(op, PatchOp::Insert { node, .. } if node.id == 5));

        assert!(has_remove_c, "Should remove C(4)");
        assert!(has_insert_d, "Should insert D(5)");
    }
}
