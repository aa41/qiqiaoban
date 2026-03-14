/// scroll-view 可滚动视图 — 对应微信小程序 `<scroll-view>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
/// 内容超出容器时可滚动。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 scroll-view 组件。
Widget buildScrollViewWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final scrollX = node.getExtraPropBool('scroll-x') || node.getExtraPropBool('scrollX');

  // 计算子节点内容总尺寸 (根据布局引擎的 x/y + width/height)
  double contentWidth = 0;
  double contentHeight = 0;
  for (final child in node.children) {
    final right = child.x + child.width;
    final bottom = child.y + child.height;
    if (right > contentWidth) contentWidth = right;
    if (bottom > contentHeight) contentHeight = bottom;
  }

  // 子节点使用布局引擎计算的 x/y 坐标进行绝对定位
  final innerStack = SizedBox(
    width: contentWidth,
    height: contentHeight,
    child: Stack(
      clipBehavior: Clip.none,
      children: node.children.map((child) {
        return Positioned(
          left: child.x,
          top: child.y,
          child: buildChild(child),
        );
      }).toList(),
    ),
  );

  Widget result = Container(
    width: node.width,
    height: node.height,
    clipBehavior: Clip.hardEdge,
    decoration: buildDecoration(node),
    child: SingleChildScrollView(
      scrollDirection: scrollX ? Axis.horizontal : Axis.vertical,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: innerStack,
    ),
  );

  // 不透明度
  if (node.opacity != null && node.opacity! < 1.0) {
    result = Opacity(opacity: node.opacity!, child: result);
  }

  // 事件绑定
  if (onEvent != null && node.events.isNotEmpty) {
    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasEvent(node, 'tap') || hasEvent(node, 'bindtap')
          ? () => onEvent(node.id, 'tap')
          : null,
      child: result,
    );
  }

  return result;
}
