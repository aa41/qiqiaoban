/// list-view / list-builder / grid-view / grid-builder / draggable-sheet 组件。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 list-view 组件。
Widget buildListViewWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  // 计算内容尺寸
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
          child: buildChild(child),
        );
      }).toList(),
    ),
  );

  return Container(
    width: node.width > 0 ? node.width : null,
    height: node.height > 0 ? node.height : null,
    decoration: buildDecoration(node),
    clipBehavior: Clip.hardEdge,
    child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      child: innerStack,
    ),
  );
}

/// 构建 list-builder 组件（同 list-view）。
Widget buildListBuilderWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return buildListViewWidget(node, buildChild, onEvent);
}

/// 构建 grid-view 组件。
Widget buildGridViewWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  // 使用 Stack+Positioned 进行布局 (坐标由 Rust 布局引擎计算)
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
          child: buildChild(child),
        );
      }).toList(),
    ),
  );

  return Container(
    width: node.width > 0 ? node.width : null,
    height: node.height > 0 ? node.height : null,
    decoration: buildDecoration(node),
    clipBehavior: Clip.hardEdge,
    child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      child: innerStack,
    ),
  );
}

/// 构建 grid-builder 组件（同 grid-view）。
Widget buildGridBuilderWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return buildGridViewWidget(node, buildChild, onEvent);
}

/// 构建 draggable-sheet 组件。
Widget buildDraggableSheetWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final initialSize = node.getExtraPropDouble('initial-child-size') ??
      node.getExtraPropDouble('initialChildSize') ?? 0.5;
  final minSize = node.getExtraPropDouble('min-child-size') ??
      node.getExtraPropDouble('minChildSize') ?? 0.25;
  final maxSize = node.getExtraPropDouble('max-child-size') ??
      node.getExtraPropDouble('maxChildSize') ?? 1.0;

  // 计算内容尺寸
  double contentHeight = 0;
  for (final child in node.children) {
    final bottom = child.y + child.height;
    if (bottom > contentHeight) contentHeight = bottom;
  }

  return SizedBox(
    width: node.width > 0 ? node.width : null,
    height: node.height > 0 ? node.height : 300,
    child: DraggableScrollableSheet(
      initialChildSize: initialSize.clamp(0.0, 1.0),
      minChildSize: minSize.clamp(0.0, 1.0),
      maxChildSize: maxSize.clamp(0.0, 1.0),
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: parseColor(node.color) ?? Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(node.borderRadius ?? 12),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
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
            ),
          ),
        );
      },
    ),
  );
}
