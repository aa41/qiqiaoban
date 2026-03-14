//! Dart 侧编译器 API — 模板编译 + 组件创建。
//!
//! 提供以下能力:
//! - `compile_template` — 编译 Vue 模板为 JS render 函数
//! - `compile_and_create_component` — 编译模板 + script，直接创建组件实例

use crate::compiler;

// ---------------------------------------------------------------------------
// Dart 侧 API
// ---------------------------------------------------------------------------

/// 编译 Vue 模板为 JS render 函数代码。
///
/// # 参数
/// - `template`: Vue 模板字符串
///
/// # 返回
/// JS render 函数代码字符串。
///
/// # 示例
/// ```rust
/// let template = "<view><text>{{ message }}</text></view>";
/// let render_fn = compile_template(template.to_string()).unwrap();
/// // render_fn 包含 "function render() { ... }"
/// ```
pub fn compile_template(template: String) -> Result<String, String> {
    compiler::compile(&template)
}

/// 编译模板 + script，返回完整的组件创建 JS 代码。
///
/// 将模板编译为 render 函数，与 script 中的组件选项合并，
/// 生成可直接传给 `create_component` 的 JS 代码。
///
/// # 参数
/// - `template`: Vue 模板字符串
/// - `script`: JS script 内容 (组件选项对象字面量，如 `{ data: ..., methods: ... }`)
///
/// # 返回
/// 可执行的 JS 代码字符串，调用后返回 `{ id, vnode }` JSON。
///
/// # 示例
/// ```rust
/// let template = "<view @tap=\"increment\"><text>{{ count }}</text></view>";
/// let script = "{ data: function() { return { count: 0 }; }, methods: { increment: function() { this.count++; } } }";
/// let js = compile_and_create_component(template.to_string(), script.to_string()).unwrap();
/// ```
pub fn compile_and_create_component(
    template: String,
    script: String,
) -> Result<String, String> {
    let render_fn = compiler::compile(&template)?;

    // 合并 script 选项与编译后的 render 函数
    let js = format!(
        r#"(function() {{
    var _opts = {script};
    _opts.render = {render_fn};
    var _result = __qb_createComponent(_opts);
    return JSON.stringify(_result);
}})()"#
    );

    Ok(js)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compile_simple_template() {
        let result = compile_template("<view><text>Hello</text></view>".to_string());
        assert!(result.is_ok());
        let js = result.unwrap();
        assert!(js.contains("function render()"));
        assert!(js.contains("_h(\"view\""));
        assert!(js.contains("_h(\"text\""));
    }

    #[test]
    fn compile_and_create_produces_valid_js() {
        let template = r#"<view @tap="increment"><text>{{ count }}</text></view>"#;
        let script = r#"{ data: function() { return { count: 0 }; }, methods: { increment: function() { this.count++; } } }"#;

        let result = compile_and_create_component(template.to_string(), script.to_string());
        assert!(result.is_ok());
        let js = result.unwrap();
        assert!(js.contains("__qb_createComponent"));
        assert!(js.contains("_opts.render"));
        assert!(js.contains("this.count"));
        assert!(js.contains(r#"tap: "increment""#));
    }

    #[test]
    fn compile_invalid_template_fails() {
        // v-else without v-if
        let template = "<view v-else></view>";
        let result = compile_template(template.to_string());
        assert!(result.is_err());
    }
}
