//! JS 事件运行时 — 注入到 QuickJS 的桥接代码。
//!
//! 提供 JS 侧的事件处理器注册和分发机制。
//! 由 Rust 在引擎初始化时自动注入。

/// JS 事件运行时代码。
///
/// 注入后提供以下全局 API:
/// - `__qb_bindEvent(nodeId, eventType, handler)` — 注册事件处理器
/// - `__qb_unbindEvent(nodeId, eventType)` — 取消事件处理器
/// - `__qb_dispatch_event__(eventJson)` — Rust 调用入口，分发事件到对应处理器
/// - `__qb_clearEvents()` — 清空所有事件处理器
pub const EVENT_RUNTIME_JS: &str = r#"
(function() {
    // 全局事件处理器注册表: { nodeId: { eventType: handler } }
    globalThis.__qb_event_handlers__ = {};

    // 当前渲染函数（可选，用于事件触发后 re-render）
    globalThis.__qb_render_fn__ = null;

    // 注册事件处理器
    globalThis.__qb_bindEvent = function(nodeId, eventType, handler) {
        if (!__qb_event_handlers__[nodeId]) {
            __qb_event_handlers__[nodeId] = {};
        }
        __qb_event_handlers__[nodeId][eventType] = handler;
    };

    // 取消事件处理器
    globalThis.__qb_unbindEvent = function(nodeId, eventType) {
        if (__qb_event_handlers__[nodeId]) {
            delete __qb_event_handlers__[nodeId][eventType];
        }
    };

    // 清空所有事件处理器
    globalThis.__qb_clearEvents = function() {
        globalThis.__qb_event_handlers__ = {};
    };

    // 设置渲染函数（事件处理器可能触发 re-render）
    globalThis.__qb_setRenderFn = function(fn) {
        globalThis.__qb_render_fn__ = fn;
    };

    // Rust 调用入口 — 分发事件到 JS 处理器
    globalThis.__qb_dispatch_event__ = function(eventJson) {
        try {
            var event = JSON.parse(eventJson);
            var handlers = __qb_event_handlers__[event.nodeId];

            if (!handlers || !handlers[event.eventType]) {
                return JSON.stringify({ "result": "none" });
            }

            // 调用事件处理器
            var handlerResult = handlers[event.eventType](event);

            // 如果处理器返回了对象，视为 re-render 请求
            if (handlerResult && typeof handlerResult === 'object') {
                return JSON.stringify({
                    "result": "rerender",
                    "vnode": handlerResult
                });
            }

            // 如果设置了全局渲染函数且处理器返回 true，触发 re-render
            if (handlerResult === true && __qb_render_fn__) {
                var newVNode = __qb_render_fn__();
                if (newVNode) {
                    return JSON.stringify({
                        "result": "rerender",
                        "vnode": newVNode
                    });
                }
            }

            return JSON.stringify({ "result": "none" });
        } catch (e) {
            return JSON.stringify({
                "result": "none",
                "error": String(e)
            });
        }
    };
})();
"#;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn event_runtime_js_is_not_empty() {
        assert!(!EVENT_RUNTIME_JS.is_empty());
        assert!(EVENT_RUNTIME_JS.contains("__qb_dispatch_event__"));
        assert!(EVENT_RUNTIME_JS.contains("__qb_bindEvent"));
        assert!(EVENT_RUNTIME_JS.contains("__qb_event_handlers__"));
    }
}
