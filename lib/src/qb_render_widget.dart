import 'package:flutter/material.dart';

import 'qb_widget_factory.dart';
import 'rust/api/poc_render.dart';

/// 七巧板渲染组件 — 将 RenderNode 树渲染为 Flutter Widget 树。
///
/// 委托 [QBWidgetFactory.buildTree] 递归构建 Widget。
/// 节点类型 `scroll-view` 自动映射为可滚动容器。
///
/// ```dart
/// QBRenderWidget(root: renderRoot)
/// ```
class QBRenderWidget extends StatelessWidget {
  const QBRenderWidget({
    super.key,
    required this.root,
    this.onEvent,
  });

  /// Rust 计算后返回的渲染树根节点。
  final RenderNode root;

  /// 事件回调 (tap / doubleTap / longPress)。
  final QBEventCallback? onEvent;

  @override
  Widget build(BuildContext context) {
    return QBWidgetFactory.buildTree(root, onEvent: onEvent);
  }
}
