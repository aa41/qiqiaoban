/// input 输入框组件 — 对应微信小程序 `<input>`。
///
/// 属性:
/// - value: 输入框初始值
/// - type: 输入类型 (text/number/idcard/digit/password)
/// - placeholder: 占位文字
/// - placeholder-style: 占位文字样式
/// - disabled: 是否禁用
/// - maxlength: 最大输入长度 (默认 140, -1 不限制)
/// - focus: 是否自动获取焦点
/// - confirm-type: 键盘右下角按钮文字 (send/search/next/go/done)
/// - cursor-color: 光标颜色
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 input 组件。
Widget buildInputWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return _InputWidget(node: node, onEvent: onEvent);
}

class _InputWidget extends StatefulWidget {
  final RenderNode node;
  final void Function(String nodeId, String eventName)? onEvent;

  const _InputWidget({required this.node, this.onEvent});

  @override
  State<_InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<_InputWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.node.getExtraProp('value') ?? '';
    _controller = TextEditingController(text: initialValue);
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
    final type = node.getExtraProp('_type') ?? node.getExtraProp('type') ?? 'text';
    final placeholder = node.getExtraProp('placeholder') ?? '';
    final disabled = node.getExtraPropBool('disabled');
    final maxLength = node.getExtraPropInt('maxlength') ?? 140;
    final cursorColor = parseColor(node.getExtraProp('cursor-color') ??
        node.getExtraProp('cursorColor'));
    final confirmType = node.getExtraProp('confirm-type') ??
        node.getExtraProp('confirmType') ?? 'done';

    TextInputType keyboardType;
    bool obscure = false;
    List<TextInputFormatter>? formatters;

    switch (type) {
      case 'number':
        keyboardType = TextInputType.number;
        formatters = [FilteringTextInputFormatter.digitsOnly];
        break;
      case 'digit':
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
        break;
      case 'idcard':
        keyboardType = TextInputType.text;
        break;
      case 'password':
        keyboardType = TextInputType.visiblePassword;
        obscure = true;
        break;
      default:
        keyboardType = TextInputType.text;
    }

    TextInputAction action;
    switch (confirmType) {
      case 'send':   action = TextInputAction.send; break;
      case 'search': action = TextInputAction.search; break;
      case 'next':   action = TextInputAction.next; break;
      case 'go':     action = TextInputAction.go; break;
      default:       action = TextInputAction.done;
    }

    return SizedBox(
      width: node.width > 0 ? node.width : null,
      height: node.height > 0 ? node.height : null,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: !disabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: action,
        maxLength: maxLength > 0 ? maxLength : null,
        cursorColor: cursorColor,
        inputFormatters: formatters,
        style: buildTextStyle(node),
        decoration: InputDecoration(
          hintText: placeholder,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          counterText: '',
          isDense: true,
        ),
        onChanged: (_) => widget.onEvent?.call(node.id, 'input'),
        onSubmitted: (_) => widget.onEvent?.call(node.id, 'confirm'),
      ),
    );
  }
}
