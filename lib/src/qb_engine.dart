import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show Uint64List;

import 'rust/api/compiler_api.dart' as compiler_api;
import 'rust/api/component_api.dart' as component_api;
import 'rust/api/js_engine.dart' as js_engine_api;
import 'rust/api/layout_api.dart' as layout_api;
import 'rust/api/poc_render.dart';
import 'rust/api/simple.dart' as rust_api;
import 'rust/api/vnode_api.dart' as vnode_api;
import 'rust/frb_generated.dart';

/// 七巧板引擎 — Dart 侧的统一入口。
///
/// [Qiqiaoban] 封装了与 Rust Core 的所有交互，
/// 提供类型安全、文档完整的 Dart API。
class Qiqiaoban {
  Qiqiaoban._(); // 私有构造，不允许实例化

  static bool _initialized = false;

  // ---------------------------------------------------------------------------
  // 生命周期
  // ---------------------------------------------------------------------------

  /// 初始化七巧板 Rust 运行时。
  ///
  /// 必须在使用任何其他 API 之前调用一次。
  /// 重复调用是安全的，会被自动忽略。
  static Future<void> init() async {
    if (_initialized) return;
    await RustLib.init();
    _initialized = true;
  }

  /// 检查引擎是否已初始化。
  static bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // 同步 API — Step 1 验证
  // ---------------------------------------------------------------------------

  /// 返回 Rust Core 的版本号。
  static String get rustCoreVersion => rust_api.rustCoreVersion();

  /// 返回问候消息，验证 Dart → Rust 同步通信。
  static String greet(String name) => rust_api.greet(name: name);

  // ---------------------------------------------------------------------------
  // 异步 API — Step 1 验证
  // ---------------------------------------------------------------------------

  /// 计算 1 + 2 + ... + n 的累加和。
  static Future<int> sumToN(int n) => rust_api.sumToN(n: n);

  // ---------------------------------------------------------------------------
  // Stream API — Step 1 验证
  // ---------------------------------------------------------------------------

  /// 创建一个每秒递增的整数流。
  static Stream<int> tickStream({required int count}) =>
      rust_api.tickStream(count: count);

  // ---------------------------------------------------------------------------
  // JS 引擎 API — Step 2
  // ---------------------------------------------------------------------------

  /// 创建一个新的 QuickJS 引擎实例。
  ///
  /// 返回引擎 ID，后续通过此 ID 操作引擎。
  ///
  /// - [memoryLimitMb]: 最大堆内存（MB），默认 32
  /// - [maxStackSizeKb]: 最大栈深度（KB），默认 512
  static Future<int> createJsEngine({
    int? memoryLimitMb,
    int? maxStackSizeKb,
  }) =>
      js_engine_api.createJsEngine(
        memoryLimitMb: memoryLimitMb,
        maxStackSizeKb: maxStackSizeKb,
      );

  /// 在指定引擎中执行 JS 代码，返回字符串结果。
  ///
  /// 对象类型会被 JSON.stringify。
  static Future<String> evalJs({
    required int engineId,
    required String code,
  }) =>
      js_engine_api.evalJs(engineId: engineId, code: code);

  /// 销毁指定的 JS 引擎实例。
  static Future<void> destroyJsEngine({required int engineId}) =>
      js_engine_api.destroyJsEngine(engineId: engineId);

  /// 获取当前活跃的引擎数量（调试用途）。
  static int get activeEngineCount => js_engine_api.activeEngineCount();

  // ---------------------------------------------------------------------------
  // 布局 API — Step 3
  // ---------------------------------------------------------------------------

  /// 创建一个新的 Flexbox 布局树。
  ///
  /// 返回布局树 ID，后续通过此 ID 操作。
  static int createLayoutTree() => layout_api.createLayoutTree();

  /// 在布局树中添加一个叶子节点。
  static BigInt layoutAddNode({
    required int treeId,
    double? width,
    double? height,
    double? flexGrow,
    double? flexShrink,
    double? paddingTop,
    double? paddingRight,
    double? paddingBottom,
    double? paddingLeft,
  }) =>
      layout_api.layoutAddNode(
        treeId: treeId,
        width: width,
        height: height,
        flexGrow: flexGrow,
        flexShrink: flexShrink,
        paddingTop: paddingTop,
        paddingRight: paddingRight,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
      );

  /// 在布局树中添加一个容器节点。
  static BigInt layoutAddContainer({
    required int treeId,
    required Uint64List childrenIds,
    String? flexDirection,
    String? justifyContent,
    String? alignItems,
    double? gapRow,
    double? gapColumn,
    double? width,
    double? height,
  }) =>
      layout_api.layoutAddContainer(
        treeId: treeId,
        childrenIds: childrenIds,
        flexDirection: flexDirection,
        justifyContent: justifyContent,
        alignItems: alignItems,
        gapRow: gapRow,
        gapColumn: gapColumn,
        width: width,
        height: height,
      );

  /// 计算布局。
  static void layoutCompute({
    required int treeId,
    required BigInt rootId,
    required double width,
    required double height,
  }) =>
      layout_api.layoutCompute(
        treeId: treeId,
        rootId: rootId,
        width: width,
        height: height,
      );

