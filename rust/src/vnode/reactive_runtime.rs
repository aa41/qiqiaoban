//! JS 响应式运行时 — Vue 风格的 getter/setter 依赖收集系统。
//!
//! 注入 QuickJS 后提供:
//! - `__qb_reactive(obj)` — 将对象属性转为响应式（getter/setter 拦截）
//! - `__qb_computed(fn)` — 创建缓存 computed 值
//! - `__qb_watch(getter, callback)` — 监听数据变化

/// JS 响应式运行时代码。
///
/// 核心机制:
/// 1. `__qb_reactive(obj)` 遍历对象属性，用 `Object.defineProperty`
///    替换为 getter/setter，getter 中收集依赖，setter 中通知订阅者。
/// 2. `__qb_computed(fn)` 包装计算函数，首次调用时收集依赖，
///    依赖变化时标记为 dirty，下次读取时重新计算。
/// 3. `__qb_watch(getter, callback)` 监听 getter 返回值变化，
///    变化时调用 callback(newVal, oldVal)。
pub const REACTIVE_RUNTIME_JS: &str = r#"
(function() {
    // =========================================================================
    // 依赖收集核心
    // =========================================================================

    // 当前正在收集依赖的 watcher (栈顶)
    var depStack = [];

    function pushTarget(watcher) {
        depStack.push(watcher);
    }

    function popTarget() {
        depStack.pop();
    }

    function currentTarget() {
        return depStack.length > 0 ? depStack[depStack.length - 1] : null;
    }

    // =========================================================================
    // Dep — 依赖管理器
    // =========================================================================

    var depIdCounter = 0;

    function Dep() {
        this.id = depIdCounter++;
        this.subs = [];  // 订阅者列表
    }

    Dep.prototype.addSub = function(watcher) {
        for (var i = 0; i < this.subs.length; i++) {
            if (this.subs[i] === watcher) return;
        }
        this.subs.push(watcher);
    };

    Dep.prototype.removeSub = function(watcher) {
        var idx = this.subs.indexOf(watcher);
        if (idx > -1) this.subs.splice(idx, 1);
    };

    Dep.prototype.depend = function() {
        var target = currentTarget();
        if (target) {
            target.addDep(this);
        }
    };

    Dep.prototype.notify = function() {
        var subs = this.subs.slice();
        for (var i = 0; i < subs.length; i++) {
            subs[i].update();
        }
    };

    // =========================================================================
    // Watcher — 观察者
    // =========================================================================

    var watcherIdCounter = 0;

    function Watcher(getter, callback, options) {
        this.id = watcherIdCounter++;
        this.getter = getter;
        this.callback = callback;
        this.deps = [];
        this.lazy = options && options.lazy;
        this.dirty = this.lazy;
        this.value = this.lazy ? undefined : this.get();
    }

    Watcher.prototype.get = function() {
        pushTarget(this);
        var value;
        try {
            value = this.getter();
        } finally {
            popTarget();
        }
        return value;
    };

    Watcher.prototype.addDep = function(dep) {
        for (var i = 0; i < this.deps.length; i++) {
            if (this.deps[i].id === dep.id) return;
        }
        this.deps.push(dep);
        dep.addSub(this);
    };

    Watcher.prototype.update = function() {
        if (this.lazy) {
            this.dirty = true;
        } else if (this.callback) {
            var oldValue = this.value;
            this.value = this.get();
            this.callback(this.value, oldValue);
        }
    };

    Watcher.prototype.evaluate = function() {
        this.value = this.get();
        this.dirty = false;
    };

    Watcher.prototype.teardown = function() {
        for (var i = 0; i < this.deps.length; i++) {
            this.deps[i].removeSub(this);
        }
        this.deps = [];
    };

    // =========================================================================
    // reactive — 将对象属性转为响应式
    // =========================================================================

    function defineReactive(obj, key, val) {
        var dep = new Dep();

        // 如果值是对象，递归转化
        if (val !== null && typeof val === 'object' && !Array.isArray(val)) {
            observeObject(val);
        }

        Object.defineProperty(obj, key, {
            enumerable: true,
            configurable: true,
            get: function() {
                dep.depend();
                return val;
            },
            set: function(newVal) {
                if (newVal === val) return;
                val = newVal;
                // 新值如果是对象，也要响应式化
                if (newVal !== null && typeof newVal === 'object' && !Array.isArray(newVal)) {
                    observeObject(newVal);
                }
                dep.notify();
            }
        });
    }

    function observeObject(obj) {
        if (obj.__qb_observed__) return;
        Object.defineProperty(obj, '__qb_observed__', {
            value: true,
            enumerable: false,
            configurable: false
        });
        var keys = Object.keys(obj);
        for (var i = 0; i < keys.length; i++) {
            defineReactive(obj, keys[i], obj[keys[i]]);
        }
    }

    // =========================================================================
    // 公开 API
    // =========================================================================

    // 将对象转为响应式
    globalThis.__qb_reactive = function(obj) {
        if (obj === null || typeof obj !== 'object') return obj;
        observeObject(obj);
        return obj;
    };

    // 创建 computed 值 (lazy watcher)
    globalThis.__qb_computed = function(getter) {
        var watcher = new Watcher(getter, null, { lazy: true });
        return {
            get value() {
                if (watcher.dirty) {
                    watcher.evaluate();
                }
                // 如果当前有依赖收集，传递依赖
                var target = currentTarget();
                if (target) {
                    for (var i = 0; i < watcher.deps.length; i++) {
                        watcher.deps[i].depend();
                    }
                }
                return watcher.value;
            }
        };
    };

    // 监听数据变化
    globalThis.__qb_watch = function(getter, callback) {
        var watcher = new Watcher(getter, callback);
        return function() {
            watcher.teardown();
        };
    };

    // 内部 API 供组件运行时使用
    globalThis.__qb_internals__ = {
        Dep: Dep,
        Watcher: Watcher,
        pushTarget: pushTarget,
        popTarget: popTarget
    };
})();
"#;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reactive_runtime_js_contains_api() {
        assert!(REACTIVE_RUNTIME_JS.contains("__qb_reactive"));
        assert!(REACTIVE_RUNTIME_JS.contains("__qb_computed"));
        assert!(REACTIVE_RUNTIME_JS.contains("__qb_watch"));
        assert!(REACTIVE_RUNTIME_JS.contains("defineReactive"));
        assert!(REACTIVE_RUNTIME_JS.contains("__qb_internals__"));
    }
}
