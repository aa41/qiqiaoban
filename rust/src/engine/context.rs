//! JS 执行上下文 — 代码执行、函数注册、值交互。
//!
//! [`QBContext`] 封装了 rquickjs 的 `AsyncContext`，是 JS 代码执行的核心入口。
//! 每个 Context 拥有独立的全局对象、变量空间和模块注册表。

use rquickjs::{AsyncContext, FromJs, Function, IntoJs, Value};

use super::error::{EngineError, EngineResult};
use super::runtime::QBRuntime;

/// 七巧板 JS 执行上下文。
///
/// 在一个 [`QBRuntime`] 中可以创建多个 `QBContext`，每个 Context 拥有独立的：
/// - 全局对象 (`globalThis`)
/// - 变量作用域
/// - 已注册的原生函数
pub struct QBContext {
    /// rquickjs 的异步上下文。
    inner: AsyncContext,
}

impl QBContext {
    /// 创建新的 JS 执行上下文。
    pub async fn new(runtime: &QBRuntime) -> EngineResult<Self> {
        let inner = AsyncContext::full(runtime.inner())
            .await
            .map_err(|e| EngineError::runtime_init(format!("Failed to create context: {e}")))?;

        Ok(Self { inner })
    }

    /// 执行一段 JS 代码并返回字符串形式的结果。
    ///
    /// 对于对象类型，返回 JSON.stringify 的结果。
    pub async fn eval_as_string(&self, code: &str) -> EngineResult<String> {
        let code = code.to_string();
        self.inner
            .with(|ctx| {
                let result: Value = ctx.eval(code.as_str()).map_err(|e| {
                    extract_js_error(&ctx, e)
                })?;
                value_to_string(&ctx, result)
            })
            .await
    }

    /// 执行 JS 代码并返回泛型结果。
    ///
    /// 支持返回 `String`、`i32`、`f64`、`bool` 等基础类型。
    pub async fn eval<T>(&self, code: &str) -> EngineResult<T>
    where
        T: for<'js> FromJs<'js> + Send + 'static,
    {
        let code = code.to_string();
        self.inner
            .with(move |ctx| {
                let result: T = ctx.eval(code.as_str()).map_err(|e| {
                    extract_js_error(&ctx, e)
                })?;
                Ok(result)
            })
            .await
    }

    /// 在全局对象上设置一个值。
    pub async fn set_global<V>(&self, name: &str, value: V) -> EngineResult<()>
    where
        V: for<'js> IntoJs<'js> + Send + 'static,
    {
        let name = name.to_string();
        self.inner
            .with(move |ctx| {
                let global = ctx.globals();
                global
                    .set(
                        &*name,
                        value.into_js(&ctx).map_err(|e| {
                            EngineError::type_conversion(format!("Failed to convert value: {e}"))
                        })?,
                    )
                    .map_err(|e| {
                        EngineError::eval(format!("Failed to set global '{name}': {e}"))
                    })?;
                Ok(())
            })
            .await
    }

    /// 获取全局对象上的值。
    pub async fn get_global<T>(&self, name: &str) -> EngineResult<T>
    where
        T: for<'js> FromJs<'js> + Send + 'static,
    {
        let name = name.to_string();
        self.inner
            .with(move |ctx| {
                let global = ctx.globals();
                let value: T = global.get(&*name).map_err(|e| {
                    EngineError::type_conversion(format!("Failed to get global '{name}': {e}"))
                })?;
                Ok(value)
            })
            .await
    }

    /// 调用全局对象上的 JS 函数，返回字符串结果。
    ///
    /// 等价于 `eval("funcName(arg1, arg2, ...)")`，但通过名称查找更安全。
    ///
    /// # 参数
    /// - `func_name`: 全局函数名
    /// - `args_json`: 参数的 JSON 数组表示，例如 `"[1, 2, \"hello\"]"`
    pub async fn call_global_function(
        &self,
        func_name: &str,
        args_json: &str,
    ) -> EngineResult<String> {
        // 通过 apply 调用，避免参数注入风险
        let code = format!(
            "(function() {{ var __args = {args_json}; return {func_name}.apply(null, __args); }})()"
        );
        self.eval_as_string(&code).await
    }
}

// ---------------------------------------------------------------------------
// 辅助函数
// ---------------------------------------------------------------------------

/// 从 rquickjs 错误中提取 JS 异常的详细信息（消息 + 堆栈）。
fn extract_js_error<'a>(ctx: &rquickjs::Ctx<'a>, err: rquickjs::Error) -> EngineError {
    if let rquickjs::Error::Exception = &err {
        if let Some(exception) = ctx.catch().as_exception() {
            return EngineError::eval(format!(
                "{}\n{}",
                exception.message().unwrap_or_default(),
                exception.stack().unwrap_or_default()
            ));
        }
    }
    EngineError::from(err)
}

/// 将 JS Value 转换为人类可读的字符串。
fn value_to_string<'a>(ctx: &rquickjs::Ctx<'a>, value: Value<'a>) -> EngineResult<String> {
    match value.type_of() {
        rquickjs::Type::String => {
            let s: String = FromJs::from_js(ctx, value)
                .map_err(|e| EngineError::type_conversion(format!("String conversion: {e}")))?;
            Ok(s)
        }
        rquickjs::Type::Null => Ok("null".to_string()),
        rquickjs::Type::Undefined => Ok("undefined".to_string()),
        rquickjs::Type::Object | rquickjs::Type::Array => {
            let json_stringify: Function = ctx
                .eval("(function(v) { return JSON.stringify(v); })")
                .map_err(|e| EngineError::type_conversion(format!("JSON.stringify init: {e}")))?;
            let result: String = json_stringify.call((value,)).map_err(|e| {
                EngineError::type_conversion(format!("JSON.stringify call: {e}"))
            })?;
            Ok(result)
        }
        _ => {
            let string_fn: Function = ctx
                .eval("(function(v) { return String(v); })")
                .map_err(|e| EngineError::type_conversion(format!("String() init: {e}")))?;
            let result: String = string_fn.call((value,)).map_err(|e| {
                EngineError::type_conversion(format!("String() call: {e}"))
            })?;
            Ok(result)
        }
    }
}
