import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// Demo 2: Flexbox 渲染 — JS → Rust 布局 → Flutter 绘制。
class RenderDemoPage extends StatefulWidget {
  const RenderDemoPage({super.key});

  @override
  State<RenderDemoPage> createState() => _RenderDemoPageState();
}

class _RenderDemoPageState extends State<RenderDemoPage> {
  RenderNode? _renderRoot;
  String? _error;
  bool _isLoading = false;
  bool _isRunning = false; // 防止重入
  int _demoIndex = 0;

  static const _demos = [
    _Demo(
      title: 'Column 布局',
      desc: 'flex-direction: column, header / body / footer',
      code: r'''({
  id: "root", type: "view",
  style: { flexDirection: "column", width: 320, height: 480, backgroundColor: "#F5F5F5" },
  children: [
    { id: "header", type: "view",
      style: { height: 56, backgroundColor: "#3F51B5", justifyContent: "center", alignItems: "center" },
      children: [
        { id: "t1", type: "text", text: "七巧板 PoC", style: { fontSize: 20, color: "#FFF", height: 28 } }
      ]
    },
    { id: "body", type: "view",
      style: { flexGrow: 1, flexDirection: "column", padding: 16, gap: 12 },
      children: [
        { id: "c1", type: "view", style: { height: 72, backgroundColor: "#E3F2FD", padding: 12 },
          children: [{ id: "c1t", type: "text", text: "JS 定义 UI ✅", style: { fontSize: 16, color: "#1565C0", height: 24 } }] },
        { id: "c2", type: "view", style: { height: 72, backgroundColor: "#E8F5E9", padding: 12 },
          children: [{ id: "c2t", type: "text", text: "Rust 布局 ✅", style: { fontSize: 16, color: "#2E7D32", height: 24 } }] },
        { id: "c3", type: "view", style: { height: 72, backgroundColor: "#FFF3E0", padding: 12 },
          children: [{ id: "c3t", type: "text", text: "Flutter 渲染 ✅", style: { fontSize: 16, color: "#E65100", height: 24 } }] }
      ]
    },
    { id: "footer", type: "view",
      style: { height: 42, backgroundColor: "#E8EAF6", justifyContent: "center", alignItems: "center" },
      children: [
        { id: "ft", type: "text", text: "Powered by QuickJS + Taffy", style: { fontSize: 11, color: "#5C6BC0", height: 16 } }
      ]
    }
  ]
})''',
    ),
    _Demo(
      title: 'Row + FlexGrow',
      desc: 'flex-direction: row, 等比空间分配 1:2:1',
      code: r'''({
  id: "root", type: "view",
  style: { flexDirection: "column", width: 320, height: 480, backgroundColor: "#FAFAFA" },
  children: [
    { id: "bar", type: "view",
      style: { height: 48, backgroundColor: "#009688", alignItems: "center", padding: 12 },
      children: [{ id: "bt", type: "text", text: "Row + Flex Grow", style: { fontSize: 18, color: "#FFF", height: 24 } }] },
    { id: "row", type: "view",
      style: { flexDirection: "row", gap: 8, padding: 16, height: 120 },
      children: [
        { id: "r1", type: "view", style: { flexGrow: 1, backgroundColor: "#B2DFDB" },
          children: [{ id: "r1t", type: "text", text: "1x", style: { fontSize: 24, color: "#00695C", height: 32 } }] },
        { id: "r2", type: "view", style: { flexGrow: 2, backgroundColor: "#80CBC4" },
          children: [{ id: "r2t", type: "text", text: "2x", style: { fontSize: 24, color: "#00695C", height: 32 } }] },
        { id: "r3", type: "view", style: { flexGrow: 1, backgroundColor: "#4DB6AC" },
          children: [{ id: "r3t", type: "text", text: "1x", style: { fontSize: 24, color: "#FFF", height: 32 } }] }
      ]
    },
    { id: "info", type: "view",
      style: { flexGrow: 1, padding: 16, flexDirection: "column", gap: 6 },
      children: [
        { id: "i1", type: "text", text: "flexGrow:1 → 25%", style: { fontSize: 13, color: "#666", height: 18 } },
        { id: "i2", type: "text", text: "flexGrow:2 → 50%", style: { fontSize: 13, color: "#666", height: 18 } },
        { id: "i3", type: "text", text: "flexGrow:1 → 25%", style: { fontSize: 13, color: "#666", height: 18 } }
      ]
    }
  ]
})''',
    ),
    _Demo(
      title: 'JS 动态生成',
      desc: 'JS 循环动态生成 5 个子元素',
      code: r'''(function() {
  var colors = ["#EF5350","#AB47BC","#42A5F5","#66BB6A","#FFA726"];
  var items = [];
  for (var i = 0; i < 5; i++) {
    items.push({
      id: "item"+i, type: "view",
      style: { height: 60, backgroundColor: colors[i], justifyContent: "center", padding: 12 },
      children: [{ id: "t"+i, type: "text", text: "动态 #"+(i+1), style: { fontSize: 16, color: "#FFF", height: 24 } }]
    });
  }
  return {
    id: "root", type: "view",
    style: { flexDirection: "column", width: 320, height: 480, backgroundColor: "#212121", padding: 16, gap: 12 },
    children: [
      { id: "hd", type: "view", style: { height: 48, justifyContent: "center", alignItems: "center" },
        children: [{ id: "ht", type: "text", text: "JS Loop 生成 "+items.length+" 个", style: { fontSize: 18, color: "#FFF", height: 28 } }] }
    ].concat(items)
  };
})()''',
    ),
  ];

  Future<void> _runDemo(int idx) async {
    // 防止频繁点击导致重入
    if (_isRunning) {
      debugPrint('[QBRender] Skipping - already running');
      return;
    }
    _isRunning = true;
    debugPrint('[QBRender] Starting demo $idx...');
    setState(() {
      _isLoading = true;
      _error = null;
      _demoIndex = idx;
    });
    try {
      final sw = Stopwatch()..start();
      final root = await renderFromJs(
        jsCode: _demos[idx].code,
        viewportWidth: 320,
        viewportHeight: 480,
      );
      sw.stop();
      debugPrint('[QBRender] Success: root=${root.id} in ${sw.elapsedMilliseconds}ms');
      if (mounted) {
        setState(() {
          _renderRoot = root;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[QBRender] ERROR: $e');
      debugPrint('[QBRender] Dart stack:\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      _isRunning = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDemo(0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Flexbox 渲染')),
      body: Column(
        children: [
          // 切换按钮
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              segments: List.generate(_demos.length, (i) {
                return ButtonSegment(value: i, label: Text(_demos[i].title));
              }),
              selected: {_demoIndex},
              onSelectionChanged: (s) => _runDemo(s.first),
              style: const ButtonStyle(
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              ),
            ),
          ),
          Text(_demos[_demoIndex].desc,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          // 渲染区域
          Expanded(
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              '错误详情:\n\n$_error',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        )
                      : _renderRoot != null
                          ? Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: QBRenderWidget(root: _renderRoot!),
                              ),
                            )
                          : const SizedBox.shrink(),
            ),
          ),
          // 底部信息
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerLow,
            child: Text('root: ${_renderRoot?.id ?? "N/A"}',
                style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Demo {
  const _Demo({required this.title, required this.desc, required this.code});
  final String title;
  final String desc;
  final String code;
}
