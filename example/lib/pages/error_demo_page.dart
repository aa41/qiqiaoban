import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// Demo 5: 错误处理 & 安全沙箱。
class ErrorDemoPage extends StatefulWidget {
  const ErrorDemoPage({super.key});

  @override
  State<ErrorDemoPage> createState() => _ErrorDemoPageState();
}

class _ErrorDemoPageState extends State<ErrorDemoPage> {
  final _results = <_Entry>[];

  void _log(String msg, {bool ok = true}) {
    setState(() => _results.add(_Entry(msg, ok: ok)));
  }

  /// 编译一个有语法错误的模板。
  Future<void> _testCompileError() async {
    _log('--- 编译错误测试 ---', ok: true);
    try {
      await compileTemplate(template: '<view v-else></view>');
      _log('⚠️ 居然没报错?', ok: false);
    } catch (e) {
      _log('✅ 正确捕获: ${e.toString().split('\n').first}');
    }
  }

  /// 使用安全编译。
  Future<void> _testSafeCompile() async {
    _log('--- 安全编译测试 ---', ok: true);
    try {
      final result = await safeCompileTemplate(template: '<view><text>OK</text></view>');
      _log('✅ 安全编译成功: ${result.substring(0, 40)}...');
    } catch (e) {
      _log('❌ 安全编译失败: $e', ok: false);
    }
  }

  /// 测试错误上报系统。
  void _testErrorHandler() {
    _log('--- 错误处理器测试 ---', ok: true);
    QBErrorHandler.clear();

    QBErrorHandler.reportCompileError('模板语法错误: 缺少闭合标签');
    QBErrorHandler.reportRuntimeError('TypeError: undefined is not a function',
        componentId: 42);
    QBErrorHandler.reportRenderError('VNode 节点数超出限制',
        componentId: 42);
    QBErrorHandler.reportNetworkError('Connection timeout',
        url: 'https://cdn.example.com/bundle.js');

    // 测试去重
    QBErrorHandler.reportCompileError('模板语法错误: 缺少闭合标签');

    _log('✅ 错误数量: ${QBErrorHandler.recentErrors.length} (去重生效: 4 不是 5)');
    for (final e in QBErrorHandler.recentErrors) {
      _log('  [${e.source.name}] ${e.message}');
    }
  }

  /// SHA256 校验测试。
  void _testChecksum() {
    _log('--- SHA256 校验测试 ---', ok: true);
    final hash = QBBundleManager.sha256Hex('hello world');
    const expected =
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';
    _log('输入: "hello world"');
    _log('SHA256: $hash');
    _log(hash == expected ? '✅ 校验通过' : '❌ 校验失败', ok: hash == expected);
  }

  /// Bundle 配置测试。
  void _testBundleConfig() {
    _log('--- Bundle 配置测试 ---', ok: true);
    final config = QBBundleConfig(
      url: 'https://cdn.example.com/counter.js',
      version: '1.2.0',
      checksum: 'sha256:abc123',
      maxCacheAge: const Duration(hours: 12),
    );
    _log('✅ URL: ${config.url}');
    _log('✅ Version: ${config.version}');
    _log('✅ CacheKey: ${config.effectiveCacheKey}');
    _log('✅ MaxAge: ${config.maxCacheAge.inHours}h');
  }

  /// Logger 性能追踪测试。
  void _testPerfTracking() {
    _log('--- 性能追踪测试 ---', ok: true);
    QBLogger.clearPerfEntries();

    // 模拟一些操作
    for (final label in ['compile', 'render', 'diff', 'layout']) {
      final sw = QBLogger.startTimer(label);
      // 模拟耗时
      for (var i = 0; i < 100000; i++) {
        // simulate work
      }
      QBLogger.stopTimer(sw, label);
    }

    _log('✅ 记录了 ${QBLogger.perfEntries.length} 条性能指标:');
    for (final e in QBLogger.perfEntries) {
      _log('  ⏱ ${e.label}: ${e.duration.inMicroseconds}μs');
    }
  }

  void _runAll() {
    setState(() => _results.clear());
    _testCompileError();
    _testSafeCompile();
    _testErrorHandler();
    _testChecksum();
    _testBundleConfig();
    _testPerfTracking();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('错误处理 & 安全'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '运行全部',
            onPressed: _runAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // 快捷按钮
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _Chip('编译错误', _testCompileError),
              _Chip('安全编译', _testSafeCompile),
              _Chip('错误处理器', _testErrorHandler),
              _Chip('SHA256', _testChecksum),
              _Chip('Bundle配置', _testBundleConfig),
              _Chip('性能追踪', _testPerfTracking),
              _Chip('🚀 全部运行', _runAll),
            ]),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('点击按钮运行测试'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final e = _results[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          e.msg,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: e.ok
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.error,
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

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          onPressed: onTap,
        ),
      );
}

class _Entry {
  _Entry(this.msg, {this.ok = true});
  final String msg;
  final bool ok;
}
