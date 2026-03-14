# 七巧板 (Qiqiaoban) — Flutter + JS 动态化方案技术调研

> **版本**: v0.1 | **日期**: 2026-03-13 | **状态**: 调研阶段

---

## 目录

1. [项目愿景与核心目标](#1-项目愿景与核心目标)
2. [整体架构设计](#2-整体架构设计)
3. [双线程模型 — 参考微信小程序](#3-双线程模型--参考微信小程序)
4. [渲染层 — Vue 模板到 Flutter Widget Tree](#4-渲染层--vue-模板到-flutter-widget-tree)
5. [逻辑层 — flutter_rust_bridge + QuickJS](#5-逻辑层--flutter_rust_bridge--quickjs)
6. [Flex 布局引擎](#6-flex-布局引擎)
7. [数据交互与通信协议](#7-数据交互与通信协议)
8. [业界对标方案深度分析](#8-业界对标方案深度分析)
9. [技术选型对比矩阵](#9-技术选型对比矩阵)
10. [风险评估与挑战](#10-风险评估与挑战)
11. [推荐的技术路线图](#11-推荐的技术路线图)
12. [附录 — 术语表](#12-附录--术语表)

---

## 1. 项目愿景与核心目标

**七巧板 (Qiqiaoban)** 旨在构建一套完整的 Flutter 动态化解决方案，使前端开发者能够使用 **Vue 模板语法** 编写 UI，通过 **JavaScript** 编写业务逻辑，最终映射为高性能的 **Flutter Widget Tree** 进行原生渲染。

### 核心设计目标

| 目标 | 描述 |
|------|------|
| **Vue 模板驱动** | 基于 Vue 前端模板语法编写 UI，降低 Flutter 学习门槛 |
| **完整 Flex 布局** | 支持完整的 CSS Flexbox 布局规范（不支持完整 CSS） |
| **原生级性能** | 映射为 Flutter Widget Tree 进行原生渲染，非 WebView |
| **JS 逻辑层** | 通过 flutter_rust_bridge + QuickJS 实现 JS 业务逻辑 |
| **双线程架构** | 逻辑线程推动 UI 线程更新，类似小程序架构 |
| **同步/异步通信** | 支持 Flutter ↔ JS 双向同步 & 异步数据交互 |

### 项目命名含义

"七巧板"寓意着像七巧板拼图一样，用有限的「组件块」拼出无限可能的 UI 界面。

---

## 2. 整体架构设计

### 2.1 架构全景图

```
┌─────────────────────────────────────────────────────────────────┐
│                     七巧板 Runtime                               │
│                                                                 │
│  ┌──────────────────────┐     ┌──────────────────────────────┐  │
│  │    逻辑线程 (JS)       │     │        渲染线程 (Dart)         │  │
│  │                      │     │                              │  │
│  │ ┌──────────────────┐ │     │  ┌────────────────────────┐  │  │
│  │ │  Vue Template     │ │     │  │  Flutter Widget Tree   │  │  │
│  │ │  Compiler (AOT)   │ │     │  │                        │  │  │
│  │ └────────┬─────────┘ │     │  │  ┌──────────────────┐  │  │  │
│  │          ↓           │     │  │  │  Flex Layout      │  │  │  │
│  │ ┌──────────────────┐ │     │  │  │  Engine           │  │  │  │
│  │ │  Virtual Node     │ │     │  │  └──────────────────┘  │  │  │
│  │ │  Tree (VNode)     │─┼──→──┼─│                        │  │  │
│  │ └──────────────────┘ │ ①   │  │  ┌──────────────────┐  │  │  │
│  │                      │     │  │  │  Widget Factory   │  │  │  │
│  │ ┌──────────────────┐ │     │  │  │  (VNode→Widget)   │  │  │  │
│  │ │  QuickJS Engine   │ │     │  │  └──────────────────┘  │  │  │
│  │ │  (Rust 封装)       │ │     │  └────────────────────────┘  │  │
│  │ └──────────────────┘ │     │                              │  │
│  │                      │     │  ┌────────────────────────┐  │  │
│  │ ┌──────────────────┐ │     │  │  Native API Bridge     │  │  │
│  │ │  Business Logic   │ │     │  │  (Platform Channels)   │  │  │
│  │ │  (用户 JS 代码)    │ │     │  └────────────────────────┘  │  │
│  │ └──────────────────┘ │     │                              │  │
│  └──────────────────────┘     └──────────────────────────────┘  │
│               ↑    ↓                                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          flutter_rust_bridge (FFI)                        │   │
│  │          ┌─────────────────────────────────┐              │   │
│  │          │  Rust Core Layer                │              │   │
│  │          │  • QuickJS Binding (rquickjs)   │              │   │
│  │          │  • Flex Layout Calculator       │              │   │
│  │          │  • VNode Diff Engine            │              │   │
│  │          │  • Serialization (MessagePack)  │              │   │
│  │          └─────────────────────────────────┘              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

① 通信协议: Binary MessagePack / JSON (可配置)
```

### 2.2 分层设计

#### Layer 0: Platform Layer（平台层）
- Flutter Engine (Skia/Impeller)
- 各平台原生能力 (Camera, GPS, Bluetooth, etc.)

#### Layer 1: Rust Core Layer（核心层 — Rust）
- **QuickJS 运行时** — 通过 `rquickjs` crate 嵌入
- **Flex 布局计算引擎** — 纯 Rust 实现的 Flexbox 计算器
- **VNode Diff 引擎** — 高效的虚拟节点差异计算
- **序列化模块** — MessagePack / JSON 双协议支持

#### Layer 2: Bridge Layer（桥接层）
- **flutter_rust_bridge v2** — Dart ↔ Rust FFI 自动代码生成
- **StreamSink** — 支持 Rust → Dart 实时数据推送
- **同步调用** — 支持 Dart → Rust 同步方法调用

#### Layer 3: Framework Layer（框架层 — Dart）
- **Widget Factory** — VNode 到 Flutter Widget 的映射工厂
- **State Manager** — 响应式状态管理（对应 JS 侧 data/computed）
- **Event Dispatcher** — 事件系统（对应 JS 侧 methods）
- **Lifecycle Manager** — 组件生命周期管理

#### Layer 4: Application Layer（应用层）
- **Vue SFC (.vue)** — 开发者编写的 Vue 单文件组件
- **JavaScript 业务逻辑** — 运行在 QuickJS 中的用户代码
- **资源文件** — 图片、字体等静态资源

---

## 3. 双线程模型 — 参考微信小程序

### 3.1 微信小程序双线程架构回顾

微信小程序采用经典的 **逻辑层 (AppService) + 渲染层 (View)** 双线程架构：

```
┌─────────────────┐          ┌─────────────────┐
│  Logic Thread   │          │  Render Thread   │
│  (JsCore)       │          │  (WebView)       │
│                 │          │                  │
│  • JS 执行       │  setData │  • WXML 渲染      │
│  • 数据处理       │ ───────→ │  • WXSS 样式      │
│  • 网络请求       │          │  • DOM 操作       │
│  • API 调用      │  Event   │                  │
│                 │ ←─────── │                  │
└─────────────────┘          └─────────────────┘
         ↑    ↓                      ↑    ↓
    ┌──────────────────────────────────────┐
    │         Native (微信客户端)             │
    │    • 线程间通信中转                      │
    │    • 系统 API 调用                      │
    └──────────────────────────────────────┘
```

**核心特征：**
- 逻辑层 **无法直接操作 DOM**，确保安全性
- 渲染层仅负责 UI 展示，不执行用户逻辑
- 所有通信通过 **Native 中转**，数据需序列化
- `setData` 是逻辑层推动渲染层更新的唯一途径

### 3.2 七巧板的双线程设计

我们借鉴小程序,但做了关键优化：

```
┌─────────────────────┐          ┌─────────────────────┐
│  Logic Thread        │          │  Render Thread       │
│  (Rust Isolate)      │          │  (Flutter Main)      │
│                     │          │                     │
│  ┌─────────────────┐ │          │  ┌─────────────────┐ │
│  │ QuickJS Runtime │ │  VNode   │  │ Widget Factory  │ │
│  │                 │ │  Diff    │  │                 │ │
│  │ • 用户 JS 执行   │ │ ───────→ │  │ • VNode→Widget  │ │
│  │ • Vue 响应式状态  │ │          │  │ • Flex Layout   │ │
│  │ • 数据处理       │ │  Event   │  │ • 事件分发       │ │
│  │ • 网络请求       │ │ ←─────── │  │                 │ │
│  └─────────────────┘ │          │  └─────────────────┘ │
│                     │          │                     │
│  ┌─────────────────┐ │          │  ┌─────────────────┐ │
│  │ Flex Layout     │ │          │  │ Native API      │ │
│  │ Calculator      │ │          │  │ (Camera etc.)   │ │
│  │ (Rust 实现)      │ │          │  │                 │ │
│  └─────────────────┘ │          │  └─────────────────┘ │
└─────────────────────┘          └─────────────────────┘
          ↑    ↓                         ↑    ↓
     ┌──────────────────────────────────────────┐
     │   flutter_rust_bridge (FFI / StreamSink)  │
     │   • 零拷贝二进制传输                         │
     │   • 异步 Stream 推送                        │
     │   • 同步方法调用                             │
     └──────────────────────────────────────────┘
```

### 3.3 相较小程序的关键优化

| 对比项 | 微信小程序 | 七巧板 |
|--------|-----------|--------|
| **渲染方式** | WebView (浏览器渲染) | Flutter Widget (原生渲染) |
| **通信方式** | JSON 序列化经 Native 中转 | FFI 直接调用 + Binary 序列化 |
| **布局计算** | WebView CSS 引擎 | Rust Flex 引擎（可在逻辑线程预计算） |
| **性能瓶颈** | setData 序列化 + WebView 渲染 | FFI 传输 + Widget Tree 重建 |
| **JS 引擎** | V8 / JavaScriptCore | QuickJS (轻量、可控) |
| **Diff 位置** | 渲染线程 (Virtual DOM diff) | 逻辑线程 (Rust VNode diff) |

### 3.4 数据流转详解

```
用户操作 → Flutter Event → FFI → QuickJS 事件回调
    → JS 状态变更 (reactive) → 触发 re-render
    → 生成新 VNode Tree → Rust Diff Engine 计算差异
    → Diff Patch (Binary) → FFI StreamSink → Dart 渲染线程
    → Widget Factory 应用 Patch → Flutter 局部重建
    → Skia/Impeller 渲染到屏幕
```

---

## 4. 渲染层 — Vue 模板到 Flutter Widget Tree

### 4.1 Vue 模板编译管线

Vue 3 的模板编译分为三个阶段：

```
Template (HTML-like)
    ↓ ① Parse
AST (Abstract Syntax Tree)
    ↓ ② Transform & Optimize (标记静态节点)
Optimized AST
    ↓ ③ CodeGen
Render Function (JavaScript)
    ↓ ④ Execute
VNode Tree (Virtual DOM)
```

### 4.2 七巧板的定制编译管线

我们需要 **定制 Vue 编译器**，使其输出适合 Flutter 的 VNode：

```
Vue Template (.vue SFC)
    ↓ ① 定制 Parser (基于 @vue/compiler-core)
QB-AST (七巧板 AST，扩展了 flex 布局属性)
    ↓ ② Transform (v-for, v-if, v-bind, 事件绑定)
Optimized QB-AST + 静态提升
    ↓ ③ CodeGen → 生成 JS render 函数
JS Render Function
    ↓ ④ QuickJS 执行 → 生成 VNode Tree
QB-VNode Tree
    ↓ ⑤ Diff (Rust) → 生成 Patch
    ↓ ⑥ FFI → Dart Widget Tree
Flutter Widget Tree
```

### 4.3 Vue 模板语法支持范围

#### ✅ 支持的模板语法

| Vue 语法 | 示例 | Flutter 映射 |
|----------|------|-------------|
| `v-if` / `v-else` | `<div v-if="show">` | 条件 Widget (if/else) |
| `v-for` | `<div v-for="item in list">` | `ListView.builder` / `Column` children |
| `v-bind` (:) | `:class="activeClass"` | Widget 属性动态绑定 |
| `v-on` (@) | `@tap="handleTap"` | `GestureDetector` 事件 |
| `v-model` | `<input v-model="text">` | `TextField` 双向绑定 |
| `v-show` | `<div v-show="visible">` | `Visibility` / `Offstage` |
| `{{ }}` 插值 | `{{ message }}` | `Text` Widget 内容 |
| `<slot>` | `<slot name="header">` | Widget Slot 机制 |
| `<component :is>` | `<component :is="comp">` | 动态组件 |

#### ❌ 不支持的特性

| 特性 | 原因 |
|------|------|
| 完整 CSS | 仅支持 Flexbox 布局子集 |
| `<style scoped>` | 无 CSS 样式系统 |
| `<transition>` | 需自定义 Flutter Animation 映射 (后续迭代) |
| DOM 操作 (`$refs` 直接操作) | JS 无法直接操作 Widget Tree |
| 第三方 Vue 插件 | 依赖浏览器 API 的插件不可用 |

### 4.4 VNode 到 Widget 的映射规则

```javascript
// VNode 数据结构定义
{
  "type": "view",              // 节点类型
  "props": {                   // 属性
    "flex": {                  // Flex 布局属性
      "direction": "column",
      "justifyContent": "center",
      "alignItems": "stretch",
      "flex": 1
    },
    "style": {                 // 样式属性 (非 CSS，自定义子集)
      "backgroundColor": "#FFFFFF",
      "borderRadius": 8,
      "padding": [16, 16, 16, 16],
      "margin": [0, 8, 0, 8]
    },
    "events": {                // 事件绑定
      "tap": "handleTap"
    }
  },
  "children": [ ... ]          // 子节点
}
```

**核心元素映射表：**

| VNode Type | Flutter Widget | 说明 |
|------------|---------------|------|
| `view` | `Container` / `Flex` | 基础容器，支持 Flex 布局 |
| `text` | `Text` | 文本节点 |
| `image` | `Image` | 图片 |
| `scroll-view` | `ListView` / `SingleChildScrollView` | 滚动容器 |
| `input` | `TextField` | 输入框 |
| `button` | `ElevatedButton` / `TextButton` | 按钮 |
| `list` | `ListView.builder` | 高性能长列表 |
| `swiper` | `PageView` | 轮播 |
| `canvas` | `CustomPaint` | 画布 |

### 4.5 编译策略选择 — AOT vs. Runtime

| 策略 | AOT 预编译 | Runtime 运行时编译 |
|------|-----------|-------------------|
| **时机** | 构建时将 .vue 编译为 JS render 函数 | 运行时解析 .vue 模板 |
| **启动速度** | ⚡ 快（跳过编译步骤） | 🐢 慢（需运行时编译） |
| **包体积** | ✅ 小（无需包含编译器） | ❌ 大（需包含模板编译器） |
| **灵活性** | ⚠️ 需预编译 | ✅ 支持服务端下发模板 |
| **推荐** | **主推方案** (Dev 阶段用 Runtime) | 作为可选增强 |

> **推荐**: 采用 **AOT 为主 + Runtime 可选** 的混合策略。开发阶段使用 Runtime 编译实现热重载体验，生产环境使用 AOT 预编译确保性能。

---

## 5. 逻辑层 — flutter_rust_bridge + QuickJS

### 5.1 QuickJS 引擎分析

#### 5.1.1 为什么选择 QuickJS？

| 特性 | QuickJS | V8 | JavaScriptCore |
|------|---------|-----|----------------|
| **体积** | ~210 KB | ~10 MB | ~5 MB |
| **启动时间** | < 300μs | ~50ms | ~30ms |
| **ES6+ 支持** | ES2023 完整 | ES2024 | ES2024 |
| **JIT** | ❌ 无 | ✅ TurboFan | ✅ FTL |
| **嵌入友好** | ✅ 极佳 | ⚠️ 复杂 | ⚠️ macOS/iOS |
| **内存占用** | ~1 MB 基础 | ~20 MB 基础 | ~10 MB 基础 |
| **安全沙箱** | ✅ 原生隔离 | 需额外配置 | 需额外配置 |
| **Rust 绑定** | rquickjs (成熟) | rusty_v8 (chromium) | 无官方 Rust 绑定 |
| **适用场景** | 嵌入式/轻量脚本 | 高性能计算密集 | Apple 平台 |

#### 5.1.2 QuickJS 性能基准

- **纯解释执行**: 比 V8 JIT 慢 20-100x (CPU 密集任务)
- **C 函数调用开销**: 比 JS→JS 调用 **更快** (FFI 友好)
- **启动性能**: 加载 20+ Rust 模块实例 < 4ms
- **内存**: Hello World 仅 ~210 KB

> **结论**: QuickJS 的 JS 执行速度对于 **UI 逻辑**（非 CPU 密集计算）完全足够。真正的计算密集任务应下沉到 Rust 层执行。

#### 5.1.3 通过 Rust (rquickjs) 嵌入 QuickJS

```rust
// Rust 侧: 使用 rquickjs 创建 JS 运行时
use rquickjs::{Context, Runtime, Function, Value};

pub struct QBJsEngine {
    runtime: Runtime,
    context: Context,
}

impl QBJsEngine {
    pub fn new() -> Self {
        let runtime = Runtime::new().unwrap();
        let context = Context::full(&runtime).unwrap();
        Self { runtime, context }
    }

    /// 执行 JS 代码并返回结果
    pub fn eval(&self, code: &str) -> Result<String, String> {
        self.context.with(|ctx| {
            let result: Value = ctx.eval(code).map_err(|e| e.to_string())?;
            Ok(result.to_string())
        })
    }

    /// 注册 Rust 函数供 JS 调用
    pub fn register_native_fn<F>(&self, name: &str, func: F)
    where
        F: Fn(Vec<Value>) -> Value + 'static,
    {
        self.context.with(|ctx| {
            let global = ctx.globals();
            global.set(name, Function::new(ctx, func)).unwrap();
        });
    }

    /// 调用 JS 函数
    pub fn call_js_fn(&self, fn_name: &str, args: &str) -> Result<String, String> {
        let code = format!("{}({})", fn_name, args);
        self.eval(&code)
    }
}
```

### 5.2 flutter_rust_bridge v2 架构

#### 5.2.1 核心能力

| 能力 | 说明 |
|------|------|
| **自动代码生成** | 从 Rust API 自动生成 Dart 绑定代码 |
| **任意类型支持** | 支持复杂 Rust 类型自动转换 |
| **异步支持** | Rust `async fn` → Dart `Future<T>` |
| **Stream 支持** | Rust `StreamSink<T>` → Dart `Stream<T>` |
| **同步调用** | 支持 Dart → Rust 同步调用 (SyncReturn) |
| **双向调用** | Rust 可以调用 Dart 函数 |
| **SSE 编解码** | 新一代高性能序列化编解码器 |
| **跨平台** | Android, iOS, macOS, Windows, Linux, Web |

#### 5.2.2 关键通信模式

**模式 A: Dart → Rust 异步调用**
```
Dart main thread         Rust worker thread
     │                        │
     │── call_rust_fn() ──→   │
     │   (Future<T>)          │── 执行任务
     │                        │── 完成
     │←── return Result ──────│
     │
```

**模式 B: Rust → Dart Stream 推送**
```
Dart main thread         Rust worker thread
     │                        │
     │── subscribe_stream()→  │
     │   (Stream<T>)          │
     │                        │── StreamSink.add(data1)
     │←── data1 ──────────────│
     │                        │── StreamSink.add(data2)
     │←── data2 ──────────────│
     │    ...                  │    ...
```

**模式 C: 同步调用（谨慎使用）**
```
Dart main thread         Rust (FFI 直接调用)
     │                        │
     │── sync_call() ────→    │── 立即执行
     │←── return ─────────────│   (阻塞 Dart!)
     │
```

#### 5.2.3 在七巧板中的应用场景

```rust
// ① Dart → Rust: 初始化 JS 引擎
pub fn init_js_engine() -> Result<EngineHandle, Error>;

// ② Dart → Rust: 加载并执行 Vue 组件
pub fn load_component(engine: &EngineHandle, source: String)
    -> Result<ComponentId, Error>;

// ③ Rust → Dart (Stream): JS 推送 UI 更新
pub fn subscribe_ui_updates(
    engine: &EngineHandle,
    sink: StreamSink<VNodePatch>,
);

// ④ Dart → Rust: 转发用户事件到 JS
pub fn dispatch_event(
    engine: &EngineHandle,
    component_id: ComponentId,
    event: EventPayload,
) -> Result<(), Error>;

// ⑤ Rust → Dart (同步): 获取设备信息等
pub fn get_system_info() -> SystemInfo;  // SyncReturn
```

### 5.3 JS ↔ Dart 数据交互设计

#### 5.3.1 通信时序图

```
┌──────┐      ┌────────────┐      ┌──────────┐      ┌──────────────┐
│ 用户  │      │ Flutter UI │      │ Rust FFI │      │ QuickJS (JS) │
└──┬───┘      └─────┬──────┘      └────┬─────┘      └──────┬───────┘
   │                │                   │                    │
   │── tap 按钮 ──→ │                   │                    │
   │                │── dispatch ──→    │                    │
   │                │   Event(tap,id)   │── call JS ──→     │
   │                │                   │   handler(event)   │
   │                │                   │                    │── 执行业务逻辑
   │                │                   │                    │── setState()
   │                │                   │                    │── 触发 re-render
   │                │                   │                    │── 返回新 VNode
   │                │                   │←── VNode Diff ─── │
   │                │                   │   Patch (binary)   │
   │                │←── StreamSink ── │                    │
   │                │   apply patch     │                    │
   │                │── rebuild ───→    │                    │
   │←── 更新 UI ─── │                   │                    │
   │                │                   │                    │
```

#### 5.3.2 序列化格式选型

| 格式 | 大小 | 序列化速度 | 反序列化速度 | 人类可读 | 推荐场景 |
|------|------|-----------|-------------|---------|---------|
| **MessagePack** | ★★★★★ | ★★★★☆ | ★★★★★ | ❌ | **UI Patch 传输（主推）** |
| **JSON** | ★★★☆☆ | ★★★☆☆ | ★★★★☆ | ✅ | 调试模式 / 简单数据 |
| **Protobuf** | ★★★★★ | ★★★★★ | ★★★★★ | ❌ | 备选方案 |
| **FlatBuffers** | ★★★★★ | ★★★★★ | ★★★★★(零拷贝) | ❌ | 极致性能优化 |

> **推荐**: 使用 **MessagePack** 作为主序列化格式（体积小、速度快、Rust/Dart 生态好），开发调试模式降级到 JSON。

---

## 6. Flex 布局引擎

### 6.1 布局引擎选型

| 引擎 | 语言 | 大小 | 性能 | 标准兼容 | 社区/维护 |
|------|------|------|------|---------|----------|
| **Yoga (Meta)** | C/C++ | 小 | ★★★★★ | Flex 子集 | React Native 核心 |
| **Taffy (Rust)** | Rust | 极小 | ★★★★★ | CSS Grid + Flex | 活跃维护 |
| **Stretch** | Rust | 极小 | ★★★★☆ | Flex 子集 | 已归档 → Taffy |
| **自研** | Rust | 可控 | 可控 | 可自定义 | 维护成本高 |

#### 推荐方案：**Taffy**

**理由：**
1. **纯 Rust** — 与项目技术栈完美契合（无需额外 C FFI）
2. **CSS Grid + Flexbox** — 比 Yoga 支持范围更广
3. **零依赖** — `#![no_std]` 兼容，体积极小
4. **活跃维护** — Dioxus (Rust GUI框架) 核心依赖
5. **性能优异** — 与 Yoga 性能持平或更优

### 6.2 支持的 Flex 属性

```yaml
# 容器属性
flex-direction:    row | row-reverse | column | column-reverse
flex-wrap:         nowrap | wrap | wrap-reverse
justify-content:   flex-start | flex-end | center | space-between | space-around | space-evenly
align-items:       flex-start | flex-end | center | stretch | baseline
align-content:     flex-start | flex-end | center | stretch | space-between | space-around

# 子项属性
flex-grow:         <number>     # 放大比例
flex-shrink:       <number>     # 缩小比例
flex-basis:        <length> | auto  # 主轴基础尺寸
align-self:        auto | flex-start | flex-end | center | stretch | baseline
order:             <integer>    # 排列顺序

# 尺寸
width / height:    <length> | <percentage> | auto
min-width / min-height / max-width / max-height

# 间距
margin:            <length> (上, 右, 下, 左)
padding:           <length> (上, 右, 下, 左)
gap:               <length>    # 子元素间距

# 定位 (可选扩展)
position:          relative | absolute
top / right / bottom / left
```

### 6.3 布局计算流程

```
VNode Tree (来自 JS / Diff Patch)
    ↓
构建 Taffy Node Tree (Rust)
    ↓
Taffy.compute_layout(root, available_size)
    ↓
获取每个节点的计算结果: (x, y, width, height)
    ↓
附加到 VNode Patch 中传输给 Dart
    ↓
Flutter Widget 使用 Positioned / SizedBox 精确布局
```

### 6.4 布局计算位置的选择

| 方案 | 在 Rust 线程计算 | 在 Dart 线程计算 |
|------|-----------------|-----------------|
| **优点** | 不阻塞 UI 线程; 复用 Taffy Rust 生态 | 减少跨线程传输; 复用 Flutter 布局系统 |
| **缺点** | 需传输布局结果到 Dart | 阻塞 UI 线程; 需 Dart 实现/绑定 |
| **推荐** | ✅ **推荐** | ⚠️ 仅简单布局 |

> **推荐**: 在 Rust 线程预先计算布局，结果随 VNode Patch 一起传输目标 Dart 线程。对于简单场景，也可以考虑直接使用 Flutter 的 `Flex`/`Row`/`Column` 内置布局能力，避免重复计算。

---

## 7. 数据交互与通信协议

### 7.1 通信协议设计

#### VNode Patch 协议

```
┌────────────────────────────────┐
│          Patch Binary          │
├────────────────────────────────┤
│  Header (4 bytes)              │
│  ├── version: u8               │
│  ├── op_count: u16             │
│  └── flags: u8                 │
├────────────────────────────────┤
│  Operations[]                  │
│  ├── INSERT  { parentId, index, vnode }
│  ├── REMOVE  { nodeId }        │
│  ├── UPDATE  { nodeId, props }  │
│  ├── MOVE    { nodeId, newParentId, index }
│  ├── TEXT    { nodeId, text }   │
│  └── BATCH   { ops[] }         │
└────────────────────────────────┘
```

#### 事件协议

```
┌────────────────────────────────┐
│         Event Payload          │
├────────────────────────────────┤
│  eventType: String             │ // "tap", "longpress", "input", ...
│  targetId: u32                 │ // 目标节点 ID
│  timestamp: u64                │ // 事件时间戳
│  data: Map<String, Dynamic>    │ // 事件数据 (x, y, value, etc.)
└────────────────────────────────┘
```

### 7.2 同步 vs. 异步调用场景

| 场景 | 方向 | 模式 | 说明 |
|------|------|------|------|
| 加载组件 | Dart → Rust | 异步 | 加载 JS 文件可能耗时 |
| 事件分发 | Dart → Rust | 异步 | 不应阻塞 UI 线程 |
| UI 更新推送 | Rust → Dart | Stream | 持续流式推送 Patch |
| 获取设备信息 | JS → Dart (经 Rust) | 同步 | 信息即时可用 |
| 网络请求 | JS → Dart (经 Rust) | 异步 | 网络 IO |
| 存储读写 | JS → Dart (经 Rust) | 异步 | 文件 IO |
| 获取 Flex 计算结果 | Dart → Rust | 同步 | 布局计算需即时结果 |

---

## 8. 业界对标方案深度分析

### 8.1 Kraken (北海) — 阿里巴巴

**架构**: WebView-like 但用 Flutter 渲染

```
JS (QuickJS) → DOM API → DOM Tree + CSSOM → Render Tree → Flutter 渲染
```

| 维度 | 描述 | 对我们的启示 |
|------|------|------------|
| **优点** | 完整 W3C 标准; 支持完整 CSS; React/Vue 直接运行 | Flex 布局的 flutter 映射经验 |
| **缺点** | 过重 (实现完整浏览器); 性能低于纯 Flutter | 我们应做裁剪 |
| **核心差异** | 模拟浏览器 | 我们直接映射 Widget |
| **状态** | ⚠️ 已停止维护 (2023) | 说明完整 W3C 路线不可持续 |

**教训**: 不要试图实现完整的浏览器标准，应当有选择地映射核心能力。

### 8.2 MXFlutter — 腾讯

**架构**: JS 生成 WidgetTree 描述 → Dart 构建真实 Widget

```
JS (Widget DSL) → JSON Widget 描述 → Dart DSL2Widget 引擎 → Flutter Widget
```

| 维度 | 描述 | 对我们的启示 |
|------|------|------------|
| **优点** | 轻量; JS 语法接近 Dart; 热更新 | Widget 映射 DSL 设计参考 |
| **缺点** | JS写Dart语法学习成本高; 无标准布局系统 | 我们用 Vue 语法降低门槛 |
| **核心差异** | JS 镜像 Dart Widget API | 我们用 Vue 模板抽象 |
| **状态** | ⚠️ 已归档 (不再活跃开发) | — |

**教训**: 直接镜像 Dart API 到 JS 的方式学习成本高，不如用前端开发者熟悉的 Vue 语法。

### 8.3 Flutter Fair — 58 同城

**架构**: Dart DSL → JSON → 动态渲染

```
Dart 源码 → Fair Compiler → JSON/JS Bundle → Fair Runtime → Flutter Widget
```

| 维度 | 对我们的启示 |
|------|------------|
| 优点: Dart 语法一致性 | Widget Tree 的 JSON 描述格式 |
| 缺点: 仍需学 Dart | 验证了 JSON 描述 → Widget 的可行性 |

### 8.4 fluttercandies/fjs

**架构**: QuickJS (Rust) → FFI → Flutter

```
JS → rquickjs (Rust) → flutter_rust_bridge → Dart
```

| 维度 | 对我们的启示 |
|------|------------|
| **直接参考价值** | 证明了 Rust + QuickJS + flutter_rust_bridge 技术路线的可行性 |
| 核心特性 | ES6 Module, async/await, GC 管理, 跨平台 |
| 定位差异 | fjs 只是 JS Runtime，我们是完整框架 |

> **核心结论**: fjs 项目验证了我们的技术路线底座是可行的，我们在此基础上构建 Vue 模板编译 + Flex 布局 + 响应式状态管理的上层框架。

### 8.5 方案对比总结

```
                复杂度 ←→ 灵活度 光谱

     轻量/专注                            重量级/全面
     ├─────────────────────────────────────────┤
     │                                         │
  MXFlutter    七巧板          Flutter Fair    Kraken
  (Widget DSL)  (Vue+Flex)      (Dart DSL)    (W3C标准)
     │           │                 │            │
   已归档      ← 我们的位置 →              已停维护
```

---

## 9. 技术选型对比矩阵

### 9.1 JS 引擎选型

| 维度 | QuickJS | V8 | Hermes (Meta) | JavaScriptCore |
|------|---------|-----|---------------|----------------|
| 体积 | ★★★★★ (210KB) | ★★ (10MB) | ★★★★ (3MB) | ★★★ (5MB) |
| 启动速度 | ★★★★★ (<300μs) | ★★ (~50ms) | ★★★★ (~15ms) | ★★★ (~30ms) |
| 执行性能 | ★★★ (纯解释) | ★★★★★ (JIT) | ★★★★ (字节码) | ★★★★ (JIT) |
| 嵌入性 | ★★★★★ | ★★ | ★★★★ | ★★★ |
| Rust 绑定 | ★★★★★ (rquickjs) | ★★★ (rusty_v8) | ★★ | ★★ |
| 跨平台 | ★★★★★ | ★★★★ | ★★★ (Android优先) | ★★★ (Apple优先) |
| **选择** | ✅ **推荐** | 备选 | 不推荐 | 不推荐 |

### 9.2 Flex 布局引擎选型

| 维度 | Taffy (Rust) | Yoga (C++) | 自研 (Rust) | Flutter内置 |
|------|-------------|-----------|------------|------------|
| 语言适配 | ★★★★★ | ★★★ (需C FFI) | ★★★★★ | ★★★ (Dart) |
| 功能完整性 | ★★★★★ (Grid+Flex) | ★★★★ (Flex) | 可控 | ★★★ (非标准) |
| 维护状态 | ★★★★★ | ★★★★ | 需自维护 | ★★★★★ |
| 性能 | ★★★★★ | ★★★★★ | 可控 | ★★★★ |
| **选择** | ✅ **推荐** | 备选 | 不推荐 | 简单场景可用 |

### 9.3 通信桥接选型

| 维度 | flutter_rust_bridge | dart:ffi 手写 | MethodChannel |
|------|-------------------|-------------|--------------|
| 开发效率 | ★★★★★ (自动生成) | ★★ (全手写) | ★★★★ (简单) |
| 性能 | ★★★★★ (FFI 直调) | ★★★★★ (FFI 直调) | ★★★ (序列化) |
| 类型安全 | ★★★★★ | ★★ | ★★★ |
| Stream 支持 | ★★★★★ | ★★ (需手写) | ★★★ (Event Channel) |
| **选择** | ✅ **推荐** | 不推荐 | 不推荐 |

---

## 10. 风险评估与挑战

### 10.1 技术风险

| 风险 | 等级 | 描述 | 缓解措施 |
|------|------|------|---------|
| **QuickJS 性能瓶颈** | 🟡 中 | 复杂组件 re-render 可能慢 | ① 静态节点提升 ② 计算下沉 Rust ③ 异步分批渲染 |
| **跨线程通信延迟** | 🟡 中 | FFI 调用 + 序列化有延迟 | ① MessagePack 二进制传输 ② 批量 Patch ③ 布局预计算 |
| **Vue 编译器定制复杂** | 🔴 高 | 完整 Vue 编译器需大量适配 | ① 只实现核心子集 ② 基于 @vue/compiler-core 扩展 |
| **Widget 映射不完整** | 🟡 中 | Flutter Widget 丰富但映射有限 | ① 逐步扩展映射表 ② 支持自定义 Widget 注册 |
| **调试体验差** | 🟡 中 | JS ↔ Rust ↔ Dart 链路长 | ① 开发模式 JSON 通信 ② 日志聚合 ③ source map |
| **三端一致性** | 🟢 低 | Flutter 天然跨平台 | Flex 布局在 Rust 计算，与平台无关 |

### 10.2 工程风险

| 风险 | 等级 | 描述 | 缓解措施 |
|------|------|------|---------|
| **Rust 学习曲线** | 🟡 中 | 团队可能缺乏 Rust 经验 | ① Rust Core 层由专人维护 ② 上层框架用 Dart 开发 |
| **构建复杂度** | 🟡 中 | Rust + Flutter + JS 三重构建链 | ① 统一 Makefile/脚本 ② CI 模板 |
| **社区/生态** | 🔴 高 | 自研框架需自建生态 | ① Vue 语法降低迁移成本 ② 渐进式能力开放 |

### 10.3 关键挑战

1. **Widget Tree 增量更新效率** — VNode Diff → Widget Patch 的映射效率是核心性能指标
2. **事件响应延迟** — 用户事件跨 3 层 (Dart → Rust → JS → Rust → Dart) 的 round-trip 延迟
3. **内存管理** — JS GC + Rust 所有权 + Dart GC 三套内存系统的协调
4. **热更新机制** — JS Bundle 的安全下载、校验、加载、缓存策略

---

## 11. 推荐的技术路线图

### Phase 0: 基础设施 (2-3 周)

```
[ ] 搭建 flutter_rust_bridge 项目骨架
[ ] 集成 rquickjs，实现基本 JS 执行
[ ] 实现 Dart ↔ Rust ↔ JS 双向通信 PoC
[ ] 集成 Taffy，验证 Flex 布局计算
```

### Phase 1: 核心框架 (4-6 周)

```
[ ] 设计 VNode 数据结构与协议
[ ] 实现 VNode Diff 算法 (Rust)
[ ] 实现 Widget Factory (VNode → Flutter Widget)
[ ] 实现基础 Flex 布局映射
[ ] 事件系统 (Dart → JS)
[ ] 响应式状态管理 (JS 侧)
```

### Phase 2: Vue 编译器 (3-4 周)

```
[ ] 定制 Vue Template Parser
[ ] 实现 v-if / v-for / v-bind / v-on 编译
[ ] 实现 {{ }} 插值编译
[ ] AOT 编译工具链 (.vue → .js bundle)
[ ] <slot> 插槽机制
```

### Phase 3: 开发体验 (2-3 周)

```
[ ] DevTools 调试面板
[ ] Hot Reload (开发模式)
[ ] JS Source Map 支持
[ ] CLI 工具 (项目创建/构建/调试)
[ ] 文档站点
```

### Phase 4: 生产就绪 (3-4 周)

```
[ ] JS Bundle 下载/缓存/校验机制
[ ] 性能优化 (分批渲染, 懒加载, 虚拟列表)
[ ] 错误捕获与上报
[ ] 安全沙箱加固
[ ] 基准测试与性能报告
```

---

## 12. 附录 — 术语表

| 术语 | 说明 |
|------|------|
| **VNode** | Virtual Node, 虚拟节点，UI 树的轻量级 JS 对象表示 |
| **Widget Tree** | Flutter 的 UI 组件树 |
| **FFI** | Foreign Function Interface, 外部函数接口 |
| **SFC** | Single File Component, Vue 单文件组件 (.vue) |
| **AOT** | Ahead-of-Time, 预编译 |
| **JIT** | Just-in-Time, 即时编译 |
| **QuickJS** | Fabrice Bellard 开发的轻量级 JS 引擎 |
| **rquickjs** | QuickJS 的 Rust 绑定 |
| **Taffy** | Rust 实现的 CSS Flexbox/Grid 布局引擎 |
| **flutter_rust_bridge** | Dart ↔ Rust FFI 自动绑定生成器 |
| **MessagePack** | 高效二进制序列化格式 |
| **StreamSink** | flutter_rust_bridge 提供的 Rust → Dart 流式推送机制 |
| **Kraken** | 阿里巴巴基于 Flutter 的 Web 渲染引擎 (已停止维护) |
| **MXFlutter** | 腾讯的 Flutter 动态化框架 (已归档) |
| **Yoga** | Meta 的跨平台 Flex 布局引擎 |

---

> **下一步行动**: 基于本文档的调研结论，进入 Phase 0 基础设施搭建阶段，优先验证 Dart ↔ Rust ↔ QuickJS 通信链路的 PoC。
