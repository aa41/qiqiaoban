/// 通用组件属性解析工具。
///
/// 提供从 [RenderNode] 中解析颜色、尺寸、字重等通用属性的方法。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';

// ---------------------------------------------------------------------------
// 颜色解析
// ---------------------------------------------------------------------------

/// 解析颜色字符串，支持:
/// - `#RGB` / `#RRGGBB` / `#AARRGGBB`
/// - 命名颜色 (red, blue, green, black, white, grey, transparent, ...)
/// - `rgba(r,g,b,a)` 格式
Color? parseColor(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.trim().toLowerCase();

  // 命名颜色
  const named = <String, Color>{
    'transparent': Colors.transparent,
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'blue': Colors.blue,
    'green': Colors.green,
    'grey': Colors.grey,
    'gray': Colors.grey,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'cyan': Colors.cyan,
    'teal': Colors.teal,
    'amber': Colors.amber,
    'indigo': Colors.indigo,
  };
  if (named.containsKey(s)) return named[s];

  // #hex
  if (s.startsWith('#')) {
    final hex = s.substring(1);
    if (hex.length == 3) {
      final r = int.parse(hex[0] * 2, radix: 16);
      final g = int.parse(hex[1] * 2, radix: 16);
      final b = int.parse(hex[2] * 2, radix: 16);
      return Color.fromARGB(255, r, g, b);
    }
    if (hex.length == 6) {
      return Color(0xFF000000 | int.parse(hex, radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  }

  // rgba(r,g,b,a)
  final rgbaMatch = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)').firstMatch(s);
  if (rgbaMatch != null) {
    final r = int.parse(rgbaMatch.group(1)!);
    final g = int.parse(rgbaMatch.group(2)!);
    final b = int.parse(rgbaMatch.group(3)!);
    final a = rgbaMatch.group(4) != null ? double.parse(rgbaMatch.group(4)!) : 1.0;
    return Color.fromRGBO(r, g, b, a);
  }

  return null;
}

// ---------------------------------------------------------------------------
// 字重解析
// ---------------------------------------------------------------------------

/// 解析 CSS fontWeight 值。
FontWeight parseFontWeight(String? raw) {
  if (raw == null) return FontWeight.normal;
  switch (raw.trim().toLowerCase()) {
    case '100': case 'thin':         return FontWeight.w100;
    case '200': case 'extralight':   return FontWeight.w200;
    case '300': case 'light':        return FontWeight.w300;
    case '400': case 'normal':       return FontWeight.w400;
    case '500': case 'medium':       return FontWeight.w500;
    case '600': case 'semibold':     return FontWeight.w600;
    case '700': case 'bold':         return FontWeight.w700;
    case '800': case 'extrabold':    return FontWeight.w800;
    case '900': case 'black':        return FontWeight.w900;
    default:                         return FontWeight.normal;
  }
}

// ---------------------------------------------------------------------------
// TextAlign 解析
// ---------------------------------------------------------------------------

/// 解析 textAlign 值。
TextAlign parseTextAlign(String? raw) {
  if (raw == null) return TextAlign.start;
  switch (raw.trim().toLowerCase()) {
    case 'left':    return TextAlign.left;
    case 'right':   return TextAlign.right;
    case 'center':  return TextAlign.center;
    case 'justify': return TextAlign.justify;
    default:        return TextAlign.start;
  }
}

// ---------------------------------------------------------------------------
// 装饰属性提取
// ---------------------------------------------------------------------------

/// 从 [RenderNode] 构建 [BoxDecoration]。
BoxDecoration buildDecoration(RenderNode node) {
  return BoxDecoration(
    color: parseColor(node.color),
    borderRadius: node.borderRadius != null
        ? BorderRadius.circular(node.borderRadius!)
        : null,
  );
}

/// 从 [RenderNode] 构建 [TextStyle]。
TextStyle buildTextStyle(RenderNode node) {
  // fontWeight: 优先用 dedicated 字段，降级到 extra_props
  final fw = node.fontWeight ?? node.getExtraProp('fontWeight');
  final parsedWeight = parseFontWeight(fw);
  if (fw != null) {
    debugPrint('[QBText] id=${node.id} fontWeight raw="$fw" parsed=$parsedWeight');
  }
  return TextStyle(
    fontSize: node.fontSize ?? 14,
    color: parseColor(node.textColor) ?? Colors.black,
    fontWeight: parsedWeight,
    fontFamilyFallback: const ['Roboto', 'sans-serif'],
    height: node.getExtraPropDouble('lineHeight') != null
        ? (node.getExtraPropDouble('lineHeight')! / (node.fontSize ?? 14))
        : null,
  );
}

// ---------------------------------------------------------------------------
// 事件工具
// ---------------------------------------------------------------------------

/// 检查节点是否绑定了指定事件。
bool hasEvent(RenderNode node, String eventName) {
  return node.events.contains(eventName);
}
