//! QuickJS 运行时的生命周期管理。
//!
//! [`QBRuntime`] 封装了 rquickjs 的 `Runtime`，负责：
//! - JS 引擎实例的创建与销毁
//! - 内存限制配置
//! - 全局模块加载器注册

use rquickjs::{AsyncRuntime};

use super::error::{EngineError, EngineResult};

/// QuickJS 运行时的最大堆内存（默认 32 MB）。
const DEFAULT_MEMORY_LIMIT: usize = 32 * 1024 * 1024;

/// QuickJS 运行时的最大栈深度（默认 512 KB）。
const DEFAULT_MAX_STACK_SIZE: usize = 512 * 1024;

/// 七巧板 JS 运行时。
///
/// 封装了 QuickJS 的 `AsyncRuntime`，提供引擎级别的生命周期管理。
/// 一个 `QBRuntime` 对应一个独立的 JS 运行时实例，可包含多个执行上下文。
///
/// # 线程安全
///
/// `QBRuntime` 内部使用 `AsyncRuntime`，支持跨线程使用。
///
/// # 示例
///
/// ```rust
/// let runtime = QBRuntime::new(QBRuntimeConfig::default())?;
/// ```
pub struct QBRuntime {
    /// rquickjs 的异步运行时。
    inner: AsyncRuntime,
}

/// 运行时配置参数。
#[derive(Debug, Clone)]
pub struct QBRuntimeConfig {
    /// 最大堆内存限制（字节）。
    ///
    /// QuickJS 会在达到此限制时触发 OutOfMemory 错误。
    /// 默认: 32 MB。
    pub memory_limit: usize,

    /// 最大栈深度（字节）。
    ///
    /// 防止深度递归导致栈溢出。
    /// 默认: 512 KB。
    pub max_stack_size: usize,
}

impl Default for QBRuntimeConfig {
    fn default() -> Self {
        Self {
            memory_limit: DEFAULT_MEMORY_LIMIT,
            max_stack_size: DEFAULT_MAX_STACK_SIZE,
        }
    }
}

impl QBRuntime {
    /// 创建新的 JS 运行时实例。
    ///
    /// # 参数
    /// - `config`: 运行时配置（内存限制、栈深度等）
    ///
    /// # 错误
    /// 当 QuickJS 运行时初始化失败时返回 `EngineError::RuntimeInit`。
    pub async fn new(config: QBRuntimeConfig) -> EngineResult<Self> {
        let inner = AsyncRuntime::new()
            .map_err(|e| EngineError::runtime_init(format!("Failed to create runtime: {e}")))?;

        // 配置内存限制
        inner.set_memory_limit(config.memory_limit).await;
        inner.set_max_stack_size(config.max_stack_size).await;

        Ok(Self { inner })
    }

    /// 获取内部的 rquickjs AsyncRuntime 引用。
    ///
    /// 用于创建 [`QBContext`](super::context::QBContext)。
    pub(crate) fn inner(&self) -> &AsyncRuntime {
        &self.inner
    }
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn create_runtime_with_default_config() {
        let runtime = QBRuntime::new(QBRuntimeConfig::default()).await;
        assert!(runtime.is_ok(), "Should create runtime with default config");
    }

    #[tokio::test]
    async fn create_runtime_with_custom_config() {
        let config = QBRuntimeConfig {
            memory_limit: 8 * 1024 * 1024,  // 8 MB
            max_stack_size: 256 * 1024,       // 256 KB
        };
        let runtime = QBRuntime::new(config).await;
        assert!(runtime.is_ok(), "Should create runtime with custom config");
    }
}
