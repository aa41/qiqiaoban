import 'dart:convert';

import 'package:flutter/material.dart';

import 'qb_engine.dart';
import 'qb_widget_factory.dart';
import 'rust/api/poc_render.dart';
import 'rust/api/vnode_api.dart' as vnode_api;

/// 七巧板组件 Widget — Vue 模板 → Flutter UI 的端到端封装。
///
/// 接收 Vue 模板和 script 选项，自动执行:
/// 1. 编译模板 → JS render 函数
/// 2. 创建响应式组件实例
/// 3. 渲染 VNode 树为 Flutter Widget
/// 4. 事件自动分发 → 调用组件方法 → 自动 re-render
///
/// ```dart
/// QBComponentWidget(
///   template: '<view @tap="increment"><text>Count: {{ count }}</text></view>',
///   script: '''
///     {
///       data: function() { return { count: 0 }; },
///       methods: {
///         increment: function() { this.count++; }
///       }
///     }
///   ''',
/// )
/// ```
class QBComponentWidget extends StatefulWidget {
  const QBComponentWidget({
    super.key,
    required this.template,
    required this.script,
    this.width,
    this.height,
    this.placeholder,
    this.onError,
    this.onCreated,
  });

  /// Vue 模板字符串。
  final String template;

  /// 组件选项 JS 对象字面量 (data, methods, computed, watch)。
  final String script;

  /// 组件渲染区域宽度 (默认取父容器宽度)。
  final double? width;

  /// 组件渲染区域高度 (默认取父容器高度)。
  final double? height;

  /// 加载中 / 编译中的占位 Widget。
  final Widget? placeholder;

  /// 错误回调。
  final void Function(String error)? onError;

  /// 组件实例创建成功后的回调，返回 componentId。
  final void Function(int componentId)? onCreated;

  @override
  State<QBComponentWidget> createState() => QBComponentWidgetState();
}

/// QBComponentWidget 的状态类。
///
/// 可通过 GlobalKey 获取引用，手动调用 `callMethod` 等方法。
class QBComponentWidgetState extends State<QBComponentWidget> {
  int? _componentId;
  List<RenderNode>? _renderNodes;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initComponent();
  }

  @override
  void didUpdateWidget(covariant QBComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 template 或 script 变更，重新编译组件
    if (oldWidget.template != widget.template ||
        oldWidget.script != widget.script) {
      _destroyAndReinit();
    }
  }

  @override
  void dispose() {
    _destroyComponent();
    super.dispose();
  }

  /// 手动调用组件方法。
  ///
  /// 方法执行后自动触发 re-render。
  Future<void> callMethod(String method, [String argsJson = '[]']) async {
    if (_componentId == null) return;
    try {
      final newVnodeJson = await Qiqiaoban.callComponentMethod(
        componentId: _componentId!,
        method: method,
        argsJson: argsJson,
      );
      await _updateRenderNodes(newVnodeJson);
    } catch (e) {
      _setError('callMethod($method) failed: $e');
    }
  }

  /// 获取组件当前 state (JSON 格式，调试用)。
  Future<String?> getState() async {
    if (_componentId == null) return null;
    try {
      return await Qiqiaoban.evalComponentJs(
        code: 'JSON.stringify(__qb_components[${_componentId!}].__data)',
      );
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  Future<void> _initComponent() async {
    try {
      // 1. 编译模板 + 创建组件
      final js = await Qiqiaoban.compileAndCreateComponent(
        template: widget.template,
        script: widget.script,
      );

      // 2. 在组件引擎中执行创建代码
      final resultJson = await Qiqiaoban.evalComponentJs(code: js);
      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      _componentId = result['id'] as int;

      widget.onCreated?.call(_componentId!);

      // 3. VNode 已包含在创建结果中 — 无需再次调用 getComponentVnode
      //    这避免了第二次 JSON.stringify 导致的 QuickJS 栈溢出
      final vnodeData = result['vnode'];
      if (vnodeData == null) {
        _setError('Component created but no VNode in result');
        return;
      }
      final vnodeJson = jsonEncode(vnodeData);

      // 4. 渲染为 RenderNode 列表
      await _updateRenderNodes(vnodeJson);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, s) {
      debugPrint('[qb:component] Init error: $e\n$s');
      _setError('Component init failed: $e');
    }
  }

  Future<void> _updateRenderNodes(String vnodeJson) async {
    // 使用 LayoutBuilder 的尺寸或指定尺寸
    final w = widget.width ?? 300;
    final h = widget.height ?? 600;

    final nodes = await vnode_api.renderVnodeFromJson(
      vnodeJson: vnodeJson,
      viewportWidth: w,
      viewportHeight: h,
    );

    if (mounted) {
      setState(() {
        _renderNodes = nodes;
        _error = null;
      });
    }
  }

  void _handleEvent(
    String nodeId,
    String eventType,
    Map<String, dynamic>? data,
  ) {
    if (_componentId == null) return;

    // 使用组件引擎分发事件 — 调用组件方法
    // 事件名映射: tap → onTap, longPress → onLongPress, 等
    // 组件运行时自动将 VNode events 绑定到 methods
    _dispatchComponentEvent(nodeId, eventType);
  }

  Future<void> _dispatchComponentEvent(String nodeId, String eventType) async {
    if (_componentId == null) return;
    try {
      // 1. 查找事件绑定的方法名
      final lookupCode = '''
        (function() {
          var comp = __qb_components[${_componentId!}];
          if (comp && comp.__eventBindings) {
            var binding = comp.__eventBindings["${nodeId}_$eventType"];
            if (binding) return binding;
          }
          return "";
        })()
      ''';

      final methodName = await Qiqiaoban.evalComponentJs(code: lookupCode);
      if (methodName.isEmpty) return;

      // 2. 通过 Rust API 调用方法（Rust 侧处理 JSON.stringify）
      final vnodeJson = await Qiqiaoban.callComponentMethod(
        componentId: _componentId!,
        method: methodName,
        argsJson: '[]',
      );

      // 3. 更新渲染
      if (vnodeJson.isNotEmpty && vnodeJson != 'null') {
        await _updateRenderNodes(vnodeJson);
      }
    } catch (e) {
      debugPrint('[qb:component] Event dispatch error: $e');
    }
  }

  void _setError(String error) {
    widget.onError?.call(error);
    if (mounted) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _destroyAndReinit() {
    _destroyComponent();
    setState(() {
      _isLoading = true;
      _renderNodes = null;
      _error = null;
    });
    _initComponent();
  }

  void _destroyComponent() {
    if (_componentId != null) {
      Qiqiaoban.destroyComponent(componentId: _componentId!);
      _componentId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_isLoading || _renderNodes == null) {
      return widget.placeholder ??
          const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: widget.width ?? constraints.maxWidth,
          height: widget.height ?? constraints.maxHeight,
          child: QBWidgetFactory.buildTreeFromList(
            _renderNodes!,
            onEvent: _handleEvent,
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '七巧板组件错误',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
