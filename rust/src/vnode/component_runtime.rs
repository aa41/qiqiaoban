//! JS 组件运行时 — Vue 风格的组件定义与生命周期管理。
//!
//! 注入 QuickJS 后提供:
//! - `__qb_createComponent(options)` — 创建组件实例
//! - `__qb_getComponentVNode(id)` — 获取组件当前 VNode
//! - `__qb_callMethod(id, method, args)` — 调用组件方法
//! - `__qb_destroyComponent(id)` — 销毁组件

/// JS 组件运行时代码。
///
/// 依赖: 必须在 `REACTIVE_RUNTIME_JS` 和 `EVENT_RUNTIME_JS` 之后注入。
///
/// 组件定义格式:
/// ```javascript
/// __qb_createComponent({
///     data: function() { return { count: 0 }; },
///     computed: { doubled: function() { return this.count * 2; } },
///     watch: { count: function(n, o) { /* ... */ } },
///     methods: { increment: function() { this.count++; } },
///     render: function() { return { id: 1, type: "view", ... }; }
/// });
/// ```
pub const COMPONENT_RUNTIME_JS: &str = r##"
(function() {
    var componentIdCounter = 0;
    var components = {};  // id -> Component instance
    // 暴露给 Dart 侧 JS 代码访问
    globalThis.__qb_components = components;

    // =========================================================================
    // Component 构造
    // =========================================================================

    function Component(options) {
        this.id = ++componentIdCounter;
        this.options = options;
        this._watchers = [];
        this._computedWatchers = {};
        this._vnode = null;

        // 1. 初始化 data (响应式)
        this._initData();

        // 2. 初始化 computed
        this._initComputed();

        // 3. 初始化 methods
        this._initMethods();

        // 4. 初始化 watch
        this._initWatch();

        // 5. 事件绑定映射 (nodeId_eventType -> methodName)
        this.__eventBindings = {};

        // 6. 首次 render（不使用 watcher，直接调用）
        this._vnode = this.options.render.call(this);
        this.__currentVNode = this._vnode;

        // 7. 自动注册事件绑定
        this._bindVNodeEvents(this._vnode);
    }

    // 初始化 data — 将 data() 返回值转为响应式并代理到 this 上
    Component.prototype._initData = function() {
        var dataFn = this.options.data;
        var data = typeof dataFn === 'function' ? dataFn.call(this) : (dataFn || {});
        this._data = __qb_reactive(data);

        // 代理: this.xxx -> this._data.xxx
        var self = this;
        var keys = Object.keys(this._data);
        for (var i = 0; i < keys.length; i++) {
            (function(key) {
                Object.defineProperty(self, key, {
                    enumerable: true,
                    configurable: true,
                    get: function() { return self._data[key]; },
                    set: function(val) { self._data[key] = val; }
                });
            })(keys[i]);
        }
    };

    // 初始化 computed — 使用 lazy watcher
    Component.prototype._initComputed = function() {
        var computed = this.options.computed || {};
        var self = this;
        var keys = Object.keys(computed);

        for (var i = 0; i < keys.length; i++) {
            (function(key) {
                var getter = computed[key];
                var c = __qb_computed(function() { return getter.call(self); });
                self._computedWatchers[key] = c;

                Object.defineProperty(self, key, {
                    enumerable: true,
                    configurable: true,
                    get: function() { return c.value; }
                });
            })(keys[i]);
        }
    };

    // 初始化 methods — 绑定 this 到组件
    Component.prototype._initMethods = function() {
        var methods = this.options.methods || {};
        var self = this;
        var keys = Object.keys(methods);

        for (var i = 0; i < keys.length; i++) {
            (function(key) {
                self[key] = function() {
                    return methods[key].apply(self, arguments);
                };
            })(keys[i]);
        }
    };

    // 初始化 watch — 监听 data 变化
    Component.prototype._initWatch = function() {
        var watch = this.options.watch || {};
        var self = this;
        var keys = Object.keys(watch);

        for (var i = 0; i < keys.length; i++) {
            (function(key) {
                var handler = watch[key];
                var unwatch = __qb_watch(
                    function() { return self[key]; },
                    function(newVal, oldVal) { handler.call(self, newVal, oldVal); }
                );
                self._watchers.push(unwatch);
            })(keys[i]);
        }
    };

    // 递归绑定 VNode 中的事件到组件方法
    Component.prototype._bindVNodeEvents = function(vnode) {
        if (!vnode) return;

        if (vnode.events && typeof vnode.events === 'object') {
            var eventKeys = Object.keys(vnode.events);
            for (var i = 0; i < eventKeys.length; i++) {
                var eventType = eventKeys[i];
                var methodName = vnode.events[eventType];
                if (typeof methodName === 'string' && typeof this[methodName] === 'function') {
                    // 存储绑定映射供 Dart 侧查找
                    this.__eventBindings[vnode.id + '_' + eventType] = methodName;

                    var self = this;
                    var method = this[methodName];
                    (function(nodeId, evType, fn, comp) {
                        __qb_bindEvent(nodeId, evType, function(event) {
                            fn.call(comp, event);
                            return true;
                        });
                    })(vnode.id, eventType, method, this);
                }
            }
        }

        if (vnode.children) {
            for (var j = 0; j < vnode.children.length; j++) {
                this._bindVNodeEvents(vnode.children[j]);
            }
        }
    };

    // 重新渲染组件（直接调用 render，不通过 watcher）
    Component.prototype._rerender = function() {
        this.__eventBindings = {};
        this._vnode = this.options.render.call(this);
        this.__currentVNode = this._vnode;
        // 重新绑定事件
        __qb_clearEvents();
        this._bindVNodeEvents(this._vnode);
        return this._vnode;
    };

    // 获取当前 VNode
    Component.prototype.getVNode = function() {
        return this._vnode;
    };

    // 调用组件方法并触发 re-render
    Component.prototype.callMethod = function(methodName, args) {
        if (typeof this[methodName] !== 'function') {
            throw new Error('Method "' + methodName + '" not found on component ' + this.id);
        }
        this[methodName].apply(this, args || []);

        // 方法可能修改了 state → 直接 re-render
        return this._rerender();
    };

    // 销毁组件
    Component.prototype.destroy = function() {
        for (var i = 0; i < this._watchers.length; i++) {
            this._watchers[i]();
        }
        this._watchers = [];
        this._vnode = null;
    };

    // =========================================================================
    // 公开 API
    // =========================================================================

    globalThis.__qb_createComponent = function(options) {
        var comp = new Component(options);
        components[comp.id] = comp;
        return {
            id: comp.id,
            vnode: comp.getVNode()
        };
    };

    globalThis.__qb_getComponentVNode = function(id) {
        var comp = components[id];
        if (!comp) throw new Error('Component ' + id + ' not found');
        return comp.getVNode();
    };

    globalThis.__qb_callMethod = function(id, methodName, args) {
        var comp = components[id];
        if (!comp) throw new Error('Component ' + id + ' not found');
        return comp.callMethod(methodName, args);
    };

    globalThis.__qb_destroyComponent = function(id) {
        var comp = components[id];
        if (comp) {
            comp.destroy();
            delete components[id];
        }
    };

    globalThis.__qb_getComponent = function(id) {
        return components[id] || null;
    };
})();
"##;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn component_runtime_js_contains_api() {
        assert!(COMPONENT_RUNTIME_JS.contains("__qb_createComponent"));
        assert!(COMPONENT_RUNTIME_JS.contains("__qb_getComponentVNode"));
        assert!(COMPONENT_RUNTIME_JS.contains("__qb_callMethod"));
        assert!(COMPONENT_RUNTIME_JS.contains("__qb_destroyComponent"));
        assert!(COMPONENT_RUNTIME_JS.contains("_initData"));
        assert!(COMPONENT_RUNTIME_JS.contains("_initComputed"));
        assert!(COMPONENT_RUNTIME_JS.contains("_initMethods"));
        assert!(COMPONENT_RUNTIME_JS.contains("_initWatch"));
    }
}
