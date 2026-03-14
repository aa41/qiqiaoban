//! Dart 侧 VNode API — 暴露 VNode 管线核心操作。
//!
//! 使用 **同步** rquickjs API，避免 tokio block_on 与 flutter_rust_bridge 的冲突。

use std::collections::HashMap;
use std::sync::Mutex;
use std::sync::OnceLock;

use crate::api::poc_render::RenderNode;
use crate::vnode::diff;
use crate::vnode::event::EventResult;
use crate::vnode::event_runtime::EVENT_RUNTIME_JS;
use crate::vnode::layout_bridge;
use crate::vnode::node::{VNode, VNodeType};
use crate::vnode::patch::PatchSet;

/// 同步 JS 引擎。
struct VNodeEngine {
    context: rquickjs::Context,
    _runtime: rquickjs::Runtime,
    raw_rt: *mut rquickjs::qjs::JSRuntime,
}

// SAFETY: 外层 Mutex 串行化所有访问
unsafe impl Send for VNodeEngine {}
unsafe impl Sync for VNodeEngine {}

fn vnode_engine() -> &'static Mutex<Option<VNodeEngine>> {
    static ENGINE: OnceLock<Mutex<Option<VNodeEngine>>> = OnceLock::new();
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

fn ensure_engine() -> Result<(), String> {
    let mut guard = vnode_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    if guard.is_some() {
        return Ok(());
    }

    eprintln!("[qb:vnode] Creating sync engine...");
    let runtime = rquickjs::Runtime::new()
        .map_err(|e| format!("Runtime creation failed: {e}"))?;
    runtime.set_memory_limit(64 * 1024 * 1024);
    runtime.set_max_stack_size(256 * 1024 * 1024);

    let context = rquickjs::Context::full(&runtime)
        .map_err(|e| format!("Context creation failed: {e}"))?;

    // 注入 console 桥接 + 事件运行时
    let raw_rt = context.with(|ctx| -> Result<*mut rquickjs::qjs::JSRuntime, String> {
        let rt = extract_raw_runtime(&ctx);
        unsafe { rquickjs::qjs::JS_UpdateStackTop(rt); }
        ctx.eval::<rquickjs::Value, _>(r#"
            (function() {
                function noop() {}
                globalThis.console = { log: noop, warn: noop, error: noop, info: noop, debug: noop };
            })();
        "#).map(|_| ()).map_err(|e| format!("Console bridge injection failed: {e}"))?;
        ctx.eval::<rquickjs::Value, _>(EVENT_RUNTIME_JS)
            .map(|_| ())
            .map_err(|e| format!("Event runtime injection failed: {e}"))?;
        Ok(rt)
    })?;

    eprintln!("[qb:vnode] Engine created OK (sync mode)");
    *guard = Some(VNodeEngine { _runtime: runtime, context, raw_rt });
    Ok(())
}

/// 同步执行 JS 返回字符串。
fn eval_sync(code: &str) -> Result<String, String> {
    let guard = vnode_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    let engine = guard.as_ref().ok_or("Engine not initialized")?;
    engine.context.with(|ctx| {
        unsafe { rquickjs::qjs::JS_UpdateStackTop(engine.raw_rt); }
        match ctx.eval::<String, _>(code) {
            Ok(s) => Ok(s),
            Err(e) => {
                let exc = ctx.catch();
                let js_err = if let Some(obj) = exc.as_object() {
                    let msg: String = obj.get("message").unwrap_or_default();
                    let stack: String = obj.get("stack").unwrap_or_default();
                    if stack.is_empty() { msg } else { format!("{msg}\n  Stack: {stack}") }
                } else {
                    format!("{exc:?}")
                };
                let msg = format!("[qb:vnode] JS eval error: {e}\n  JS exception: {js_err}");
                eprintln!("{msg}");
                Err(msg)
            }
        }
    })
}

// ---------------------------------------------------------------------------
// Dart 侧 API
// ---------------------------------------------------------------------------

/// 执行 JS 代码并返回 VNode 树的 JSON 表示。
pub fn parse_vnode_from_js(js_code: String) -> Result<String, String> {
    ensure_engine()?;

    let wrapped = format!(
        r#"(function() {{
            var __result = (function() {{ return {js_code} }})();
            return JSON.stringify(__result);
        }})()"#
    );

    let json_str = eval_sync(&wrapped)?;

    // 验证 JSON 能被解析为 VNode
    let _vnode: VNode =
        serde_json::from_str(&json_str).map_err(|e| format!("VNode parse error: {e}"))?;

    Ok(json_str)
}

