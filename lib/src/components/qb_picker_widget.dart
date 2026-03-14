/// picker / picker-view 选择器组件 — 对应微信小程序 `<picker>` 和 `<picker-view>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 picker 组件 (点击弹出选择器)。
Widget buildPickerWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final disabled = node.getExtraPropBool('disabled');

  Widget content;
  if (node.children.isNotEmpty) {
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
  } else {
    content = Text(node.text ?? '请选择', style: const TextStyle(fontSize: 14));
  }

  return GestureDetector(
    onTap: disabled ? null : () => onEvent?.call(node.id, 'tap'),
    child: SizedBox(
      width: node.width > 0 ? node.width : null,
      height: node.height > 0 ? node.height : null,
      child: content,
    ),
  );
}

/// 构建 picker-view 组件 (嵌入式滚动选择器)。
Widget buildPickerViewWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  List<String> items = [];
  final rangeJson = node.getExtraProp('range');
  if (rangeJson != null) {
    try {
      final decoded = jsonDecode(rangeJson);
      if (decoded is List) {
        items = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
  }

  if (items.isEmpty && node.children.isNotEmpty) {
    return SizedBox(
      width: node.width > 0 ? node.width : null,
      height: node.height > 0 ? node.height : 200,
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
  }

  return SizedBox(
    width: node.width > 0 ? node.width : null,
    height: node.height > 0 ? node.height : 200,
    child: CupertinoPicker(
      itemExtent: 36,
      onSelectedItemChanged: (index) {
        onEvent?.call(node.id, 'change');
      },
      children: items.map((item) => Center(child: Text(item))).toList(),
    ),
  );
}
