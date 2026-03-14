//! Dart 侧组件 API — 组件生命周期管理。
//!
//! 使用 **同步** rquickjs API，避免 tokio block_on 与 flutter_rust_bridge 的冲突。

use std::sync::Mutex;
use std::sync::OnceLock;

use crate::vnode::component_runtime::COMPONENT_RUNTIME_JS;
use crate::vnode::event_runtime::EVENT_RUNTIME_JS;
use crate::vnode::reactive_runtime::REACTIVE_RUNTIME_JS;

/// JS console 桥接 — 在 QuickJS 中注入 console.log/warn/error/info。
/// 所有输出通过 globalThis.__qb_console_output__ 收集。
const CONSOLE_BRIDGE_JS: &str = r#"
(function() {
    globalThis.__qb_console_output__ = [];
    function makeLogger(level) {
        return function() {
            var parts = [];
            for (var i = 0; i < arguments.length; i++) {
                var arg = arguments[i];
                if (typeof arg === 'object' && arg !== null) {
                    try { parts.push(JSON.stringify(arg)); }
                    catch(e) { parts.push(String(arg)); }
                } else {
                    parts.push(String(arg));
                }
            }
            var msg = parts.join(' ');
            globalThis.__qb_console_output__.push('[' + level + '] ' + msg);
        };
    }
    globalThis.console = {
        log: makeLogger('LOG'),
        warn: makeLogger('WARN'),
        error: makeLogger('ERROR'),
        info: makeLogger('INFO'),
        debug: makeLogger('DEBUG')
    };
})();
"#;

/// 同步 JS 引擎包装。
struct ComponentEngine {
    context: rquickjs::Context,
    // Runtime must stay alive as long as Context exists
    _runtime: rquickjs::Runtime,
    /// 原始 JSRuntime 指针 — 用于跨线程 stack_top 修正
    raw_rt: *mut rquickjs::qjs::JSRuntime,
}

// SAFETY: rquickjs Runtime/Context 内部有锁保护; 外层通过 Mutex 串行化访问。
unsafe impl Send for ComponentEngine {}
unsafe impl Sync for ComponentEngine {}

fn component_engine() -> &'static Mutex<Option<ComponentEngine>> {
    static ENGINE: OnceLock<Mutex<Option<ComponentEngine>>> = OnceLock::new();
    ENGINE.get_or_init(|| Mutex::new(None))
}

/// 从 Ctx 中提取原始 JSRuntime 指针。
fn extract_raw_runtime(ctx: &rquickjs::Ctx<'_>) -> *mut rquickjs::qjs::JSRuntime {
    unsafe {
        let ctx_ptr: *mut rquickjs::qjs::JSContext =
            *(ctx as *const rquickjs::Ctx as *const *mut rquickjs::qjs::JSContext);
        rquickjs::qjs::JS_GetRuntime(ctx_ptr)
    }
}

fn ensure_component_engine() -> Result<(), String> {
    let mut guard = component_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    if guard.is_some() {
        return Ok(());
    }

    eprintln!("[qb:component] Creating sync engine...");
    let runtime = rquickjs::Runtime::new()
        .map_err(|e| format!("Runtime creation failed: {e}"))?;
    runtime.set_memory_limit(64 * 1024 * 1024);
    runtime.set_max_stack_size(256 * 1024 * 1024); // 256MB 安全值

    let context = rquickjs::Context::full(&runtime)
        .map_err(|e| format!("Context creation failed: {e}"))?;

    // 注入 console 桥接（避免 JS 中 console.log 报错）
    let raw_rt = context.with(|ctx| -> Result<*mut rquickjs::qjs::JSRuntime, String> {
        let rt = extract_raw_runtime(&ctx);
        unsafe { rquickjs::qjs::JS_UpdateStackTop(rt); }
        ctx.eval::<rquickjs::Value, _>(CONSOLE_BRIDGE_JS)
            .map(|_| ())
            .map_err(|e| format!("Console bridge injection: {e}"))?;
        // 按顺序注入运行时: 事件 → 响应式 → 组件
        ctx.eval::<rquickjs::Value, _>(EVENT_RUNTIME_JS)
            .map(|_| ())
            .map_err(|e| format!("Event runtime injection: {e}"))?;
        ctx.eval::<rquickjs::Value, _>(REACTIVE_RUNTIME_JS)
            .map(|_| ())
            .map_err(|e| format!("Reactive runtime injection: {e}"))?;
        ctx.eval::<rquickjs::Value, _>(COMPONENT_RUNTIME_JS)
            .map(|_| ())
            .map_err(|e| format!("Component runtime injection: {e}"))?;
        Ok(rt)
    })?;

    eprintln!("[qb:component] Engine created OK (sync mode)");
    *guard = Some(ComponentEngine { _runtime: runtime, context, raw_rt });
    Ok(())
}

