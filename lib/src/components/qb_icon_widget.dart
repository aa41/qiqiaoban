/// icon 图标组件 — 对应微信小程序 `<icon>`。
///
/// 属性:
/// - type: 图标类型 (success/success_no_circle/info/warn/waiting/cancel/download/search/clear)
/// - size: 图标大小 (默认 23)
/// - color: 图标颜色
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 微信图标类型到 Material Icons 映射。
const _iconMap = <String, IconData>{
  'success': Icons.check_circle,
  'success_no_circle': Icons.check,
  'info': Icons.info,
  'warn': Icons.warning,
  'waiting': Icons.hourglass_empty,
  'cancel': Icons.cancel,
  'download': Icons.download,
  'search': Icons.search,
  'clear': Icons.clear,
  'back': Icons.arrow_back,
  'delete': Icons.delete,
  'edit': Icons.edit,
  'close': Icons.close,
  'add': Icons.add,
  'star': Icons.star,
  'heart': Icons.favorite,
};

const _iconColorMap = <String, Color>{
  'success': Color(0xFF09BB07),
  'info': Color(0xFF10AEFF),
  'warn': Color(0xFFFFBE00),
  'cancel': Color(0xFFF43530),
  'waiting': Color(0xFF10AEFF),
};

/// 构建 icon 组件。
Widget buildIconWidget(RenderNode node) {
  final type = node.getExtraProp('_type') ?? node.getExtraProp('type') ?? 'info';
  final size = node.getExtraPropDouble('size') ?? 23;
  final color = parseColor(node.getExtraProp('color')) ?? _iconColorMap[type] ?? Colors.black;
  final iconData = _iconMap[type] ?? Icons.help_outline;

  return Icon(iconData, size: size, color: color);
}
