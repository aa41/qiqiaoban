import 'package:flutter/material.dart';

import 'rust/api/poc_render.dart';

/// 事件回调类型 — Widget 触发事件时调用。
typedef QBEventCallback =
    void Function(String nodeId, String eventType, Map<String, dynamic>? data);

/// 七巧板 Widget 工厂 — RenderNode 树 → Flutter Widget 树。
///
/// 递归遍历 RenderNode 树，根据 node_type 映射到 Flutter Widget:
/// - `view`        → 固定尺寸容器 (Stack + Positioned)
/// - `scroll-view` → SingleChildScrollView 可滚动容器
/// - `text`        → Text Widget (叶子节点)
/// - `image`       → Image Widget (占位)
/// - `button`      → ElevatedButton (占位)
/// - `input`       → TextField (占位)
///
/// 参考微信小程序 DSL: scroll-view 是声明式容器节点，
/// 滚动行为在 DSL 层面定义，而非渲染层 hack。
class QBWidgetFactory {
  QBWidgetFactory._();

  /// 自定义 Widget 构建器注册表。
  static final Map<String, Widget Function(RenderNode)> _customBuilders = {};

  /// 注册一个自定义 Widget 构建器。
  static void register(String type, Widget Function(RenderNode) builder) {
    _customBuilders[type] = builder;
  }

  /// 取消注册。
  static void unregister(String type) {
    _customBuilders.remove(type);
  }

  /// 从 RenderNode 树构建 Flutter Widget 树。
  ///
  /// 入口：传入根 RenderNode，递归构建完整 Widget。
  static Widget buildTree(RenderNode root, {QBEventCallback? onEvent}) {
    return _buildWidget(root, onEvent);
  }

  /// 兼容旧 API — 从扁平 RenderNode 列表构建 Widget。
  ///
  /// 用于 VNode 系统 (vnode_api) 等仍返回 List<RenderNode> 的场景。
  /// 内部使用 Stack + Positioned 绝对定位。
  static Widget buildTreeFromList(
    List<RenderNode> nodes, {
    QBEventCallback? onEvent,
  }) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    final root = nodes.first;
    return SizedBox(
      width: root.width,
      height: root.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: nodes.map((n) {
          Widget child = switch (n.nodeType) {
            'text' => _buildText(n),
            'image' => _buildImage(n),
            'button' => _buildButton(n),
            'input' => _buildInput(n),
            _ => _buildView(n, onEvent),
          };
          child = _maybeWrapGestures(child, n, onEvent);
          return Positioned(left: n.x, top: n.y, child: child);
        }).toList(),
      ),
    );
  }

  /// 递归构建单个节点 → Widget。
  static Widget _buildWidget(RenderNode node, QBEventCallback? onEvent) {
    // 优先使用自定义构建器
    final customBuilder = _customBuilders[node.nodeType];
    if (customBuilder != null) {
      return _wrapSize(
        node,
        _maybeWrapGestures(customBuilder(node), node, onEvent),
      );
    }

    Widget child = switch (node.nodeType) {
      'text' => _buildText(node),
      'scroll-view' => _buildScrollView(node, onEvent),
      'image' => _buildImage(node),
      'button' => _buildButton(node),
      'input' => _buildInput(node),
      _ => _buildView(node, onEvent), // "view" 及其他
    };

    return _maybeWrapGestures(child, node, onEvent);
  }

  // ─────────────────────────────────────────────────────────
  // view — 固定尺寸容器，子节点使用 Stack + Positioned (相对坐标)
  // ─────────────────────────────────────────────────────────
  static Widget _buildView(RenderNode node, QBEventCallback? onEvent) {
    if (node.children.isEmpty) {
      // 叶子 view (纯色块)
      return Container(
        width: node.width,
        height: node.height,
        decoration: BoxDecoration(color: _parseColor(node.color)),
      );
    }

    // 有子节点 → Stack + Positioned
    return Container(
      width: node.width,
      height: node.height,
      decoration: BoxDecoration(color: _parseColor(node.color)),
      child: Stack(
        clipBehavior: Clip.none,
        children: node.children.map((child) {
          return Positioned(
            left: child.x,
            top: child.y,
            child: _buildWidget(child, onEvent),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // scroll-view — 可滚动容器 (类似微信小程序 <scroll-view>)
  // ─────────────────────────────────────────────────────────
  static Widget _buildScrollView(RenderNode node, QBEventCallback? onEvent) {
    // 计算子节点内容总尺寸
    double contentWidth = 0;
    double contentHeight = 0;
    for (final child in node.children) {
      final right = child.x + child.width;
      final bottom = child.y + child.height;
      if (right > contentWidth) contentWidth = right;
      if (bottom > contentHeight) contentHeight = bottom;
    }

    final innerStack = SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: node.children.map((child) {
          return Positioned(
            left: child.x,
            top: child.y,
            child: _buildWidget(child, onEvent),
          );
        }).toList(),
      ),
    );

    return Container(
      width: node.width,
      height: node.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: _parseColor(node.color)),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: innerStack,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // text — 叶子文本节点
  // ─────────────────────────────────────────────────────────
  static Widget _buildText(RenderNode node) {
    return SizedBox(
      width: node.width,
      height: node.height,
      child: Align(
        alignment: Alignment.center,
        child: Text(
          node.text ?? '',
          style: TextStyle(
            fontSize: node.fontSize ?? 14,
            color: _parseColor(node.textColor) ?? Colors.black,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: node.fontSize != null
              ? (node.height / (node.fontSize! * 1.4)).floor().clamp(1, 99)
              : 1,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // image — 图片占位
  // ─────────────────────────────────────────────────────────
  static Widget _buildImage(RenderNode node) {
    return Container(
      width: node.width,
      height: node.height,
      decoration: BoxDecoration(
        color: _parseColor(node.color) ?? Colors.grey.shade200,
      ),
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey, size: 32),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // button — 按钮占位
  // ─────────────────────────────────────────────────────────
  static Widget _buildButton(RenderNode node) {
    return SizedBox(
      width: node.width,
      height: node.height,
      child: ElevatedButton(
        onPressed: () {},
        child: Text(
          node.text ?? 'Button',
          style: TextStyle(
            fontSize: node.fontSize ?? 14,
            color: _parseColor(node.textColor),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // input — 输入框占位
  // ─────────────────────────────────────────────────────────
  static Widget _buildInput(RenderNode node) {
    return SizedBox(
      width: node.width,
      height: node.height,
      child: TextField(
        decoration: InputDecoration(
          hintText: node.text ?? '',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
        ),
        style: TextStyle(fontSize: node.fontSize ?? 14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 辅助方法
  // ─────────────────────────────────────────────────────────

  static Widget _wrapSize(RenderNode node, Widget child) {
    return SizedBox(width: node.width, height: node.height, child: child);
  }

  static Widget _maybeWrapGestures(
    Widget child,
    RenderNode node,
    QBEventCallback? onEvent,
  ) {
    if (onEvent == null || node.events.isEmpty) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: node.events.contains('tap')
          ? () => onEvent(node.id, 'tap', null)
          : null,
      onDoubleTap: node.events.contains('doubleTap')
          ? () => onEvent(node.id, 'doubleTap', null)
          : null,
      onLongPress: node.events.contains('longPress')
          ? () => onEvent(node.id, 'longPress', null)
          : null,
      child: child,
    );
  }

  /// 解析 #RRGGBB / #RGB / #AARRGGBB 颜色字符串。
  static Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    if (colorStr == 'transparent') return Colors.transparent;
    String hex = colorStr.replaceFirst('#', '');
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }
}
