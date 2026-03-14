/// button 按钮组件 — 对应微信小程序 `<button>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 微信按钮类型颜色。
const _buttonColors = <String, Color>{
  'primary': Color(0xFF07C160),
  'default': Color(0xFFF8F8F8),
  'warn': Color(0xFFE64340),
};

const _buttonTextColors = <String, Color>{
  'primary': Colors.white,
  'default': Color(0xFF000000),
  'warn': Colors.white,
};

/// 构建 button 组件。
Widget buildButtonWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final type =
      node.getExtraProp('_type') ?? node.getExtraProp('type') ?? 'default';
  final size = node.getExtraProp('size') ?? 'default';
  final plain = node.getExtraPropBool('plain');
  final disabled = node.getExtraPropBool('disabled');
  final loading = node.getExtraPropBool('loading');

  final bgColor = plain
      ? Colors.transparent
      : (_buttonColors[type] ?? _buttonColors['default']!);
  final textColor = plain
      ? (_buttonColors[type] ?? Colors.black)
      : (_buttonTextColors[type] ?? Colors.black);
  final borderColor = plain
      ? (_buttonColors[type] ?? Colors.grey)
      : Colors.transparent;

  final isMini = size == 'mini';

  // 按钮文本: 从 node.text 或第一个 text 子节点获取
  String content = node.text ?? '';
  if (content.isEmpty && node.children.isNotEmpty) {
    // 从子节点中提取文本
    for (final child in node.children) {
      if (child.text != null && child.text!.isNotEmpty) {
        content = child.text!;
        break;
      }
    }
  }

  Widget buttonContent = Row(
    mainAxisSize: isMini ? MainAxisSize.min : MainAxisSize.max,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (loading) ...[
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(textColor),
          ),
        ),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: disabled ? textColor.withValues(alpha: 0.6) : textColor,
            fontSize: isMini ? 13 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );

  Widget result = Container(
    width: node.width,
    height: node.height > 0 ? node.height : null,
    alignment: Alignment.center,
    padding: node.children.isEmpty
        ? EdgeInsets.symmetric(
            horizontal: isMini ? 12 : 24,
            vertical: isMini ? 4 : 8,
          )
        : null,
    decoration: BoxDecoration(
      color: disabled ? bgColor.withValues(alpha: 0.6) : bgColor,
      borderRadius: BorderRadius.circular(
        node.borderRadius ?? (isMini ? 4 : 8),
      ),
      border: Border.all(color: borderColor, width: plain ? 1 : 0),
    ),
    child: buttonContent,
  );

  if (!disabled && onEvent != null) {
    result = GestureDetector(
      onTap: () => onEvent(node.id, 'tap'),
      child: result,
    );
  }

  return result;
}