/// 同步执行 JS 并返回字符串结果。
/// 自动处理所有 JS 类型: 字符串直传，对象 JSON.stringify，基础类型 String()。
fn eval_sync(code: &str) -> Result<String, String> {
    let guard = component_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    let engine = guard.as_ref().ok_or("Engine not initialized")?;
    engine.context.with(|ctx| {
        unsafe { rquickjs::qjs::JS_UpdateStackTop(engine.raw_rt); }
        match ctx.eval::<rquickjs::Value, _>(code) {
            Ok(val) => {
                use rquickjs::{FromJs, Function, Type};
                match val.type_of() {
                    Type::String => {
                        String::from_js(&ctx, val)
                            .map_err(|e| format!("String conversion: {e}"))
                    }
                    Type::Null => Ok("null".to_string()),
                    Type::Undefined => Ok("undefined".to_string()),
                    Type::Object | Type::Array => {
                        let stringify: Function = ctx
                            .eval("(function(v) { return JSON.stringify(v); })")
                            .map_err(|e| format!("JSON.stringify init: {e}"))?;
                        stringify.call::<_, String>((val,))
                            .map_err(|e| format!("JSON.stringify call: {e}"))
                    }
                    _ => {
                        let string_fn: Function = ctx
                            .eval("(function(v) { return String(v); })")
                            .map_err(|e| format!("String() init: {e}"))?;
                        string_fn.call::<_, String>((val,))
                            .map_err(|e| format!("String() call: {e}"))
                    }
                }
            }
            Err(e) => {
                let js_err = get_js_exception(&ctx);
                let msg = format!("[qb:component] JS eval error: {e}\n  JS exception: {js_err}");
                eprintln!("{msg}");
                Err(msg)
            }
        }
    })
}

/// 同步执行 JS，忽略返回值。
fn eval_sync_void(code: &str) -> Result<(), String> {
    let guard = component_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    let engine = guard.as_ref().ok_or("Engine not initialized")?;
    engine.context.with(|ctx| {
        match ctx.eval::<rquickjs::Value, _>(code) {
            Ok(_) => Ok(()),
            Err(e) => {
                let js_err = get_js_exception(&ctx);
                let msg = format!("[qb:component] JS eval error: {e}\n  JS exception: {js_err}");
                eprintln!("{msg}");
                Err(msg)
            }
        }
    })
}

/// 从 JS 上下文提取异常详情。
fn get_js_exception(ctx: &rquickjs::Ctx<'_>) -> String {
    let exc = ctx.catch();
    if let Some(obj) = exc.as_object() {
        let msg: String = obj.get("message").unwrap_or_default();
        let stack: String = obj.get("stack").unwrap_or_default();
        if stack.is_empty() { msg } else { format!("{msg}\n  Stack: {stack}") }
    } else if let Some(s) = exc.as_string() {
        s.to_string().unwrap_or_else(|e| format!("{e:?}"))
    } else {
        format!("{exc:?}")
    }
}

// ---------------------------------------------------------------------------
// Dart 侧 API
// ---------------------------------------------------------------------------

/// 创建组件实例。
///
/// 注意: 传入的 JS 已经包含了 `JSON.stringify` 包装,
/// 所以这里直接执行即可，不需要再次包装。
pub fn create_component(js_code: String) -> Result<String, String> {
    ensure_component_engine()?;
    eval_sync(&js_code)
}

/// 获取组件当前 VNode 的 JSON 表示。
pub fn get_component_vnode(component_id: i32) -> Result<String, String> {
    ensure_component_engine()?;
    let code = format!("JSON.stringify(__qb_getComponentVNode({component_id}))");
    eval_sync(&code)
}

/// 调用组件方法，返回更新后的 VNode JSON。
pub fn call_component_method(
    component_id: i32,
    method: String,
    args_json: String,
) -> Result<String, String> {
    ensure_component_engine()?;
    let code = format!(
        "JSON.stringify(__qb_callMethod({component_id}, \"{method}\", {args_json}))"
    );
    eval_sync(&code)
}

/// 在组件引擎中执行 JS 代码。
pub fn eval_component_js(code: String) -> Result<String, String> {
    ensure_component_engine()?;
    eval_sync(&code)
}

/// 销毁组件实例。
pub fn destroy_component(component_id: i32) -> Result<(), String> {
    ensure_component_engine()?;
    let code = format!("__qb_destroyComponent({component_id})");
    eval_sync_void(&code)
}

