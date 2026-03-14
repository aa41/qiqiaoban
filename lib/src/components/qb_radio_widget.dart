/// radio / radio-group 组件 — 对应微信小程序 `<radio>` 和 `<radio-group>`。
///
/// radio 属性: value, checked, disabled, color
/// radio-group 属性: bindchange
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 radio 组件。
///
/// 标签文本来源优先级:
/// 1. node.text (直接文本)
/// 2. node.getExtraProp('value') (使用 value 作为标签)
Widget buildRadioWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  final checked = node.getExtraPropBool('checked');
  final disabled = node.getExtraPropBool('disabled');
  final color = parseColor(node.getExtraProp('color')) ?? const Color(0xFF09BB07);
  // 标签: 优先用 text，其次用 value
  final label = node.text ?? node.getExtraProp('value') ?? '';

  return _RadioWidget(
    checked: checked,
    disabled: disabled,
    color: color,
    label: label,
    node: node,
    onEvent: onEvent,
  );
}

class _RadioWidget extends StatefulWidget {
  final bool checked;
  final bool disabled;
  final Color color;
  final String label;
  final RenderNode node;
  final void Function(String nodeId, String eventName)? onEvent;

  const _RadioWidget({
    required this.checked,
    required this.disabled,
    required this.color,
    required this.label,
    required this.node,
    this.onEvent,
  });

  @override
  State<_RadioWidget> createState() => _RadioWidgetState();
}

class _RadioWidgetState extends State<_RadioWidget> {
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
              setState(() => _checked = true);
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
              child: Radio<bool>(
                value: true,
                groupValue: _checked ? true : null,
                activeColor: widget.color,
                onChanged: widget.disabled
                    ? null
                    : (_) {
                        setState(() => _checked = true);
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

/// 构建 radio-group 容器。
Widget buildRadioGroupWidget(
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
