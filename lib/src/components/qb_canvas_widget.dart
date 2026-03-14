/// canvas 画布组件 — 对应微信小程序 `<canvas>`。
///
/// 属性:
/// - type: 2d / webgl
/// - canvas-id: 画布标识
///
/// 注: Canvas 完整功能需要后续通过 JS→Dart 通道实现绘制命令。
/// 当前实现为占位容器。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 canvas 组件 (占位)。
Widget buildCanvasWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final canvasType = node.getExtraProp('type') ?? '2d';
  final canvasId = node.getExtraProp('canvas-id') ??
      node.getExtraProp('canvasId') ?? node.id;

  return Container(
    width: node.width > 0 ? node.width : 300,
    height: node.height > 0 ? node.height : 150,
    decoration: BoxDecoration(
      color: parseColor(node.color) ?? Colors.transparent,
      borderRadius: node.borderRadius != null
          ? BorderRadius.circular(node.borderRadius!)
          : null,
    ),
    child: CustomPaint(
      painter: _CanvasPlaceholderPainter(),
      child: Center(
        child: Text(
          'Canvas ($canvasType)\n#$canvasId',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}

class _CanvasPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制占位网格
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;

    const step = 20.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
