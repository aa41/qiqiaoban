import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// Demo 6: DevTools 调试面板。
class DevToolsDemoPage extends StatefulWidget {
  const DevToolsDemoPage({super.key});

  @override
  State<DevToolsDemoPage> createState() => _DevToolsDemoPageState();
}

class _DevToolsDemoPageState extends State<DevToolsDemoPage> {
  final _componentIds = <int>[];

  @override
  void initState() {
    super.initState();
    // 启用性能追踪来填充 DevTools Perf 面板
    QBLogger.enablePerfTracking = true;

    // 生成一些性能数据供面板展示
    for (final label in ['init', 'compile', 'render', 'layout', 'diff']) {
      final sw = QBLogger.startTimer(label);
      // 模拟耗时
      for (var i = 0; i < 50000; i++) {
        // simulate work
      }
      QBLogger.stopTimer(sw, label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('DevTools 面板')),
      body: Stack(
        children: [
          // 主内容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bug_report,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('DevTools 调试浮层',
                                style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '点击右下角 🐛 按钮打开 DevTools 面板，'
                          '可查看:',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        _FeatureItem('State', '组件 data 状态实时查看'),
                        _FeatureItem('VNode', '当前 VNode 树 JSON'),
                        _FeatureItem('Perf', '性能指标 (编译/渲染/diff耗时)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Logger 配置',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('日志级别: '),
                            DropdownButton<QBLogLevel>(
                              value: QBLogger.level,
                              items: QBLogLevel.values.map((l) {
                                return DropdownMenuItem(
                                    value: l, child: Text(l.name));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => QBLogger.level = v);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('性能追踪'),
                          subtitle:
                              Text('已记录 ${QBLogger.perfEntries.length} 条'),
                          value: QBLogger.enablePerfTracking,
                          onChanged: (v) {
                            setState(
                                () => QBLogger.enablePerfTracking = v);
                          },
                          dense: true,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('记录 debug'),
                              onPressed: () =>
                                  QBLogger.debug('Debug message from demo'),
                            ),
                            ActionChip(
                              label: const Text('记录 info'),
                              onPressed: () =>
                                  QBLogger.info('Info message from demo'),
                            ),
                            ActionChip(
                              label: const Text('记录 warn'),
                              onPressed: () =>
                                  QBLogger.warn('Warning from demo'),
                            ),
                            ActionChip(
                              label: const Text('记录 error'),
                              onPressed: () =>
                                  QBLogger.error('Error from demo'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Hot Reload 信息
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hot Reload 管理器',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Text(
                          'QBHotReloadManager 支持:\n'
                          '• 注册/注销组件实例\n'
                          '• 重编译模板 (保留 state)\n'
                          '• reload 回调通知',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enabled: ${QBHotReloadManager.enabled}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // DevTools 浮层
          QBDevToolsOverlay(
            componentIds: _componentIds,
            initiallyExpanded: false,
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem(this.tab, this.desc);
  final String tab;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tab,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700)),
          ),
          const SizedBox(width: 8),
          Text(desc,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
