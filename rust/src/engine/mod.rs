//! 七巧板 JS 引擎模块。
//!
//! 基于 [rquickjs](https://docs.rs/rquickjs) 封装的 QuickJS 运行时，
//! 提供安全、高性能的 JavaScript 执行环境。
//!
//! # 模块结构
//!
//! - [`runtime`] — JS 运行时生命周期管理
//! - [`context`] — JS 执行上下文（eval、函数注册等）
//! - [`error`] — 统一错误类型

pub mod context;
pub mod error;
pub mod runtime;
pub mod sandbox;
