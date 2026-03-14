//! 七巧板虚拟节点 (VNode) 模块。
//!
//! 定义了 UI 树的轻量级 Rust 描述，是 JS 逻辑层与 Flutter 渲染层之间的核心协议。
//!
//! # 模块结构
//!
//! - [`node`] — VNode 核心数据结构（节点类型、属性、样式）
//! - [`patch`] — Diff 产生的补丁操作定义
//! - [`diff`] — VNode 树的差异计算算法
//! - [`layout_bridge`] — VNode → Taffy 布局树的桥接
//! - [`event`] — 事件数据结构（Dart → JS 传递协议）
//! - [`event_runtime`] — JS 事件运行时桥接代码
//! - [`reactive_runtime`] — JS 响应式运行时（getter/setter 依赖收集）
//! - [`component_runtime`] — JS 组件运行时（data/computed/watch/methods/render）

pub mod component_runtime;
pub mod diff;
pub mod event;
pub mod event_runtime;
pub mod layout_bridge;
pub mod node;
pub mod patch;
pub mod reactive_runtime;
