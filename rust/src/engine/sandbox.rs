//! 安全沙箱 — JS 执行环境限制。
//!
//! 提供以下保护:
//! - 内存使用限制
//! - 执行时间限制
//! - VNode 树深度/大小限制
//! - 危险 API 检测

/// 沙箱配置。
#[derive(Debug, Clone)]
pub struct SandboxConfig {
    /// JS 堆内存限制 (字节)，默认 32MB。
    pub max_memory_bytes: usize,
    /// 单次执行时间限制 (毫秒)，默认 5000ms。
    pub max_execution_time_ms: u64,
    /// VNode 树最大深度，默认 50。
    pub max_vnode_depth: usize,
    /// VNode 树最大节点数，默认 10000。
    pub max_vnode_count: usize,
    /// 最大字符串长度 (属性/文本内容)，默认 100KB。
    pub max_string_length: usize,
    /// 是否禁用 eval()，默认 true。
    pub disable_eval: bool,
    /// 是否禁用动态 import()，默认 true。
    pub disable_dynamic_import: bool,
}

impl Default for SandboxConfig {
    fn default() -> Self {
        Self {
            max_memory_bytes: 32 * 1024 * 1024, // 32 MB
            max_execution_time_ms: 5_000,         // 5s
            max_vnode_depth: 50,
            max_vnode_count: 10_000,
            max_string_length: 100 * 1024, // 100 KB
            disable_eval: true,
            disable_dynamic_import: true,
        }
    }
}

/// 沙箱验证器。
pub struct SandboxValidator;

impl SandboxValidator {
    /// 验证 JS 代码安全性 (静态分析)。
    ///
    /// 检查是否包含危险模式:
    /// - `eval(`, `Function(`, `new Function`
    /// - `import(` (动态导入)
    /// - `__proto__`, `constructor['constructor']` (原型污染)
    pub fn validate_js_code(code: &str, config: &SandboxConfig) -> Result<(), String> {
        // 检查代码长度
        if code.len() > config.max_string_length {
            return Err(format!(
                "JS code exceeds max length: {} > {}",
                code.len(),
                config.max_string_length
            ));
        }

        // 检查危险 API
        if config.disable_eval {
            let dangerous_patterns = [
                "eval(",
                "new Function(",
                "Function(",
            ];
            for pattern in &dangerous_patterns {
                if code.contains(pattern) {
                    return Err(format!(
                        "Forbidden API detected: '{}'. eval/Function is disabled.",
                        pattern
                    ));
                }
            }
        }

        if config.disable_dynamic_import && code.contains("import(") {
            return Err("Dynamic import() is disabled in sandbox mode.".to_string());
        }

        // 检查原型污染
        let proto_patterns = ["__proto__", "constructor[\"constructor\"]", "constructor['constructor']"];
        for pattern in &proto_patterns {
            if code.contains(pattern) {
                return Err(format!(
                    "Potential prototype pollution detected: '{}'",
                    pattern
                ));
            }
        }

        Ok(())
    }

    /// 验证 VNode 树大小限制。
    pub fn validate_vnode_size(
        node_count: usize,
        max_depth: usize,
        config: &SandboxConfig,
    ) -> Result<(), String> {
        if node_count > config.max_vnode_count {
            return Err(format!(
                "VNode count ({}) exceeds limit ({})",
                node_count, config.max_vnode_count
            ));
        }
        if max_depth > config.max_vnode_depth {
            return Err(format!(
                "VNode depth ({}) exceeds limit ({})",
                max_depth, config.max_vnode_depth
            ));
        }
        Ok(())
    }

    /// 计算 VNode 树的节点数和最大深度。
    pub fn measure_vnode_tree(vnode_json: &str) -> Result<(usize, usize), String> {
        let value: serde_json::Value =
            serde_json::from_str(vnode_json).map_err(|e| format!("VNode parse error: {e}"))?;
        let (count, depth) = Self::count_nodes(&value, 0);
        Ok((count, depth))
    }

    fn count_nodes(value: &serde_json::Value, current_depth: usize) -> (usize, usize) {
        let mut count = 1;
        let mut max_depth = current_depth;

        if let Some(children) = value.get("children").and_then(|c| c.as_array()) {
            for child in children {
                let (child_count, child_depth) = Self::count_nodes(child, current_depth + 1);
                count += child_count;
                max_depth = max_depth.max(child_depth);
            }
        }

        (count, max_depth)
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config_sane() {
        let cfg = SandboxConfig::default();
        assert_eq!(cfg.max_memory_bytes, 32 * 1024 * 1024);
        assert_eq!(cfg.max_vnode_depth, 50);
        assert!(cfg.disable_eval);
    }

    #[test]
    fn validate_safe_code() {
        let cfg = SandboxConfig::default();
        assert!(SandboxValidator::validate_js_code(
            "var x = 1 + 2;",
            &cfg
        ).is_ok());
    }

    #[test]
    fn detect_eval() {
        let cfg = SandboxConfig::default();
        let result = SandboxValidator::validate_js_code("eval('alert(1)')", &cfg);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("eval"));
    }

    #[test]
    fn detect_dynamic_import() {
        let cfg = SandboxConfig::default();
        let result = SandboxValidator::validate_js_code("import('malicious.js')", &cfg);
        assert!(result.is_err());
    }

    #[test]
    fn detect_proto_pollution() {
        let cfg = SandboxConfig::default();
        let result = SandboxValidator::validate_js_code("obj.__proto__.x = 1", &cfg);
        assert!(result.is_err());
    }

    #[test]
    fn code_too_long() {
        let cfg = SandboxConfig {
            max_string_length: 10,
            ..Default::default()
        };
        let result = SandboxValidator::validate_js_code("a very long code string here!", &cfg);
        assert!(result.is_err());
    }

    #[test]
    fn vnode_size_ok() {
        let cfg = SandboxConfig::default();
        assert!(SandboxValidator::validate_vnode_size(100, 10, &cfg).is_ok());
    }

    #[test]
    fn vnode_too_many_nodes() {
        let cfg = SandboxConfig {
            max_vnode_count: 5,
            ..Default::default()
        };
        assert!(SandboxValidator::validate_vnode_size(10, 2, &cfg).is_err());
    }

    #[test]
    fn measure_simple_tree() {
        let json = r#"{"id":1,"children":[{"id":2,"children":[]},{"id":3,"children":[{"id":4,"children":[]}]}]}"#;
        let (count, depth) = SandboxValidator::measure_vnode_tree(json).unwrap();
        assert_eq!(count, 4);
        assert_eq!(depth, 2);
    }
}
