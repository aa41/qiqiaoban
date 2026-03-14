//! 错误 API — 结构化错误捕获与报告。
//!
//! 提供 JS 执行的安全包裹，捕获异常并返回结构化错误信息。

use serde::{Deserialize, Serialize};

/// 七巧板结构化错误。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QBError {
    /// 错误来源: "compile" / "runtime" / "render" / "network"
    pub source: String,
    /// 错误消息。
    pub message: String,
    /// JS 堆栈 (可选)。
    pub stack: Option<String>,
    /// 关联的组件 ID (可选)。
    pub component_id: Option<i32>,
    /// 时间戳 (Unix ms)。
    pub timestamp: u64,
}

impl QBError {
    pub fn compile(message: String) -> Self {
        Self {
            source: "compile".to_string(),
            message,
            stack: None,
            component_id: None,
            timestamp: Self::now_ms(),
        }
    }

    pub fn runtime(message: String, component_id: Option<i32>) -> Self {
        Self {
            source: "runtime".to_string(),
            message,
            stack: None,
            component_id,
            timestamp: Self::now_ms(),
        }
    }

    pub fn render(message: String, component_id: Option<i32>) -> Self {
        Self {
            source: "render".to_string(),
            message,
            stack: None,
            component_id,
            timestamp: Self::now_ms(),
        }
    }

    fn now_ms() -> u64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0)
    }
}

/// 安全执行模板编译，返回结构化错误。
pub fn safe_compile_template(template: String) -> Result<String, String> {
    match crate::compiler::compile(&template) {
        Ok(js) => Ok(js),
        Err(e) => {
            let err = QBError::compile(e);
            Err(serde_json::to_string(&err).unwrap_or_else(|_| err.message.clone()))
        }
    }
}

/// 获取最近的 JS 引擎错误列表 (JSON)。
pub fn get_recent_errors() -> String {
    // 返回空数组 — 错误在 Dart 侧聚合
    "[]".to_string()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qb_error_compile() {
        let err = QBError::compile("Unexpected token".to_string());
        assert_eq!(err.source, "compile");
        assert!(err.timestamp > 0);

        let json = serde_json::to_string(&err).unwrap();
        assert!(json.contains("compile"));
        assert!(json.contains("Unexpected token"));
    }

    #[test]
    fn safe_compile_valid() {
        let result = safe_compile_template("<view></view>".to_string());
        assert!(result.is_ok());
    }

    #[test]
    fn safe_compile_invalid() {
        let result = safe_compile_template("<view v-else></view>".to_string());
        assert!(result.is_err());
        // 错误应该是结构化的 JSON
        let err_json = result.unwrap_err();
        assert!(err_json.contains("compile"));
    }
}
