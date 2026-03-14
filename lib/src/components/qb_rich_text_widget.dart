/// rich-text 富文本组件 — 对应微信小程序 `<rich-text>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 rich-text 组件。
Widget buildRichTextWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
) {
  // 如果有子节点，使用 Stack+Positioned 布局
  if (node.children.isNotEmpty) {
    return SizedBox(
      width: node.width > 0 ? node.width : null,
      height: node.height > 0 ? node.height : null,
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

  // 尝试从 extraProps 中解析 nodes JSON
  final nodesJson = node.getExtraProp('nodes');
  if (nodesJson != null) {
    try {
      final decoded = jsonDecode(nodesJson);
      if (decoded is List) {
        final spans = decoded.map((item) => _buildSpan(item)).toList();
        return SizedBox(
          width: node.width > 0 ? node.width : null,
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black),
              children: spans,
            ),
          ),
        );
      }
    } catch (_) {
      // 降级为纯文本
    }
  }

  // 降级: 显示 text
  return Text(node.text ?? '', style: buildTextStyle(node));
}

/// 递归构建 TextSpan。
InlineSpan _buildSpan(dynamic item) {
  if (item is Map) {
    final text = item['text'] as String?;

    TextStyle style = const TextStyle();
    if (item['attrs'] is Map) {
      final attrs = item['attrs'] as Map;
      if (attrs['style'] is String) {
        style = _parseInlineStyle(attrs['style'] as String);
      }
    }

    final childSpans = (item['children'] as List?)
        ?.map((child) => _buildSpan(child))
        .toList();

    return TextSpan(
      text: text,
      style: style,
      children: childSpans,
    );
  }
  if (item is String) {
    return TextSpan(text: item);
  }
  return const TextSpan();
}

/// 简单的内联样式解析。
TextStyle _parseInlineStyle(String css) {
  final styles = <String, String>{};
  for (final part in css.split(';')) {
    final kv = part.split(':');
    if (kv.length == 2) {
      styles[kv[0].trim()] = kv[1].trim();
    }
  }

  return TextStyle(
    color: parseColor(styles['color']),
    fontSize: double.tryParse(styles['font-size']?.replaceAll('px', '') ?? ''),
    fontWeight: styles['font-weight'] == 'bold' ? FontWeight.bold : null,
    fontStyle: styles['font-style'] == 'italic' ? FontStyle.italic : null,
    decoration: styles['text-decoration'] == 'underline'
        ? TextDecoration.underline
        : styles['text-decoration'] == 'line-through'
            ? TextDecoration.lineThrough
            : null,
  );
}