/// 对两个 VNode 树执行 Diff，返回 PatchSet 的 JSON 表示。
pub fn diff_vnodes(old_json: String, new_json: String) -> Result<String, String> {
    let old: VNode =
        serde_json::from_str(&old_json).map_err(|e| format!("Old VNode parse error: {e}"))?;
    let new: VNode =
        serde_json::from_str(&new_json).map_err(|e| format!("New VNode parse error: {e}"))?;

    let patches: PatchSet = diff::diff(&old, &new);
    serde_json::to_string(&patches).map_err(|e| format!("PatchSet serialize error: {e}"))
}

/// 从 VNode JSON 计算布局，返回布局结果 JSON。
pub fn compute_layout_from_vnode(
    vnode_json: String,
    width: f64,
    height: f64,
) -> Result<String, String> {
    let vnode: VNode =
        serde_json::from_str(&vnode_json).map_err(|e| format!("VNode parse error: {e}"))?;

    let layout_map = layout_bridge::compute_vnode_layout(&vnode, width as f32, height as f32);

    let result: HashMap<String, serde_json::Value> = layout_map
        .iter()
        .map(|(id, layout)| {
            (
                id.to_string(),
                serde_json::json!({
                    "x": layout.x, "y": layout.y,
                    "width": layout.width, "height": layout.height
                }),
            )
        })
        .collect();

    serde_json::to_string(&result).map_err(|e| format!("Layout serialize error: {e}"))
}

/// 完整管线: JS → VNode → Layout → 渲染数据。
pub fn render_vnode_from_js(
    js_code: String,
    viewport_width: f64,
    viewport_height: f64,
) -> Result<Vec<RenderNode>, String> {
    let vnode_json = parse_vnode_from_js(js_code)?;
    let vnode: VNode =
        serde_json::from_str(&vnode_json).map_err(|e| format!("VNode parse error: {e}"))?;

    let layout_map = layout_bridge::compute_vnode_layout(
        &vnode, viewport_width as f32, viewport_height as f32,
    );

    let mut render_nodes = Vec::new();
    collect_render_nodes(&vnode, &layout_map, &mut render_nodes);
    Ok(render_nodes)
}

/// 分发用户交互事件到 JS 处理函数。
pub fn dispatch_event(event_json: String) -> Result<String, String> {
    ensure_engine()?;

    let escaped = event_json
        .replace('\\', "\\\\")
        .replace('\'', "\\'")
        .replace('\n', "\\n")
        .replace('\r', "\\r");

    let code = format!("__qb_dispatch_event__('{escaped}')");
    let result = eval_sync(&code)?;

    // 验证返回值
    let _: EventResult =
        serde_json::from_str(&result).map_err(|e| format!("EventResult parse error: {e}"))?;
    Ok(result)
}

/// 在 JS 引擎中执行代码。
pub fn eval_vnode_js(code: String) -> Result<String, String> {
    ensure_engine()?;
    eval_sync(&code)
}

/// 销毁 VNode API 引擎。
pub fn destroy_vnode_engine() -> Result<(), String> {
    let mut guard = vnode_engine().lock().map_err(|e| format!("Lock: {e}"))?;
    *guard = None;
    Ok(())
}

/// 从 VNode JSON 直接生成 RenderNode 列表。
pub fn render_vnode_from_json(
    vnode_json: String,
    viewport_width: f64,
    viewport_height: f64,
) -> Result<Vec<RenderNode>, String> {
    let vnode: VNode =
        serde_json::from_str(&vnode_json).map_err(|e| format!("VNode parse error: {e}"))?;

    let layout_map = layout_bridge::compute_vnode_layout(
        &vnode, viewport_width as f32, viewport_height as f32,
    );

    let mut render_nodes = Vec::new();
    collect_render_nodes(&vnode, &layout_map, &mut render_nodes);
    Ok(render_nodes)
}

// ---------------------------------------------------------------------------
// 内部: VNode → RenderNode 收集
// ---------------------------------------------------------------------------

fn collect_render_nodes(
    vnode: &VNode,
    layout_map: &layout_bridge::LayoutMap,
    out: &mut Vec<RenderNode>,
) {
    let layout = layout_map.get(&vnode.id).copied().unwrap_or_default();

    let text = match vnode.node_type {
        VNodeType::Text => vnode.props.get("content").and_then(|v| v.as_str()).map(String::from),
        _ => None,
    };

    out.push(RenderNode {
        id: vnode.id.to_string(),
        node_type: format!("{:?}", vnode.node_type).to_lowercase(),
        text,
        color: vnode.style.background_color.clone(),
        x: layout.x as f64,
        y: layout.y as f64,
        width: layout.width as f64,
        height: layout.height as f64,
        font_size: vnode.style.font_size.map(|v| v as f64),
        text_color: vnode.style.color.clone(),
        events: vnode.events.keys().cloned().collect(),
        children: vec![],
    });

    for child in &vnode.children {
        collect_render_nodes(child, layout_map, out);
    }
}
