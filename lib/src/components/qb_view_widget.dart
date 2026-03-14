/// view 容器组件 — 通用容器，对应微信小程序 `<view>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 view 组件。
///
/// 子节点通过 `Stack + Positioned` 定位，坐标由 Rust Taffy 布局引擎计算。
Widget buildViewWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  Widget content;
  if (node.children.isEmpty) {
    content = const SizedBox.shrink();
  } else {
    // 子节点使用布局引擎计算的 x/y 坐标进行绝对定位
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

  Widget result = Container(
    width: node.width,
    height: node.height,
    decoration: buildDecoration(node),
    clipBehavior: node.borderRadius != null ? Clip.antiAlias : Clip.none,
    child: content,
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
      onLongPress: hasEvent(node, 'longpress') || hasEvent(node, 'bindlongpress')
          ? () => onEvent(node.id, 'longpress')
          : null,
      child: result,
    );
  }

  return result;
}
