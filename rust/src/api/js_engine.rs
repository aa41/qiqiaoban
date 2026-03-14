//! Dart 侧 JS 引擎 API。
//!
//! 使用 **同步** rquickjs API 避免 block_on 与 flutter_rust_bridge 的冲突。

use std::collections::HashMap;
use std::sync::Mutex;
use std::sync::OnceLock;

/// 一个完整的 JS 引擎实例 (同步 Runtime + Context)。
struct EngineInstance {
    context: rquickjs::Context,
    _runtime: rquickjs::Runtime,
    /// 原始 JSRuntime 指针 — 用于在 eval 前调用 JS_UpdateStackTop
    raw_rt: *mut rquickjs::qjs::JSRuntime,
}

// SAFETY: 外层 Mutex 串行化所有访问
unsafe impl Send for EngineInstance {}
unsafe impl Sync for EngineInstance {}

/// 全局引擎仓库。
struct EngineStore {
    engines: HashMap<u32, EngineInstance>,
    next_id: u32,
}

fn store() -> &'static Mutex<EngineStore> {
    static STORE: OnceLock<Mutex<EngineStore>> = OnceLock::new();
    STORE.get_or_init(|| {
        Mutex::new(EngineStore {
            engines: HashMap::new(),
            next_id: 1,
        })
    })
}

// ---------------------------------------------------------------------------
// Dart 侧 API
// ---------------------------------------------------------------------------

/// 创建一个新的 JS 引擎实例 (同步)。
pub fn create_js_engine(
    memory_limit_mb: Option<u32>,
    _max_stack_size_kb: Option<u32>,
) -> Result<u32, String> {
    let memory_limit = memory_limit_mb.unwrap_or(32) as usize * 1024 * 1024;

    let runtime = rquickjs::Runtime::new()
        .map_err(|e| format!("Runtime creation failed: {e}"))?;
    runtime.set_memory_limit(memory_limit);
    runtime.set_max_stack_size(256 * 1024 * 1024);

    let context = rquickjs::Context::full(&runtime)
        .map_err(|e| format!("Context creation failed: {e}"))?;

    // 提取原始 JSRuntime 指针 — 用于跨线程 stack_top 修正
    let raw_rt = context.with(|ctx| {
        // Ctx 内部是 NonNull<JSContext>，通过 globals() 创建的 Value 可间接获取
        // 但最简单的方式: 用 JS_GetRuntime(ctx_ptr) — 通过 eval 获取 ctx
        // 我们换个方式: 直接从 Value 的 runtime 引用获取
        unsafe {
            // Ctx 是 #[repr(transparent)] 包装 NonNull<JSContext> + PhantomData
            // 我们可以安全地读取其内部的 ctx 指针
            let ctx_ref: &rquickjs::Ctx = &ctx;
            let ctx_ptr: *mut rquickjs::qjs::JSContext =
                *(ctx_ref as *const rquickjs::Ctx as *const *mut rquickjs::qjs::JSContext);
            rquickjs::qjs::JS_GetRuntime(ctx_ptr)
        }
    });

    let instance = EngineInstance { _runtime: runtime, context, raw_rt };

    let mut guard = store().lock().map_err(|e| format!("Lock error: {e}"))?;
    let id = guard.next_id;
    guard.next_id += 1;
    guard.engines.insert(id, instance);

    Ok(id)
}

/// 在指定引擎中执行 JS 代码 (同步)。
pub fn eval_js(engine_id: u32, code: String) -> Result<String, String> {
    let guard = store().lock().map_err(|e| format!("Lock error: {e}"))?;
    let instance = guard
        .engines
        .get(&engine_id)
        .ok_or_else(|| format!("Engine {engine_id} not found (already destroyed?)"))?;

    // 关键: 在每次 eval 前更新 stack_top 到当前线程
    unsafe { rquickjs::qjs::JS_UpdateStackTop(instance.raw_rt); }

    instance.context.with(|ctx| {
        match ctx.eval::<rquickjs::Value, _>(code.as_str()) {
            Ok(val) => value_to_string(&ctx, val),
            Err(e) => {
                let exc = ctx.catch();
                let js_err = if let Some(obj) = exc.as_object() {
                    let msg: String = obj.get("message").unwrap_or_default();
                    msg
                } else {
                    format!("{exc:?}")
                };
                Err(format!("[qb:js_engine] Error: {e}\n  JS: {js_err}"))
            }
        }
    })
}

/// 将 JS Value 转换为字符串 (同步版)。
fn value_to_string<'a>(ctx: &rquickjs::Ctx<'a>, value: rquickjs::Value<'a>) -> Result<String, String> {
    use rquickjs::{FromJs, Function, Type};
    match value.type_of() {
        Type::String => {
            String::from_js(ctx, value)
                .map_err(|e| format!("String conversion: {e}"))
        }
        Type::Null => Ok("null".to_string()),
        Type::Undefined => Ok("undefined".to_string()),
        Type::Object | Type::Array => {
            let json_stringify: Function = ctx
                .eval("(function(v) { return JSON.stringify(v); })")
                .map_err(|e| format!("JSON.stringify init: {e}"))?;
            let result: String = json_stringify.call((value,))
                .map_err(|e| format!("JSON.stringify call: {e}"))?;
            Ok(result)
        }
        _ => {
            // int, float, bool 等基础类型
            let string_fn: Function = ctx
                .eval("(function(v) { return String(v); })")
                .map_err(|e| format!("String() init: {e}"))?;
            let result: String = string_fn.call((value,))
                .map_err(|e| format!("String() call: {e}"))?;
            Ok(result)
        }
    }
}

/// 销毁指定的 JS 引擎实例。
pub fn destroy_js_engine(engine_id: u32) -> Result<(), String> {
    let mut guard = store().lock().map_err(|e| format!("Lock error: {e}"))?;
    if guard.engines.remove(&engine_id).is_some() {
        Ok(())
    } else {
        Err(format!("Engine {engine_id} not found"))
    }
}

/// 获取当前活跃的引擎数量（调试用途）。
#[flutter_rust_bridge::frb(sync)]
pub fn active_engine_count() -> u32 {
    store()
        .lock()
        .map(|s| s.engines.len() as u32)
        .unwrap_or(0)
}
