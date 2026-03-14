/// navigator 导航组件 — 对应微信小程序 `<navigator>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 navigator 组件。
Widget buildNavigatorWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  Widget content;
  if (node.children.isEmpty) {
    final url = node.getExtraProp('url');
    content = Text(
      node.text ?? url ?? '',
      style: const TextStyle(color: Color(0xFF576B95), fontSize: 14),
    );
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

  return GestureDetector(
    onTap: () => onEvent?.call(node.id, 'tap'),
    child: SizedBox(
      width: node.width > 0 ? node.width : null,
      height: node.height > 0 ? node.height : null,
      child: content,
    ),
  );
}