/// 销毁组件引擎。
pub fn destroy_component_engine() -> Result<(), String> {
    let mut guard = component_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    *guard = None;
    Ok(())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn component_lifecycle_integration() {
        // 1. 创建简单组件
        let js_code_simple = r#"
            __qb_createComponent({
                data: function() { return { count: 0 }; },
                render: function() {
                    return {
                        id: 1, type: "view",
                        children: [
                            { id: 2, type: "text", props: { content: "Count: " + this.count } }
                        ]
                    };
                }
            })
        "#;

        let result = create_component(js_code_simple.to_string());
        assert!(result.is_ok(), "create_component failed: {:?}", result.err());

        let json_str = result.unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();
        assert!(parsed["id"].is_number());
        assert_eq!(parsed["vnode"]["id"], 1);
        let simple_id = parsed["id"].as_i64().unwrap() as i32;

        // 2. 带 methods 的组件
        let js_code_methods = r#"
            __qb_createComponent({
                data: function() { return { count: 0 }; },
                methods: {
                    increment: function() { this.count++; }
                },
                render: function() {
                    return {
                        id: 10, type: "view",
                        children: [
                            { id: 11, type: "text", props: { content: "Count: " + this.count } }
                        ]
                    };
                }
            })
        "#;

        let result2 = create_component(js_code_methods.to_string()).unwrap();
        let parsed2: serde_json::Value = serde_json::from_str(&result2).unwrap();
        let methods_id = parsed2["id"].as_i64().unwrap() as i32;

        let vnode_json = get_component_vnode(methods_id).unwrap();
        let vnode: serde_json::Value = serde_json::from_str(&vnode_json).unwrap();
        assert_eq!(vnode["children"][0]["props"]["content"], "Count: 0");

        let new_vnode_json = call_component_method(
            methods_id, "increment".to_string(), "[]".to_string(),
        ).unwrap();
        let new_vnode: serde_json::Value = serde_json::from_str(&new_vnode_json).unwrap();
        assert_eq!(new_vnode["children"][0]["props"]["content"], "Count: 1");

        // 3. 带 computed 的组件
        let js_code_computed = r#"
            __qb_createComponent({
                data: function() { return { count: 5 }; },
                computed: {
                    doubled: function() { return this.count * 2; }
                },
                render: function() {
                    return {
                        id: 20, type: "text",
                        props: { content: "Doubled: " + this.doubled }
                    };
                }
            })
        "#;

        let result3 = create_component(js_code_computed.to_string()).unwrap();
        let parsed3: serde_json::Value = serde_json::from_str(&result3).unwrap();
        let computed_id = parsed3["id"].as_i64().unwrap() as i32;

        let vnode_json3 = get_component_vnode(computed_id).unwrap();
        let vnode3: serde_json::Value = serde_json::from_str(&vnode_json3).unwrap();
        assert_eq!(vnode3["props"]["content"], "Doubled: 10");

        // 清理
        destroy_component(simple_id).unwrap();
        destroy_component(methods_id).unwrap();
        destroy_component(computed_id).unwrap();
        destroy_component_engine().unwrap();
    }

    /// 使用真实编译器输出测试组件创建和 VNode 获取。
    /// 精确模拟 Flutter 端 QBComponentWidget._initComponent 的流程。
    #[test]
    fn component_with_compiler_output() {
        use crate::api::compiler_api::compile_and_create_component;

        // 先清理旧引擎状态
        let _ = destroy_component_engine();

        let template = r#"<view @tap="increment"><text>Count: {{ count }}</text></view>"#;
        let script = r#"{ data: function() { return { count: 0 }; }, methods: { increment: function() { this.count++; } } }"#;

        // Step 1: 编译 (纯 Rust 字符串操作)
        let js = compile_and_create_component(template.to_string(), script.to_string())
            .expect("compile_and_create_component failed");
        eprintln!("[test] Compiled JS ({} bytes)", js.len());

        // Step 2: 执行 (模拟 evalComponentJs)
        let result_json = eval_component_js(js).expect("eval_component_js failed");
        eprintln!("[test] Result: {}", &result_json[..result_json.len().min(200)]);

        let parsed: serde_json::Value = serde_json::from_str(&result_json)
            .expect("Failed to parse result");
        let comp_id = parsed["id"].as_i64().expect("No id in result") as i32;
        assert!(comp_id > 0, "Component ID should be positive, got {}", comp_id);

        // Step 3: 获取 VNode (Flutter 报 stack overflow 的调用!)
        let vnode_json = get_component_vnode(comp_id)
            .expect("get_component_vnode FAILED - stack overflow?");
        eprintln!("[test] VNode: {}", &vnode_json[..vnode_json.len().min(200)]);

        let vnode: serde_json::Value = serde_json::from_str(&vnode_json)
            .expect("Failed to parse VNode JSON");
        assert_eq!(vnode["type"], "view");

        // Step 4: 调用方法
        let new_vnode_json = call_component_method(
            comp_id, "increment".to_string(), "[]".to_string()
        ).expect("call_component_method failed");
        eprintln!("[test] After increment: {}", &new_vnode_json[..new_vnode_json.len().min(200)]);

        // 清理
        destroy_component(comp_id).unwrap();
        destroy_component_engine().unwrap();
    }
}
