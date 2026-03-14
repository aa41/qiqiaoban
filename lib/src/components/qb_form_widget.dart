/// form 表单容器 — 对应微信小程序 `<form>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 form 容器组件。
Widget buildFormWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  Widget content;
  if (node.children.isEmpty) {
    content = const SizedBox.shrink();
  } else {
    content = Stack(
      clipBehavior: Clip.none,
      children: node.children.map((child) {
        return Positioned(
          left: child.x,
          top: child.y,
          child: buildChild(child),
        );
      }).toList(),
    );
  }

  return Container(
    width: node.width > 0 ? node.width : null,
    height: node.height > 0 ? node.height : null,
    decoration: buildDecoration(node),
    child: content,
  );
}
