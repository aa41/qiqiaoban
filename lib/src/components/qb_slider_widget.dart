/// slider 滑动选择器 — 对应微信小程序 `<slider>`。
///
/// 属性:
/// - min / max / step / value
/// - disabled
/// - activeColor / backgroundColor / block-size / block-color
/// - show-value: 是否显示当前值
library;

import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 slider 组件。
Widget buildSliderWidget(
  RenderNode node,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return _SliderWidget(node: node, onEvent: onEvent);
}

class _SliderWidget extends StatefulWidget {
  final RenderNode node;
  final void Function(String nodeId, String eventName)? onEvent;

  const _SliderWidget({required this.node, this.onEvent});

  @override
  State<_SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<_SliderWidget> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.node.getExtraPropDouble('value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final min = node.getExtraPropDouble('min') ?? 0;
    final max = node.getExtraPropDouble('max') ?? 100;
    final step = node.getExtraPropDouble('step') ?? 1;
    final disabled = node.getExtraPropBool('disabled');
    final showValue = node.getExtraPropBool('show-value') || node.getExtraPropBool('showValue');
    final activeColor = parseColor(node.getExtraProp('activeColor')) ?? const Color(0xFF1AAD19);
    final bgColor = parseColor(node.getExtraProp('backgroundColor')) ?? const Color(0xFFE9E9E9);
    final blockColor = parseColor(node.getExtraProp('block-color') ??
        node.getExtraProp('blockColor')) ?? Colors.white;
    final blockSize = node.getExtraPropDouble('block-size') ??
        node.getExtraPropDouble('blockSize') ?? 28;

    final divisions = step > 0 ? ((max - min) / step).round() : null;

    return SizedBox(
      width: node.width > 0 ? node.width : null,
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: activeColor,
                inactiveTrackColor: bgColor,
                thumbColor: blockColor,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: blockSize / 2),
                overlayShape: RoundSliderOverlayShape(overlayRadius: blockSize * 0.75),
              ),
              child: Slider(
                value: _value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: disabled
                    ? null
                    : (val) {
                        setState(() => _value = val);
                        widget.onEvent?.call(node.id, 'changing');
                      },
                onChangeEnd: disabled
                    ? null
                    : (val) {
                        widget.onEvent?.call(node.id, 'change');
                      },
              ),
            ),
          ),
          if (showValue)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _value.toStringAsFixed(step < 1 ? 1 : 0),
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
