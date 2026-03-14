import 'package:flutter/material.dart';

import 'rust/api/poc_render.dart';
import 'components/qb_component_props.dart';
import 'components/qb_view_widget.dart';
import 'components/qb_text_widget.dart';
import 'components/qb_scroll_view_widget.dart';
import 'components/qb_swiper_widget.dart';
import 'components/qb_icon_widget.dart';
import 'components/qb_rich_text_widget.dart';
import 'components/qb_button_widget.dart';
import 'components/qb_checkbox_widget.dart';
import 'components/qb_form_widget.dart';
import 'components/qb_input_widget.dart';
import 'components/qb_picker_widget.dart';
import 'components/qb_radio_widget.dart';
import 'components/qb_slider_widget.dart';
import 'components/qb_switch_widget.dart';
import 'components/qb_textarea_widget.dart';
import 'components/qb_list_view_widget.dart';
import 'components/qb_navigator_widget.dart';
import 'components/qb_canvas_widget.dart';

/// 事件回调类型 — Widget 触发事件时调用。
typedef QBEventCallback =
    void Function(String nodeId, String eventType, Map<String, dynamic>? data);

/// 七巧板 Widget 工厂 — RenderNode 树 → Flutter Widget 树。
///
/// 递归遍历 RenderNode 树，根据 node_type 映射到 Flutter Widget。
/// 支持 26 种微信小程序组件:
///
/// **视图容器:** view, scroll-view, swiper
/// **基础内容:** text, icon, rich-text
/// **表单组件:** button, checkbox, checkbox-group, form, input, picker,
///   picker-view, radio, radio-group, slider, switch, textarea
/// **Skyline:**  draggable-sheet, grid-builder, grid-view,
///   list-builder, list-view
/// **导航:**    navigator
/// **画布:**    canvas
class QBWidgetFactory {
  QBWidgetFactory._();

  /// 自定义 Widget 构建器注册表。
  static final Map<String, Widget Function(RenderNode)> _customBuilders = {};

  /// 注册一个自定义 Widget 构建器。
  static void register(String type, Widget Function(RenderNode) builder) {
    _customBuilders[type] = builder;
  }

  /// 取消注册。
  static void unregister(String type) {
    _customBuilders.remove(type);
  }

  /// 从 RenderNode 树构建 Flutter Widget 树。
  static Widget buildTree(RenderNode root, {QBEventCallback? onEvent}) {
    return _buildWidget(root, onEvent);
  }

  /// 兼容旧 API — 从扁平 RenderNode 列表构建 Widget。
  static Widget buildTreeFromList(
    List<RenderNode> nodes, {
    QBEventCallback? onEvent,
  }) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    final root = nodes.first;
    return SizedBox(
      width: root.width,
      height: root.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: nodes.map((n) {
          Widget child = _buildWidget(n, onEvent);
          return Positioned(left: n.x, top: n.y, child: child);
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 核心: 递归构建单个节点 → Widget
  // ─────────────────────────────────────────────────────────

  static Widget _buildWidget(RenderNode node, QBEventCallback? onEvent) {
    // 1. 优先使用自定义构建器
    final customBuilder = _customBuilders[node.nodeType];
    if (customBuilder != null) {
      return _wrapSize(
        node,
        _maybeWrapGestures(customBuilder(node), node, onEvent),
      );
    }

    // 2. 事件回调适配 (组件内部使用简化签名)
    void eventProxy(String nodeId, String eventName) {
      onEvent?.call(nodeId, eventName, null);
    }

    // 3. 组件注册表分发
    Widget child;
    switch (node.nodeType) {
      // ---- 视图容器 ----
      case 'view':
        child = buildViewWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'scroll-view' || 'scrollview':
        child = buildScrollViewWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'swiper':
        child = buildSwiperWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);

      // ---- 基础内容 ----
      case 'text':
        child = buildTextWidget(node, eventProxy);
      case 'icon':
        child = buildIconWidget(node);
      case 'rich-text' || 'richtext':
        child = buildRichTextWidget(node, (c) => _buildWidget(c, onEvent));

      // ---- 表单组件 ----
      case 'button':
        child = buildButtonWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'checkbox':
        child = buildCheckboxWidget(node, eventProxy);
      case 'checkbox-group' || 'checkboxgroup':
        child = buildCheckboxGroupWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'form':
        child = buildFormWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'input':
        child = buildInputWidget(node, eventProxy);
      case 'picker':
        child = buildPickerWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'picker-view' || 'pickerview':
        child = buildPickerViewWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'radio':
        child = buildRadioWidget(node, eventProxy);
      case 'radio-group' || 'radiogroup':
        child = buildRadioGroupWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'slider':
        child = buildSliderWidget(node, eventProxy);
      case 'switch':
        child = buildSwitchWidget(node, eventProxy);
      case 'textarea':
        child = buildTextareaWidget(node, eventProxy);

      // ---- Skyline 高性能组件 ----
      case 'list-view' || 'listview':
        child = buildListViewWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'list-builder' || 'listbuilder':
        child = buildListBuilderWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'grid-view' || 'gridview':
        child = buildGridViewWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'grid-builder' || 'gridbuilder':
        child = buildGridBuilderWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
      case 'draggable-sheet' || 'draggablesheet':
        child = buildDraggableSheetWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);

      // ---- 导航 ----
      case 'navigator':
        child = buildNavigatorWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);

      // ---- 画布 ----
      case 'canvas':
        child = buildCanvasWidget(node, eventProxy);

      // ---- 图片 (保留旧逻辑) ----
      case 'image':
        child = _buildImage(node);

      // ---- 默认: 当作 view 处理 ----
      default:
        child = buildViewWidget(node, (c) => _buildWidget(c, onEvent), eventProxy);
    }

    return child;
  }

  // ─────────────────────────────────────────────────────────
  // 保留: image (旧实现)
  // ─────────────────────────────────────────────────────────
  static Widget _buildImage(RenderNode node) {
    return Container(
      width: node.width,
      height: node.height,
      decoration: BoxDecoration(
        color: parseColor(node.color) ?? Colors.grey.shade200,
      ),
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey, size: 32),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 辅助方法
  // ─────────────────────────────────────────────────────────

  static Widget _wrapSize(RenderNode node, Widget child) {
    return SizedBox(width: node.width, height: node.height, child: child);
  }

  static Widget _maybeWrapGestures(
    Widget child,
    RenderNode node,
    QBEventCallback? onEvent,
  ) {
    if (onEvent == null || node.events.isEmpty) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: node.events.contains('tap')
          ? () => onEvent(node.id, 'tap', null)
          : null,
      onDoubleTap: node.events.contains('doubleTap')
          ? () => onEvent(node.id, 'doubleTap', null)
          : null,
      onLongPress: node.events.contains('longPress')
          ? () => onEvent(node.id, 'longPress', null)
          : null,
      child: child,
    );
  }
}
