import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// Demo 1: JS 引擎 — 创建/执行/销毁 + 事件系统。
class EngineDemoPage extends StatefulWidget {
  const EngineDemoPage({super.key});

  @override
  State<EngineDemoPage> createState() => _EngineDemoPageState();
}

class _EngineDemoPageState extends State<EngineDemoPage> {
  final _results = <_LogEntry>[];
  int? _engineId;

  void _log(String msg, {bool isError = false}) {
    setState(() => _results.add(_LogEntry(msg, isError: isError)));
  }

  Future<void> _createEngine() async {
    try {
      _engineId = await Qiqiaoban.createJsEngine(memoryLimitMb: 16);
      _log('✅ 引擎 #$_engineId 创建成功');
    } catch (e) {
      _log('❌ 创建失败: $e', isError: true);
    }
  }

  Future<void> _evalBasic() async {
    if (_engineId == null) return _log('⚠️ 请先创建引擎', isError: true);
    final result = await Qiqiaoban.evalJs(
      engineId: _engineId!,
      code: '1 + 2 + 3',
    );
    _log('📝 eval("1+2+3") = $result');
  }

  Future<void> _evalJson() async {
    if (_engineId == null) return _log('⚠️ 请先创建引擎', isError: true);
    final result = await Qiqiaoban.evalJs(
      engineId: _engineId!,
      code: 'JSON.stringify({ name: "七巧板", version: 1, features: ["编译","渲染","事件"] })',
    );
    _log('📝 eval(JSON) = $result');
  }

  Future<void> _evalLoop() async {
    if (_engineId == null) return _log('⚠️ 请先创建引擎', isError: true);
    final sw = Stopwatch()..start();
    final result = await Qiqiaoban.evalJs(
      engineId: _engineId!,
      code: 'var s=0; for(var i=1;i<=10000;i++) s+=i; s',
    );
    sw.stop();
    _log('📝 Σ(1..10000) = $result (${sw.elapsedMilliseconds}ms)');
  }

  Future<void> _evalState() async {
    if (_engineId == null) return _log('⚠️ 请先创建引擎', isError: true);
    await Qiqiaoban.evalJs(
      engineId: _engineId!,
      code: 'var __count = (__count || 0) + 1',
    );
    final result = await Qiqiaoban.evalJs(
      engineId: _engineId!,
      code: '__count',
    );
    _log('📝 __count = $result (每次调用递增)');
  }

  Future<void> _destroyEngine() async {
    if (_engineId == null) return;
    await Qiqiaoban.destroyJsEngine(engineId: _engineId!);
    _log('🗑 引擎 #$_engineId 已销毁');
    _engineId = null;
  }

  @override
  void dispose() {
    if (_engineId != null) {
      Qiqiaoban.destroyJsEngine(engineId: _engineId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('JS 引擎')),
      body: Column(
        children: [
          // 操作按钮
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ActionChip('创建引擎', Icons.add_circle, _createEngine),
                _ActionChip('基础运算', Icons.calculate, _evalBasic),
                _ActionChip('JSON 对象', Icons.data_object, _evalJson),
                _ActionChip('循环万次', Icons.loop, _evalLoop),
                _ActionChip('状态累加', Icons.trending_up, _evalState),
                _ActionChip('销毁引擎', Icons.delete, _destroyEngine,
                    color: Colors.red),
              ],
            ),
          ),
          // 状态栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Icon(Icons.memory, size: 16,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  '引擎: ${_engineId != null ? "#$_engineId 运行中" : "未创建"}'
                  '  |  活跃数: ${Qiqiaoban.activeEngineCount}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // 日志输出
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('点击按钮开始测试'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final entry = _results[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          entry.message,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: entry.isError
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => setState(() => _results.clear()),
        child: const Icon(Icons.clear_all),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.label, this.icon, this.onTap, {this.color});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
      ),
    );
  }
}

class _LogEntry {
  _LogEntry(this.message, {this.isError = false});
  final String message;
  final bool isError;
}
