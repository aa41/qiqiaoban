import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// 知乎首页高仿 — 复杂长列表渲染演示 (可滚动)。
class ZhihuDemoPage extends StatefulWidget {
  const ZhihuDemoPage({super.key});

  @override
  State<ZhihuDemoPage> createState() => _ZhihuDemoPageState();
}

class _ZhihuDemoPageState extends State<ZhihuDemoPage> {
  RenderNode? _renderRoot;
  String? _error;
  bool _isLoading = true;
  bool _isRunning = false;
  int _nodeCount = 0;
  Duration? _renderTime;

  /// 知乎首页 JS 代码 — 包含状态栏、导航、Tab、Feed 流、热榜、底部栏。
  /// 总高度超过屏幕，自动触发滚动。
  static const _zhihuJs = r'''
(function() {
  var uid = 0;
  function id() { return "z" + (uid++); }

  function text(content, opts) {
    var s = { height: opts.height || 20 };
    if (opts.fontSize) s.fontSize = opts.fontSize;
    if (opts.color) s.color = opts.color;
    if (opts.fontWeight) s.fontWeight = opts.fontWeight;
    if (opts.flexGrow) s.flexGrow = opts.flexGrow;
    if (opts.width) s.width = opts.width;
    return { id: id(), type: "text", text: content, style: s };
  }

  function box(children, style) {
    var s = {};
    for (var k in style) s[k] = style[k];
    return { id: id(), type: "view", style: s, children: children || [] };
  }

  function hStack(children, style) {
    var s = { flexDirection: "row", alignItems: "center" };
    for (var k in (style||{})) s[k] = style[k];
    return box(children, s);
  }

  function vStack(children, style) {
    var s = { flexDirection: "column" };
    for (var k in (style||{})) s[k] = style[k];
    return box(children, s);
  }

  function spacer() { return box([], { flexGrow: 1 }); }
  function divider() { return box([], { height: 1, backgroundColor: "#EEEEEE" }); }
  function gapBlock() { return box([], { height: 8, backgroundColor: "#F6F6F6" }); }

  // 圆形头像占位
  function avatar(size, color) {
    return box([], { width: size, height: size, backgroundColor: color || "#E0E0E0" });
  }

  // 状态栏
  var statusBar = hStack([
    text("9:41", { fontSize: 14, color: "#000", fontWeight: "bold", height: 18 }),
    spacer(),
    text("●●●●○ ⚡ 85%", { fontSize: 11, color: "#000", height: 14 })
  ], { height: 44, paddingLeft: 24, paddingRight: 24, backgroundColor: "#FFFFFF" });

  // 导航栏
  var navBar = hStack([
    hStack([
      text("🔍", { fontSize: 15, height: 20, color: "#999" }),
      text("天工 AI 搜索 — 试试直达答案", { fontSize: 13, color: "#BBBBBB", height: 18 })
    ], { flexGrow: 1, height: 34, backgroundColor: "#F4F4F4", paddingLeft: 10, paddingRight: 10, gap: 6 }),
    box([text("+", { fontSize: 24, color: "#333", height: 28 })], { width: 42, height: 34, justifyContent: "center", alignItems: "center" }),
    box([text("💬", { fontSize: 18, color: "#333", height: 22 })], { width: 36, height: 34, justifyContent: "center", alignItems: "center" })
  ], { height: 50, paddingLeft: 16, paddingRight: 8, backgroundColor: "#FFFFFF", gap: 2 });

  // Tab 栏
  function tabItem(label, active) {
    return vStack([
      text(label, { fontSize: active ? 16 : 14, color: active ? "#1A1A1A" : "#999999", fontWeight: active ? "bold" : "normal", height: active ? 22 : 20 }),
      box([], { width: active ? 20 : 0, height: 3, backgroundColor: active ? "#0066FF" : "transparent" })
    ], { alignItems: "center", gap: 3, paddingLeft: 14, paddingRight: 14 });
  }
  var tabBar = hStack([
    tabItem("关注", false), tabItem("推荐", true), tabItem("热榜", false),
    tabItem("视频", false), tabItem("想法", false),
    spacer(),
    box([text("☰", { fontSize: 16, color: "#999", height: 20 })], { width: 40, height: 38, justifyContent: "center", alignItems: "center" })
  ], { height: 44, backgroundColor: "#FFFFFF", paddingLeft: 2 });

  // 用户信息行
  function userRow(name, desc, avatarColor) {
    return hStack([
      avatar(28, avatarColor),
      vStack([
        text(name, { fontSize: 13, color: "#333", fontWeight: "bold", height: 17 }),
        text(desc, { fontSize: 11, color: "#999", height: 14 })
      ], { gap: 1 }),
      spacer(),
      text("⋯", { fontSize: 20, color: "#CCCCCC", height: 24 })
    ], { gap: 8, paddingLeft: 16, paddingRight: 16, paddingTop: 12 });
  }

  // 底部操作栏
  function actions(likes, comments, extra) {
    return hStack([
      hStack([text("▲ " + likes, { fontSize: 12, color: "#666", height: 16 })], { height: 28, paddingLeft: 10, paddingRight: 10, backgroundColor: "#F6F6F6" }),
      hStack([text("▼", { fontSize: 12, color: "#999", height: 16 })], { height: 28, paddingLeft: 6, paddingRight: 6, backgroundColor: "#F6F6F6" }),
      hStack([text("💬 " + comments, { fontSize: 12, color: "#666", height: 16 })], { height: 28, paddingLeft: 10, paddingRight: 10 }),
      hStack([text("↗ 分享", { fontSize: 12, color: "#666", height: 16 })], { height: 28, paddingLeft: 10, paddingRight: 10 }),
      spacer(),
      text("☆", { fontSize: 15, color: "#CCCCCC", height: 18 })
    ], { gap: 6, paddingLeft: 16, paddingRight: 16, paddingBottom: 10, paddingTop: 6 });
  }

  // 纯文字回答卡片
  function answerCard(title, author, desc, content, likes, comments, color) {
    return vStack([
      userRow(author, desc, color || "#B0D4F1"),
      vStack([
        text(title, { fontSize: 16, color: "#1A1A1A", fontWeight: "bold", height: 22 }),
        text(content, { fontSize: 14, color: "#444", height: 56 })
      ], { gap: 6, paddingLeft: 16, paddingRight: 16, paddingTop: 8 }),
      actions(likes, comments)
    ], { backgroundColor: "#FFFFFF" });
  }

  // 图文回答卡片
  function imageCard(title, author, desc, content, likes, comments, color) {
    return vStack([
      userRow(author, desc, color || "#B0F1D4"),
      hStack([
        vStack([
          text(title, { fontSize: 16, color: "#1A1A1A", fontWeight: "bold", height: 22 }),
          text(content, { fontSize: 13, color: "#666", height: 36 })
        ], { flexGrow: 1, gap: 4 }),
        box([], { width: 100, height: 68, backgroundColor: "#E8E8E8" })
      ], { gap: 10, paddingLeft: 16, paddingRight: 16, paddingTop: 8, alignItems: "flex-start" }),
      actions(likes, comments)
    ], { backgroundColor: "#FFFFFF" });
  }

  // 热榜条目
  function hotItem(rank, title, heat, tag) {
    var rc = rank <= 3 ? "#FF4500" : "#999";
    return hStack([
      text(rank + "", { fontSize: 16, color: rc, fontWeight: "bold", height: 22, width: 24 }),
      vStack([
        text(title, { fontSize: 14, color: "#1A1A1A", fontWeight: "bold", height: 20 }),
        hStack([
          text(tag, { fontSize: 10, color: tag==="沸" ? "#FF4500" : tag==="热" ? "#FF8C00" : "#0066FF", height: 14 }),
          text(heat + " 万热度", { fontSize: 10, color: "#BBBBBB", height: 14 })
        ], { gap: 6 })
      ], { flexGrow: 1, gap: 3 }),
      box([], { width: 56, height: 56, backgroundColor: "#F0F0F0" })
    ], { gap: 8, paddingLeft: 16, paddingRight: 16, paddingTop: 10, paddingBottom: 10, backgroundColor: "#FFFFFF" });
  }

  // 广告卡片
  function adCard(title, desc) {
    return vStack([
      hStack([
        box([text("广告", { fontSize: 9, color: "#999", height: 12 })], { paddingLeft: 4, paddingRight: 4, paddingTop: 1, paddingBottom: 1, backgroundColor: "#F0F0F0" }),
        text(desc, { fontSize: 11, color: "#999", height: 14 })
      ], { gap: 6, paddingLeft: 16, paddingRight: 16, paddingTop: 10 }),
      hStack([
        vStack([
          text(title, { fontSize: 15, color: "#1A1A1A", fontWeight: "bold", height: 20 }),
          text("了解更多 →", { fontSize: 12, color: "#0066FF", height: 16 })
        ], { flexGrow: 1, gap: 6 }),
        box([], { width: 90, height: 60, backgroundColor: "#E0E8F0" })
      ], { gap: 12, paddingLeft: 16, paddingRight: 16, paddingTop: 8, paddingBottom: 12 })
    ], { backgroundColor: "#FFFFFF" });
  }

  // 底部导航
  function bottomTab(emoji, label, active) {
    return vStack([
      text(emoji, { fontSize: 22, height: 26 }),
      text(label, { fontSize: 10, color: active ? "#0066FF" : "#999", height: 14 })
    ], { alignItems: "center", gap: 2, flexGrow: 1 });
  }

  // 组装完整页面 — 高度超过 812，触发滚动
  return {
    id: "zhihu-root", type: "view",
    style: { flexDirection: "column", width: 375, backgroundColor: "#F6F6F6" },
    children: [
      statusBar, navBar, tabBar, divider(),

      // Feed 1
      answerCard(
        "如何看待 2025 年 AI 编程助手的爆发式增长？",
        "张三", "AI 研究员 · 某大厂 · 3小时前",
        "最近体验了多款 AI 编程助手，从 Copilot 到 Cursor 再到各种新秀。特别是在理解上下文和多文件编辑方面进步明显，但仍存在幻觉问题...",
        "1.2k", "328", "#B0D4F1"
      ),
      gapBlock(),

      // Feed 2
      imageCard(
        "为什么越来越多公司选择 Flutter 做跨端？",
        "李四", "Flutter GDE · 昨天",
        "Flutter 3.x 性能提升明显，加上 Impeller 的加持，已经可以媲美原生",
        "856", "142", "#B0F1D4"
      ),
      gapBlock(),

      // Feed 3
      answerCard(
        "有哪些「原来还可以这样」的编程技巧？",
        "王五", "全栈工程师 · 开源爱好者 · 5小时前",
        "分享一个 Rust 的技巧：利用 newtype pattern 来在编译期防止参数传错。把 UserId 和 PostId 分别定义为不同类型，编译器自动帮你检查...",
        "2.4k", "567", "#F1D4B0"
      ),
      gapBlock(),

      // 广告
      adCard("七巧板 Qiqiaoban — Flutter 动态化方案", "Flutter 插件 · 免费"),
      gapBlock(),

      // 热榜
      vStack([
        hStack([
          text("🔥 知乎热榜", { fontSize: 15, color: "#1A1A1A", fontWeight: "bold", height: 20 }),
          spacer(),
          text("查看全部 >", { fontSize: 12, color: "#0066FF", height: 16 })
        ], { paddingLeft: 16, paddingRight: 16, paddingTop: 12, paddingBottom: 8, backgroundColor: "#FFFFFF" }),
        divider(),
        hotItem(1, "GPT-5 发布日期确认，性能提升 10 倍", 5832, "沸"),
        divider(),
        hotItem(2, "程序员必看的 10 本经典书籍推荐", 3241, "热"),
        divider(),
        hotItem(3, "Rust 正式成为 Linux 内核第二语言", 2876, "沸"),
        divider(),
        hotItem(4, "2025 年薪资最高的编程语言排行", 2104, "新"),
        divider(),
        hotItem(5, "苹果发布 M5 芯片，性能再次翻倍", 1856, "热")
      ], { backgroundColor: "#FFFFFF" }),
      gapBlock(),

      // Feed 4
      imageCard(
        "如何评价七巧板 (Qiqiaoban) 动态化方案?",
        "赵六", "框架开发者 · 七巧板贡献者 · 刚刚",
        "通过 Rust + QuickJS 实现了高性能 Flutter 动态化渲染",
        "666", "88", "#D4B0F1"
      ),
      gapBlock(),

      // Feed 5
      answerCard(
        "独立开发者如何在 2025 年找到靠谱的商业模式？",
        "独立创客", "连续创业者 · 2小时前",
        "我自己做独立开发快3年了，尝试过广告、订阅、买断制等多种模式。分享一些血泪教训和最终找到的可持续路径...",
        "3.1k", "892", "#F1B0D4"
      ),
      gapBlock(),

      // Feed 6
      imageCard(
        "为什么说 WebAssembly 将改变前端格局？",
        "前端老兵", "资深工程师 · 某大厂 · 4小时前",
        "WASM 不只是性能提升，更是打通了多语言生态的桥梁",
        "1.5k", "234", "#B0F1E8"
      ),
      gapBlock(),

      // Feed 7
      answerCard(
        "你见过最优雅的代码是什么样的？",
        "代码审美", "编程艺术家 · 8小时前",
        "优雅的代码不只是 功能正确，更是让人读起来赏心悦目。以 Rust 的迭代器链式调用为例：数据从输入流经过 map、filter、fold 最终汇聚成结果...",
        "4.2k", "1.1k", "#E8F1B0"
      ),
      gapBlock(),

      // 底部导航 (固定在最底)
      divider(),
      hStack([
        bottomTab("🏠", "首页", true),
        bottomTab("🔎", "发现", false),
        bottomTab("➕", "", false),
        bottomTab("✉️", "消息", false),
        bottomTab("👤", "我的", false)
      ], { height: 56, backgroundColor: "#FFFFFF", paddingTop: 6 }),

      // 底部安全区域
      box([], { height: 20, backgroundColor: "#FFFFFF" })
    ]
  };
})()
''';

  Future<void> _render() async {
    if (_isRunning) {
      debugPrint('[QBZhihu] Skipping - already running');
      return;
    }
    _isRunning = true;
    debugPrint('[QBZhihu] Starting render...');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sw = Stopwatch()..start();
      final root = await renderFromJs(
        jsCode: _zhihuJs,
        viewportWidth: 375,
        viewportHeight: 2000,
      );
      sw.stop();
      debugPrint('[QBZhihu] Success: root=${root.id} in ${sw.elapsedMilliseconds}ms');
      if (mounted) {
        setState(() {
          _renderRoot = root;
          _nodeCount = _countNodes(root);
          _renderTime = sw.elapsed;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[QBZhihu] ERROR: $e');
      debugPrint('[QBZhihu] Dart stack:\n$stackTrace');
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

  int _countNodes(RenderNode node) {
    int count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('知乎首页 (高仿)'),
        actions: [
          if (_renderTime != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_renderTime!.inMilliseconds}ms · $_nodeCount nodes',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _render,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('渲染中...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _error != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('渲染错误',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error)),
                      const SizedBox(height: 8),
                      SelectableText(_error!,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.left),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _render,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _renderRoot != null
                  ? Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 375),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: QBRenderWidget(
                            root: _renderRoot!,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}
