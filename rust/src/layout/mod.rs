//! 七巧板布局模块。
//!
//! 基于 [Taffy](https://docs.rs/taffy) 的 Flexbox 布局引擎，
//! 计算节点的位置和尺寸，供 Flutter 侧渲染。
//!
//! # 模块结构
//!
//! - [`style`] — Flex 样式定义（对应 CSS Flexbox 属性子集）
//! - [`tree`] — 布局树管理与计算

pub mod style;
pub mod tree;
