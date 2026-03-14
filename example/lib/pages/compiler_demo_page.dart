import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// Demo 3: Vue 模板编译器。
class CompilerDemoPage extends StatefulWidget {
  const CompilerDemoPage({super.key});

  @override
  State<CompilerDemoPage> createState() => _CompilerDemoPageState();
}

class _CompilerDemoPageState extends State<CompilerDemoPage> {
  final _controller = TextEditingController(
    text: '<view @tap="handleTap">\n'
        '  <text v-if="show">Hello {{ name }}</text>\n'
        '  <view v-for="item in list">\n'
        '    <text :class="item.cls">{{ item.label }}</text>\n'
        '  </view>\n'
        '</view>',
  );
  String? _output;
  String? _error;
  Duration? _compileTime;

  Future<void> _compile() async {
    setState(() {
      _error = null;
      _output = null;
    });
    try {
      final sw = Stopwatch()..start();
      final js = await compileTemplate(template: _controller.text);
      sw.stop();
      setState(() {
        _output = js;
        _compileTime = sw.elapsed;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _safeCompile() async {
    setState(() {
      _error = null;
      _output = null;
    });
    try {
      final result = await safeCompileTemplate(template: _controller.text);
      setState(() => _output = '✅ safe_compile:\n$result');
    } catch (e) {
      setState(() => _error = '❌ safe_compile error:\n$e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vue 模板编译'),
        actions: [
          if (_output != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _output!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 模板输入
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: 8,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Vue 模板',
                border: const OutlineInputBorder(),
                suffixIcon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      tooltip: '编译',
                      onPressed: _compile,
                    ),
                    IconButton(
                      icon: const Icon(Icons.shield),
                      tooltip: '安全编译',
                      onPressed: _safeCompile,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 快捷模板
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _QuickTemplate('简单', '<view><text>Hello</text></view>'),
                _QuickTemplate('v-if',
                    '<view><text v-if="show">Visible</text></view>'),
                _QuickTemplate('v-for',
                    '<view v-for="i in list"><text>{{ i }}</text></view>'),
                _QuickTemplate(
                    'v-model', '<input v-model="name" />'),
                _QuickTemplate('事件',
                    '<view @tap="onClick"><text>Tap me</text></view>'),
                _QuickTemplate('❌ 错误',
                    '<view v-else><text>Bad</text></view>'),
              ].map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(t.label, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      _controller.text = t.template;
                      _compile();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 编译时间
          if (_compileTime != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 14,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '编译耗时: ${_compileTime!.inMicroseconds}μs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // 输出区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _error != null
                  ? SelectableText(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.error,
                      ),
                    )
                  : _output != null
                      ? SelectableText(
                          _output!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        )
                      : Center(
                          child: Text('点击 ▶ 编译模板',
                              style: theme.textTheme.bodySmall),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTemplate {
  const _QuickTemplate(this.label, this.template);
  final String label;
  final String template;
}
