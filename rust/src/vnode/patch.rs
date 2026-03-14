//! Patch 操作定义 — Diff 算法的输出格式。
//!
//! [`PatchOp`] 描述了对 VNode 树的一个原子修改操作，
//! [`PatchSet`] 是一次 Diff 产生的所有操作集合。

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use super::node::{PropValue, VNode, VNodeStyle};

// ---------------------------------------------------------------------------
// PatchOp — 单个补丁操作
// ---------------------------------------------------------------------------

/// Diff 产生的补丁操作。
///
/// 每个 `PatchOp` 是一个原子操作，Dart 侧按顺序应用即可更新 Widget Tree。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "camelCase")]
pub enum PatchOp {
    /// 插入新节点到指定父节点的指定位置。
    #[serde(rename_all = "camelCase")]
    Insert {
        parent_id: u32,
        index: usize,
        node: VNode,
    },

    /// 移除指定节点。
    #[serde(rename_all = "camelCase")]
    Remove {
        node_id: u32,
    },

    /// 更新指定节点的属性和/或样式。
    #[serde(rename_all = "camelCase")]
    Update {
        node_id: u32,
        #[serde(default, skip_serializing_if = "HashMap::is_empty")]
        props: HashMap<String, PropValue>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        style: Option<VNodeStyle>,
    },

    /// 更新文本节点的内容（快捷操作，等价于 Update props.content）。
    #[serde(rename_all = "camelCase")]
    UpdateText {
        node_id: u32,
        text: String,
    },

    /// 替换整个节点（类型不同时使用）。
    #[serde(rename_all = "camelCase")]
    Replace {
        old_id: u32,
        new_node: VNode,
    },

    /// 移动节点到新的父节点/位置。
    #[serde(rename_all = "camelCase")]
    Move {
        node_id: u32,
        new_parent_id: u32,
        index: usize,
    },
}

// ---------------------------------------------------------------------------
// PatchSet — 批量补丁
// ---------------------------------------------------------------------------

/// 一次 Diff 计算产生的补丁集合。
///
/// 包含按顺序执行的操作列表。空 `PatchSet` 表示两棵树完全相同。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PatchSet {
    /// 按顺序执行的补丁操作列表。
    pub ops: Vec<PatchOp>,
}

impl PatchSet {
    /// 创建一个空的 PatchSet。
    pub fn new() -> Self {
        Self { ops: Vec::new() }
    }

    /// 添加一个补丁操作。
    pub fn push(&mut self, op: PatchOp) {
        self.ops.push(op);
    }

    /// 是否没有任何操作（两棵树相同）。
    pub fn is_empty(&self) -> bool {
        self.ops.is_empty()
    }

    /// 操作数量。
    pub fn len(&self) -> usize {
        self.ops.len()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::vnode::node::VNodeType;

    #[test]
    fn serialize_insert_patch() {
        let patch = PatchOp::Insert {
            parent_id: 1,
            index: 0,
            node: VNode {
                id: 2,
                node_type: VNodeType::Text,
                props: {
                    let mut m = HashMap::new();
                    m.insert("content".into(), PropValue::Str("Hello".into()));
                    m
                },
                style: VNodeStyle::default(),
                events: HashMap::new(),
                children: vec![],
            },
        };

        let json = serde_json::to_string(&patch).expect("Serialize failed");
        assert!(json.contains("\"op\":\"insert\""));
        assert!(json.contains("\"parentId\":1"));
    }

    #[test]
    fn serialize_update_patch() {
        let patch = PatchOp::Update {
            node_id: 5,
            props: {
                let mut m = HashMap::new();
                m.insert("content".into(), PropValue::Str("Updated text".into()));
                m
            },
            style: None,
        };

        let json = serde_json::to_string(&patch).expect("Serialize failed");
        assert!(json.contains("\"op\":\"update\""));
        assert!(json.contains("\"nodeId\":5"));
    }

    #[test]
    fn patchset_is_empty() {
        let ps = PatchSet::new();
        assert!(ps.is_empty());
        assert_eq!(ps.len(), 0);
    }
}
