/// checkbox / checkbox-group 组件 — 对应微信小程序 `<checkbox>` 和 `<checkbox-group>`。
///
/// checkbox 属性: value, checked, disabled, color
/// checkbox-group 属性: bindchange
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 checkbox 组件。
///
/// 标签文本来源优先级:
/// 1. node.text (直接文本)
/// 2. node.getExtraProp('value') (使用 value 作为标签)
Widget buildCheckboxWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final checked = node.getExtraPropBool('checked');
  final disabled = node.getExtraPropBool('disabled');
  final color = parseColor(node.getExtraProp('color')) ?? const Color(0xFF09BB07);
  // 标签: 优先用 text，其次用 value
  final label = node.text ?? node.getExtraProp('value') ?? '';

  return _CheckboxWidget(
    checked: checked,
    disabled: disabled,
    color: color,
    label: label,
    node: node,
    onEvent: onEvent,
  );
}

class _CheckboxWidget extends StatefulWidget {
  final bool checked;
  final bool disabled;
  final Color color;
  final String label;
  final RenderNode node;
  final void Function(String nodeId, String eventName)? onEvent;

  const _CheckboxWidget({
    required this.checked,
    required this.disabled,
    required this.color,
    required this.label,
    required this.node,
    this.onEvent,
  });

  @override
  State<_CheckboxWidget> createState() => _CheckboxWidgetState();
}

class _CheckboxWidgetState extends State<_CheckboxWidget> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.checked;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.disabled
          ? null
          : () {
              setState(() => _checked = !_checked);
              widget.onEvent?.call(widget.node.id, 'change');
            },
      child: SizedBox(
        width: widget.node.width > 0 ? widget.node.width : null,
        height: widget.node.height > 0 ? widget.node.height : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _checked,
                activeColor: widget.color,
                onChanged: widget.disabled
                    ? null
                    : (val) {
                        setState(() => _checked = val ?? false);
                        widget.onEvent?.call(widget.node.id, 'change');
                      },
              ),
            ),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.disabled ? Colors.grey : Colors.black,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 构建 checkbox-group 容器。
Widget buildCheckboxGroupWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final children = node.children.map(buildChild).toList();

  return SizedBox(
    width: node.width > 0 ? node.width : null,
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: children,
    ),
  );
}