  /// 获取节点布局结果，返回 [x, y, width, height]。
  static Float64List layoutGetResult({
    required int treeId,
    required BigInt nodeId,
  }) =>
      layout_api.layoutGetResult(treeId: treeId, nodeId: nodeId);

  /// 销毁布局树。
  static void destroyLayoutTree({required int treeId}) =>
      layout_api.destroyLayoutTree(treeId: treeId);

  // ---------------------------------------------------------------------------
  // VNode API — Phase 1
  // ---------------------------------------------------------------------------

  /// 执行 JS 代码并返回 VNode 树的 JSON 字符串。
  ///
  /// JS 代码必须返回一个符合 VNode 约定的对象。
  static Future<String> parseVnodeFromJs({required String jsCode}) =>
      vnode_api.parseVnodeFromJs(jsCode: jsCode);

  /// 对两棵 VNode 树执行 Diff，返回 PatchSet JSON。
  static Future<String> diffVnodes({
    required String oldJson,
    required String newJson,
  }) =>
      vnode_api.diffVnodes(oldJson: oldJson, newJson: newJson);

  /// 从 VNode JSON 计算布局，返回布局结果 JSON。
  static Future<String> computeLayoutFromVnode({
    required String vnodeJson,
    required double width,
    required double height,
  }) =>
      vnode_api.computeLayoutFromVnode(
        vnodeJson: vnodeJson,
        width: width,
        height: height,
      );

  /// 完整管线: JS → VNode → Layout → RenderNode 列表。
  ///
  /// 与 [renderFromJs] 类似，但使用新的 VNode 管线。
  static Future<List<RenderNode>> renderVnodeFromJs({
    required String jsCode,
    required double viewportWidth,
    required double viewportHeight,
  }) =>
      vnode_api.renderVnodeFromJs(
        jsCode: jsCode,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      );

  /// 分发用户交互事件到 JS 处理函数。
  ///
  /// 当 Widget 触发用户交互（tap、longPress 等）时调用此方法，
  /// 事件会通过 Rust FFI 转发到 QuickJS 中注册的处理函数。
  ///
  /// 返回 EventResult JSON:
  /// - `{"result":"none"}` — 无 UI 变化
  /// - `{"result":"rerender","vnode":{...}}` — 需要重新渲染
  static Future<String> dispatchEvent({
    required int nodeId,
    required String eventType,
    Map<String, dynamic>? data,
  }) {
    final event = {
      'nodeId': nodeId,
      'eventType': eventType,
      'data': data ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch.toDouble(),
    };
    return vnode_api.dispatchEvent(
      eventJson: jsonEncode(event),
    );
  }

  /// 在 VNode JS 引擎中执行代码。
  ///
  /// 用于注册事件处理器、设置状态等。
  ///
  /// ```dart
  /// await Qiqiaoban.evalVnodeJs(code: '''
  ///   __qb_bindEvent(42, "tap", function(event) {
  ///     return { id: 1, type: "view", ... }; // re-render
  ///   });
  /// ''');
  /// ```
  static Future<String> evalVnodeJs({required String code}) =>
      vnode_api.evalVnodeJs(code: code);

  /// 销毁 VNode API 引擎。
  static Future<void> destroyVnodeEngine() =>
      vnode_api.destroyVnodeEngine();

  // ---------------------------------------------------------------------------
  // Component API — Phase 1 (响应式组件)
  // ---------------------------------------------------------------------------

  /// 创建组件实例。
  ///
  /// `jsCode` 中必须调用 `__qb_createComponent({...})`。
  /// 返回 JSON: `{ "id": componentId, "vnode": {...} }`
  static Future<String> createComponent({required String jsCode}) =>
      component_api.createComponent(jsCode: jsCode);

  /// 获取组件当前 VNode JSON。
  static Future<String> getComponentVnode({required int componentId}) =>
      component_api.getComponentVnode(componentId: componentId);

  /// 调用组件方法，返回更新后的 VNode JSON。
  ///
  /// 方法可能修改 state → 自动 re-render → 返回新 VNode。
  static Future<String> callComponentMethod({
    required int componentId,
    required String method,
    String argsJson = '[]',
  }) =>
      component_api.callComponentMethod(
        componentId: componentId,
        method: method,
        argsJson: argsJson,
      );

  /// 在组件引擎中执行 JS 代码（调试用）。
  static Future<String> evalComponentJs({required String code}) =>
      component_api.evalComponentJs(code: code);

  /// 销毁指定组件实例。
  static Future<void> destroyComponent({required int componentId}) =>
      component_api.destroyComponent(componentId: componentId);

  /// 销毁组件引擎。
  static Future<void> destroyComponentEngine() =>
      component_api.destroyComponentEngine();

  // ---------------------------------------------------------------------------
  // Compiler API — Phase 2 (Vue 模板编译器)
  // ---------------------------------------------------------------------------

  /// 编译 Vue 模板为 JS render 函数代码。
  static Future<String> compileTemplate({required String template}) =>
      compiler_api.compileTemplate(template: template);

  /// 编译模板 + script，生成完整组件创建 JS 代码。
  ///
  /// 返回的 JS 代码可直接传给 `evalComponentJs` 执行。
  static Future<String> compileAndCreateComponent({
    required String template,
    required String script,
  }) =>
      compiler_api.compileAndCreateComponent(
        template: template,
        script: script,
      );
}
