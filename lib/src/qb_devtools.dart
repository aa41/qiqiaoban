import 'dart:convert';

import 'package:flutter/material.dart';

import 'qb_engine.dart';
import 'qb_logger.dart';

/// 七巧板 DevTools 调试浮层 — 组件树/state/事件日志可视化。
///
/// 开发模式下可叠加在应用上方，提供实时调试信息。
///
/// ```dart
/// Stack(
///   children: [
///     MyApp(),
///     QBDevToolsOverlay(componentIds: [1, 2]),
///   ],
/// )
/// ```
class QBDevToolsOverlay extends StatefulWidget {
  const QBDevToolsOverlay({
    super.key,
    this.componentIds = const [],
    this.initiallyExpanded = false,
  });

  /// 要监控的组件 ID 列表。
  final List<int> componentIds;

  /// 初始是否展开。
  final bool initiallyExpanded;

  @override
  State<QBDevToolsOverlay> createState() => _QBDevToolsOverlayState();
}

class _QBDevToolsOverlayState extends State<QBDevToolsOverlay> {
  bool _expanded = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Positioned(
        right: 8,
        bottom: 8,
        child: FloatingActionButton.small(
          heroTag: 'qb_devtools',
          onPressed: () => setState(() => _expanded = true),
          backgroundColor: Colors.deepPurple,
          child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
        ),
      );
    }

    return Positioned(
      right: 8,
      bottom: 8,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 320,
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildTabs(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade700,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text(
            '七巧板 DevTools',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => _expanded = false),
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['State', 'VNode', 'Perf'];
    return Container(
      color: const Color(0xFF2A2A3C),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _selectedTab = i);
                _refreshData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? Colors.deepPurple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent() {
    return switch (_selectedTab) {
      0 => _buildStateTab(),
      1 => _buildVNodeTab(),
      2 => _buildPerfTab(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildStateTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final id in widget.componentIds) ...[
          _buildSectionHeader('Component #$id'),
          FutureBuilder<String?>(
            future: _getComponentState(id),
            builder: (ctx, snap) {
              if (snap.hasData && snap.data != null) {
                return _buildJsonViewer(snap.data!);
              }
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Loading...', style: TextStyle(color: Colors.white38, fontSize: 11)),
              );
            },
          ),
        ],
        if (widget.componentIds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No components registered', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildVNodeTab() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final id in widget.componentIds) ...[
          _buildSectionHeader('Component #$id VNode'),
          FutureBuilder<String?>(
            future: _getComponentVNode(id),
            builder: (ctx, snap) {
              if (snap.hasData && snap.data != null) {
                return _buildJsonViewer(snap.data!);
              }
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Loading...', style: TextStyle(color: Colors.white38, fontSize: 11)),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPerfTab() {
    final entries = QBLogger.perfEntries.reversed.take(20).toList();
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Performance Metrics'),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No metrics yet', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: entry.duration.inMilliseconds > 16
                        ? Colors.orange
                        : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
                Text(
                  '${entry.duration.inMilliseconds}ms',
                  style: TextStyle(
                    color: entry.duration.inMilliseconds > 16
                        ? Colors.orange
                        : Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.deepPurpleAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildJsonViewer(String json) {
    try {
      final obj = jsonDecode(json);
      final pretty = const JsonEncoder.withIndent('  ').convert(obj);
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(
          pretty,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      );
    } catch (_) {
      return Text(json, style: const TextStyle(color: Colors.white54, fontSize: 10));
    }
  }

  Future<String?> _getComponentState(int id) async {
    try {
      return await Qiqiaoban.evalComponentJs(
        code: 'JSON.stringify(__qb_components[$id].__data)',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getComponentVNode(int id) async {
    try {
      return await Qiqiaoban.getComponentVnode(componentId: id);
    } catch (_) {
      return null;
    }
  }

  void _refreshData() {
    // Trigger rebuild to refresh FutureBuilders
    setState(() {});
  }
}
