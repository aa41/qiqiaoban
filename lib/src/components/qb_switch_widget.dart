/// switch 开关组件 — 对应微信小程序 `<switch>`。
///
/// 属性:
/// - checked: 是否选中
/// - disabled: 是否禁用
/// - type: 样式 (switch/checkbox)
/// - color: 选中时颜色
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 switch 组件。
Widget buildSwitchWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return _SwitchWidget(node: node, onEvent: onEvent);
}

class _SwitchWidget extends StatefulWidget {
  final RenderNode node;
  final void Function(String nodeId, String eventName)? onEvent;

  const _SwitchWidget({required this.node, this.onEvent});

  @override
  State<_SwitchWidget> createState() => _SwitchWidgetState();
}

class _SwitchWidgetState extends State<_SwitchWidget> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.node.getExtraPropBool('checked');
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final disabled = node.getExtraPropBool('disabled');
    final type = node.getExtraProp('_type') ?? node.getExtraProp('type') ?? 'switch';
    final color = parseColor(node.getExtraProp('color')) ?? const Color(0xFF04BE02);

    if (type == 'checkbox') {
      return SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: _checked,
          activeColor: color,
          onChanged: disabled
              ? null
              : (val) {
                  setState(() => _checked = val ?? false);
                  widget.onEvent?.call(node.id, 'change');
                },
        ),
      );
    }

    return Switch(
      value: _checked,
      activeColor: color,
      onChanged: disabled
          ? null
          : (val) {
              setState(() => _checked = val);
              widget.onEvent?.call(node.id, 'change');
            },
    );
  }
}
