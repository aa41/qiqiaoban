/// textarea 多行输入框 — 对应微信小程序 `<textarea>`。
///
/// 属性: value, placeholder, disabled, maxlength, auto-height, focus,
/// fixed, cursor-color, confirm-type, show-confirm-bar
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 textarea 组件。
Widget buildTextareaWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return _TextareaWidget(node: node, onEvent: onEvent);
}

class _TextareaWidget extends StatefulWidget {
  final RenderNode node;
  final void Function(String nodeId, String eventName)? onEvent;

  const _TextareaWidget({required this.node, this.onEvent});

  @override
  State<_TextareaWidget> createState() => _TextareaWidgetState();
}

class _TextareaWidgetState extends State<_TextareaWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.node.getExtraProp('value') ?? '');
    _focusNode = FocusNode();

    if (widget.node.getExtraPropBool('focus')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final placeholder = node.getExtraProp('placeholder') ?? '';
    final disabled = node.getExtraPropBool('disabled');
    final maxLength = node.getExtraPropInt('maxlength') ?? -1;
    final autoHeight = node.getExtraPropBool('auto-height') || node.getExtraPropBool('autoHeight');
    final cursorColor = parseColor(node.getExtraProp('cursor-color') ??
        node.getExtraProp('cursorColor'));

    return SizedBox(
      width: node.width > 0 ? node.width : null,
      height: autoHeight ? null : (node.height > 0 ? node.height : null),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: !disabled,
        maxLines: autoHeight ? null : 5,
        minLines: autoHeight ? 1 : null,
        maxLength: maxLength > 0 ? maxLength : null,
        cursorColor: cursorColor,
        style: buildTextStyle(node),
        decoration: InputDecoration(
          hintText: placeholder,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(node.borderRadius ?? 4),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(node.borderRadius ?? 4),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
          contentPadding: const EdgeInsets.all(12),
          counterText: '',
        ),
        onChanged: (_) => widget.onEvent?.call(node.id, 'input'),
        onSubmitted: (_) => widget.onEvent?.call(node.id, 'confirm'),
      ),
    );
  }
}
