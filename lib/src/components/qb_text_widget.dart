/// text 文本组件 — 对应微信小程序 `<text>`。
///
/// 支持属性:
/// - textAlign: 文本对齐 (left/center/right/justify), 默认 left
/// - overflow/textOverflow: 溢出处理 (ellipsis/clip/fade/visible)
/// - max-lines/maxLines: 最大行数 (显式设置)
/// - user-select/selectable: 是否可选择
///
/// 多行文本: 当没有显式设置 maxLines 时，文本在 SizedBox 内自由换行。
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 text 组件。
Widget buildTextWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final content = node.text ?? '';
  final userSelect = node.getExtraPropBool('user-select') || node.getExtraPropBool('selectable');
  final style = buildTextStyle(node);

  // ---- textAlign ----
  final textAlignStr = node.getExtraProp('textAlign');
  final justifyContent = node.getExtraProp('justifyContent');
  TextAlign textAlign;
  if (textAlignStr != null) {
    textAlign = parseTextAlign(textAlignStr);
  } else if (justifyContent == 'center') {
    textAlign = TextAlign.center;
  } else if (justifyContent == 'flex-end') {
    textAlign = TextAlign.right;
  } else {
    textAlign = TextAlign.left;
  }

  // ---- overflow ----
  final overflowStr = node.getExtraProp('overflow') ??
      node.getExtraProp('textOverflow');
  TextOverflow textOverflow;
  switch (overflowStr) {
    case 'clip':
      textOverflow = TextOverflow.clip;
    case 'fade':
      textOverflow = TextOverflow.fade;
    case 'visible':
      textOverflow = TextOverflow.visible;
    case 'ellipsis':
      textOverflow = TextOverflow.ellipsis;
    default:
      textOverflow = TextOverflow.clip;
  }

  // ---- maxLines ----
  // 只使用显式设置的 maxLines，不自动从 height/fontSize 计算。
  int? maxLines = node.getExtraPropInt('max-lines') ??
      node.getExtraPropInt('maxLines') ??
      node.getExtraPropInt('lineClamp');

  // 如果设置了 maxLines，使用 ellipsis 显示截断
  if (maxLines != null && overflowStr == null) {
    textOverflow = TextOverflow.ellipsis;
  }

  Widget textWidget;
  if (userSelect) {
    textWidget = SelectableText(
      content,
      style: style,
      maxLines: maxLines,
      textAlign: textAlign,
    );
  } else {
    textWidget = Text(
      content,
      style: style,
      overflow: textOverflow,
      maxLines: maxLines,
      textAlign: textAlign,
      softWrap: true,
    );
  }

  // 使用 ConstrainedBox 来约束宽度 (用于换行), 但不限制高度 (允许多行展开)。
  // 如果有 maxLines，则使用 SizedBox 固定高度来裁剪。
  Widget result;
  if (maxLines != null && node.height > 0) {
    // 有 maxLines 时固定高度裁剪
    result = SizedBox(
      width: node.width > 0 ? node.width : null,
      height: node.height,
      child: textWidget,
    );
  } else {
    // 无 maxLines 时只约束宽度，高度自适应
    result = SizedBox(
      width: node.width > 0 ? node.width : null,
      child: textWidget,
    );
  }

  // 事件绑定
  if (onEvent != null && node.events.isNotEmpty) {
    result = GestureDetector(
      onTap: hasEvent(node, 'tap') || hasEvent(node, 'bindtap')
          ? () => onEvent(node.id, 'tap')
          : null,
      child: result,
    );
  }

  return result;
}
