/// swiper 轮播组件 — 对应微信小程序 `<swiper>`。
///
/// 子节点使用 Rust 布局引擎预计算的 x/y 坐标进行绝对定位。
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../rust/api/poc_render.dart';
import 'qb_component_props.dart';

/// 构建 swiper 组件 (StatefulWidget 封装)。
Widget buildSwiperWidget(
  RenderNode node,
  Widget Function(RenderNode) buildChild,
  void Function(String nodeId, String eventName)? onEvent,
) {
  return _SwiperWidget(
    node: node,
    buildChild: buildChild,
    onEvent: onEvent,
  );
}

class _SwiperWidget extends StatefulWidget {
  final RenderNode node;
  final Widget Function(RenderNode) buildChild;
  final void Function(String nodeId, String eventName)? onEvent;

  const _SwiperWidget({
    required this.node,
    required this.buildChild,
    this.onEvent,
  });

  @override
  State<_SwiperWidget> createState() => _SwiperWidgetState();
}

class _SwiperWidgetState extends State<_SwiperWidget> {
  late PageController _controller;
  Timer? _autoplayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final node = widget.node;
    _currentPage = node.getExtraPropInt('current') ?? 0;
    _controller = PageController(initialPage: _currentPage);

    if (node.getExtraPropBool('autoplay')) {
      final interval = node.getExtraPropInt('interval') ?? 5000;
      _autoplayTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
        if (!mounted) return;
        final itemCount = node.children.length;
        if (itemCount <= 1) return;
        final circular = node.getExtraPropBool('circular');
        final nextPage = _currentPage + 1;
        if (circular || nextPage < itemCount) {
          _controller.animateToPage(
            circular ? nextPage % itemCount : nextPage,
            duration: Duration(milliseconds: node.getExtraPropInt('duration') ?? 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final showDots = node.getExtraPropBool('indicator-dots') ||
        node.getExtraPropBool('indicatorDots');
    final dotColor = parseColor(node.getExtraProp('indicator-color') ??
        node.getExtraProp('indicatorColor')) ?? Colors.grey.withValues(alpha: 0.5);
    final activeDotColor = parseColor(node.getExtraProp('indicator-active-color') ??
        node.getExtraProp('indicatorActiveColor')) ?? Colors.black;

    // 每个 swiper item 使用 Stack+Positioned 渲染其子树
    final pages = node.children.map((child) {
      return SizedBox(
        width: child.width,
        height: child.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: child.children.map((grandChild) {
            return Positioned(
              left: grandChild.x,
              top: grandChild.y,
              child: widget.buildChild(grandChild),
            );
          }).toList(),
        ),
      );
    }).toList();

    Widget pageView = PageView(
      controller: _controller,
      scrollDirection: node.getExtraPropBool('vertical')
          ? Axis.vertical
          : Axis.horizontal,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        widget.onEvent?.call(node.id, 'change');
      },
      children: pages,
    );

    Widget result = Container(
      width: node.width,
      height: node.height,
      decoration: buildDecoration(node),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          pageView,
          if (showDots && pages.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentPage ? activeDotColor : dotColor,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );

    return result;
  }
}
