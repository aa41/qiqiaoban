import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// Demo 4: 交互式 UI 综合演示 — 微博/知乎风格信息流 + 事件系统。
class ComponentDemoPage extends StatefulWidget {
  const ComponentDemoPage({super.key});

  @override
  State<ComponentDemoPage> createState() => _ComponentDemoPageState();
}

class _ComponentDemoPageState extends State<ComponentDemoPage> {
  RenderNode? _renderRoot;
  String? _error;
  bool _isLoading = true;
  bool _isRunning = false;
  int _nodeCount = 0;
  Duration? _renderTime;

  double _viewportWidth = 375;
  double _viewportHeight = 812;

  // ─────────────────────────────────────────────────────────────
  // 交互 UI JS 代码 — 微博/知乎风信息流 + 丰富事件
  // ─────────────────────────────────────────────────────────────
  // JS 通过 __VIEWPORT_WIDTH__ / __VIEWPORT_HEIGHT__ 获取实际视口尺寸
  static const _jsTemplate = r'''
(function() {
  var uid = 0;
  function id() { return "ui" + (uid++); }

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
  function divider(color) { return box([], { height: 1, backgroundColor: color || "#F0F0F0" }); }
  function gap(h) { return box([], { height: h, backgroundColor: "#F5F6F7" }); }

  // scroll-view — 可滚动容器 (类似小程序 <scroll-view>)
  function scrollView(children, style) {
    var s = { flexDirection: "column" };
    for (var k in (style||{})) s[k] = style[k];
    return { id: id(), type: "scroll-view", style: s, children: children || [] };
  }

  function avatar(size, color) {
    return box([], { width: size, height: size, backgroundColor: color || "#E8E8E8" });
  }

  function badge(label, bgColor, textColor) {
    return box([
      text(label, { fontSize: 10, color: textColor || "#FFF", height: 14, fontWeight: "bold" })
    ], { paddingLeft: 6, paddingRight: 6, paddingTop: 2, paddingBottom: 2, backgroundColor: bgColor || "#FF6B6B" });
  }

  function iconBtn(emoji, label, color) {
    return hStack([
      text(emoji, { fontSize: 14, height: 18, color: color || "#999" }),
      text(label, { fontSize: 11, color: color || "#999", height: 14 })
    ], { gap: 4 });
  }

  // ═══════════════════════════════════════════════════════════
  // ✦ 状态栏
  // ═══════════════════════════════════════════════════════════
  var statusBar = hStack([
    text("9:41", { fontSize: 14, color: "#000", fontWeight: "bold", height: 18 }),
    spacer(),
    text("●●●●○  ⚡ 92%", { fontSize: 11, color: "#000", height: 14 })
  ], { height: 44, paddingLeft: 24, paddingRight: 24, backgroundColor: "#FFFFFF" });

  // ═══════════════════════════════════════════════════════════
  // ✦ 顶部搜索栏 + Tab
  // ═══════════════════════════════════════════════════════════
  var searchBar = hStack([
    hStack([
      text("🔍", { fontSize: 14, height: 18, color: "#BDBDBD" }),
      text("搜索你感兴趣的内容...", { fontSize: 13, color: "#BDBDBD", height: 18 })
    ], { flexGrow: 1, height: 36, backgroundColor: "#F5F5F5", paddingLeft: 12, paddingRight: 12, gap: 6 }),
    box([text("📷", { fontSize: 18, color: "#333", height: 22 })], { width: 40, height: 36, justifyContent: "center", alignItems: "center" }),
    box([text("📝", { fontSize: 18, color: "#333", height: 22 })], { width: 40, height: 36, justifyContent: "center", alignItems: "center" })
  ], { height: 52, paddingLeft: 16, paddingRight: 8, backgroundColor: "#FFFFFF", gap: 4 });

  var tabBar = hStack([
    text("关注", { fontSize: 15, color: "#666", height: 20 }),
    vStack([
      text("推荐", { fontSize: 16, color: "#222", fontWeight: "bold", height: 22 }),
      box([], { width: 24, height: 3, backgroundColor: "#1890FF" })
    ], { alignItems: "center", gap: 2 }),
    text("热榜", { fontSize: 15, color: "#666", height: 20 }),
    text("视频", { fontSize: 15, color: "#666", height: 20 }),
    text("直播", { fontSize: 15, color: "#666", height: 20 }),
    spacer(),
    text("⋮", { fontSize: 20, color: "#999", height: 24 })
  ], { height: 44, paddingLeft: 20, paddingRight: 16, backgroundColor: "#FFFFFF", gap: 20 });

  // ═══════════════════════════════════════════════════════════
  // ✦ 置顶公告 (可点击)
  // ═══════════════════════════════════════════════════════════
  var announcement = hStack([
    badge("置顶", "#FF4D4F", "#FFF"),
    text("七巧板 v0.1.0 发布 — Rust + Flutter 动态化引擎", { fontSize: 13, color: "#333", flexGrow: 1, height: 18 }),
    text("›", { fontSize: 18, color: "#CCC", height: 22 })
  ], { height: 42, paddingLeft: 16, paddingRight: 16, backgroundColor: "#FFFBE6", gap: 8 });

  // ═══════════════════════════════════════════════════════════
  // ✦ Feed 卡片 1 — 图文混排 + 交互按钮
  // ═══════════════════════════════════════════════════════════
  function feedCard(authorName, authorTag, title, content, imageColor, likeCount, commentCount, time) {
    return vStack([
      // 作者行
      hStack([
        avatar(36, "#" + Math.floor(Math.random() * 0xCCCCCC + 0x333333).toString(16)),
        vStack([
          hStack([
            text(authorName, { fontSize: 14, color: "#222", fontWeight: "bold", height: 18 }),
            badge(authorTag, "#E6F7FF", "#1890FF")
          ], { gap: 6 }),
          text(time + " · 点击阅读全文", { fontSize: 11, color: "#BDBDBD", height: 14 })
        ], { gap: 2 }),
        spacer(),
        text("⋯", { fontSize: 18, color: "#CCC", height: 22 })
      ], { gap: 10, paddingTop: 14, paddingLeft: 16, paddingRight: 16 }),

      // 标题
      box([
        text(title, { fontSize: 16, color: "#222", fontWeight: "bold", height: 22 })
      ], { paddingLeft: 16, paddingRight: 16, paddingTop: 8 }),

      // 正文
      box([
        text(content, { fontSize: 14, color: "#666", height: 20 })
      ], { paddingLeft: 16, paddingRight: 16, paddingTop: 4 }),

      // 配图
      box([], { height: 160, backgroundColor: imageColor, marginLeft: 16, marginRight: 16, marginTop: 8 }),

      // 互动栏 — Tap 区域
      hStack([
        iconBtn("👍", likeCount, "#666"),
        iconBtn("💬", commentCount, "#666"),
        iconBtn("⭐", "收藏", "#666"),
        spacer(),
        iconBtn("↗", "分享", "#999")
      ], { height: 40, paddingLeft: 16, paddingRight: 16, gap: 24 }),

      divider("#F0F0F0")
    ], { backgroundColor: "#FFFFFF" });
  }

  var feed1 = feedCard(
    "前端小智", "优质回答者",
    "为什么 Rust 正在取代 C++ 成为系统编程首选？",
    "从内存安全到并发模型，Rust 解决了 C++ 几十年来的痛点。零成本抽象让性能毫不妥协，所有权系统从编译期就消除了数据竞争...",
    "#E3F2FD", "2.4k", "186", "3小时前"
  );

  var feed2 = feedCard(
    "Flutter 中文", "官方账号",
    "Flutter 3.24 发布 — Impeller 引擎全面启用",
    "全新的 Impeller 渲染引擎在 iOS 和 Android 上均已默认启用，带来了更流畅的动画和更少的卡顿。同时，Web 平台的 CanvasKit 性能也有显著提升...",
    "#E8F5E9", "5.1k", "342", "6小时前"
  );

  var feed3 = feedCard(
    "设计乘数", "创作者",
    "2024 年最值得关注的 10 个 UI 设计趋势",
    "从玻璃态到 3D 混合界面，设计世界正在经历一场革命。AI 辅助设计工具让原型迭代速度提升了 10 倍，个性化体验成为新标准...",
    "#FFF3E0", "1.8k", "95", "12小时前"
  );

  // ═══════════════════════════════════════════════════════════
  // ✦ 热榜模块
  // ═══════════════════════════════════════════════════════════
  function hotItem(rank, title, heat, isHot) {
    var rankColor = rank <= 3 ? "#FF4D4F" : "#999";
    return hStack([
      text(rank.toString(), { fontSize: 16, color: rankColor, fontWeight: "bold", width: 24, height: 22 }),
      vStack([
        text(title, { fontSize: 14, color: "#222", height: 20 }),
        text(heat + " 万热度", { fontSize: 11, color: "#BDBDBD", height: 14 })
      ], { flexGrow: 1, gap: 2 }),
      isHot ? badge("热", "#FF4D4F") : text("", { height: 1 })
    ], { height: 52, paddingLeft: 16, paddingRight: 16, gap: 12 });
  }

  var hotSection = vStack([
    hStack([
      text("🔥", { fontSize: 16, height: 20 }),
      text("热榜", { fontSize: 16, color: "#222", fontWeight: "bold", height: 22 }),
      spacer(),
      text("查看全部 ›", { fontSize: 12, color: "#1890FF", height: 16 })
    ], { height: 44, paddingLeft: 16, paddingRight: 16, gap: 6 }),
    divider("#F5F5F5"),
    hotItem(1, "国产大模型首次在多项基准超越 GPT-4", "856", true),
    hotItem(2, "重磅：全国统一大市场建设方案公布", "724", true),
    hotItem(3, "程序员 35 岁危机是伪命题？", "651", true),
    hotItem(4, "SpaceX 星舰第五次试飞成功回收", "423", false),
    hotItem(5, "苹果 Vision Pro 中国发售日期确认", "387", false)
  ], { backgroundColor: "#FFFFFF" });

  // ═══════════════════════════════════════════════════════════
  // ✦ 话题推荐
  // ═══════════════════════════════════════════════════════════
  function topicCard(emoji, title, desc, bgColor) {
    return vStack([
      text(emoji, { fontSize: 28, height: 36 }),
      text(title, { fontSize: 13, color: "#222", fontWeight: "bold", height: 18 }),
      text(desc, { fontSize: 11, color: "#999", height: 14 })
    ], { width: 110, height: 100, backgroundColor: bgColor, paddingTop: 12, paddingLeft: 10, paddingRight: 10, gap: 4, alignItems: "center" });
  }

  var topicSection = vStack([
    hStack([
      text("📌", { fontSize: 14, height: 18 }),
      text("推荐话题", { fontSize: 15, color: "#222", fontWeight: "bold", height: 20 }),
      spacer(),
      text("换一换", { fontSize: 12, color: "#1890FF", height: 16 })
    ], { height: 40, paddingLeft: 16, paddingRight: 16, gap: 6 }),
    hStack([
      topicCard("🚀", "科技前沿", "12.8k 讨论", "#EDE7F6"),
      topicCard("🎨", "设计美学", "8.4k 讨论", "#E0F7FA"),
      topicCard("💼", "职场成长", "15.2k 讨论", "#FFF3E0")
    ], { paddingLeft: 16, paddingRight: 16, gap: 10, paddingBottom: 12 })
  ], { backgroundColor: "#FFFFFF" });

  // ═══════════════════════════════════════════════════════════
  // ✦ 更多 Feed 卡片
  // ═══════════════════════════════════════════════════════════
  var feed4 = feedCard(
    "产品沉思录", "签约作者",
    "从 0 到 1 构建一个跨端 DSL 引擎的思考",
    "本文将分享我们在构建七巧板引擎过程中的架构决策：为什么选择 Rust + QuickJS，如何设计 VNode 协议，怎样实现零拷贝的 FFI 通信...",
    "#F3E5F5", "964", "73", "1天前"
  );

  var feed5 = feedCard(
    "硅谷密探", "认证媒体",
    "OpenAI CEO：AGI 将在两年内实现",
    "Sam Altman 在最新访谈中表示，通用人工智能比多数人预想的要来得更快。他认为 GPT-5 将是一个重要里程碑，但真正的 AGI 需要全新架构...",
    "#FFEBEE", "8.7k", "1.2k", "2天前"
  );

  // ═══════════════════════════════════════════════════════════
  // ✦ 底部导航栏
  // ═══════════════════════════════════════════════════════════
  function navItem(emoji, label, isActive) {
    var color = isActive ? "#1890FF" : "#999";
    return vStack([
      text(emoji, { fontSize: 20, color: color, height: 24 }),
      text(label, { fontSize: 10, color: color, height: 12 })
    ], { alignItems: "center", gap: 2, flexGrow: 1 });
  }

  var bottomNav = hStack([
    navItem("🏠", "首页", true),
    navItem("🔔", "通知", false),
    box([text("＋", { fontSize: 24, color: "#FFF", height: 28 })], {
      width: 44, height: 44, backgroundColor: "#1890FF", justifyContent: "center", alignItems: "center"
    }),
    navItem("💬", "消息", false),
    navItem("👤", "我的", false)
  ], { height: 56, backgroundColor: "#FFFFFF", paddingLeft: 8, paddingRight: 8, alignItems: "center" });
  bottomNav.id = "bottom-nav";

  // ═══════════════════════════════════════════════════════════
  // ✦ 组装完整页面
  // ═══════════════════════════════════════════════════════════
  var root = vStack([
    statusBar,
    searchBar,
    tabBar,
    divider("#EEEEEE"),

    // 可滚动内容区域 — DSL 层面声明 scroll 行为
    scrollView([
      announcement,
      gap(8),
      feed1,
      gap(8),
      feed2,
      gap(8),
      topicSection,
      gap(8),
      feed3,
      gap(8),
      hotSection,
      gap(8),
      feed4,
      gap(8),
      feed5,
    ], { flexGrow: 1 }),

    divider("#EEEEEE"),
    bottomNav
  ], { width: __VIEWPORT_WIDTH__, height: __VIEWPORT_HEIGHT__, backgroundColor: "#F5F6F7" });

  return root;
})()
  ''';

  /// 生成 JS 代码，将视口尺寸注入 JS
  String _buildJs() {
    return _jsTemplate
        .replaceAll('__VIEWPORT_WIDTH__', _viewportWidth.toInt().toString())
        .replaceAll('__VIEWPORT_HEIGHT__', _viewportHeight.toInt().toString());
  }

  // ─────────────────────────────────────────────────────────
  // 渲染逻辑
  // ─────────────────────────────────────────────────────────
  Future<void> _render() async {
    if (_isRunning) return;
    _isRunning = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sw = Stopwatch()..start();
      final root = await renderFromJs(
        jsCode: _buildJs(),
        viewportWidth: _viewportWidth,
        viewportHeight: _viewportHeight,
      );
      sw.stop();

      if (mounted) {
        setState(() {
          _renderRoot = root;
          _nodeCount = _countNodes(root);
          _renderTime = sw.elapsed;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[QBInteractive] ERROR: $e\n$stackTrace');
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
        title: const Text('交互式 UI (信息流)'),
        actions: [
          if (_renderTime != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _render),
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
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '渲染错误',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _error!,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
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
          ? LayoutBuilder(
              builder: (context, constraints) {
                // 首次获取约束时保存视口尺寸，如果尺寸变化则重新渲染
                final newH = constraints.maxHeight;
                final newW = constraints.maxWidth.clamp(0.0, 375.0);
                if ((_viewportHeight - newH).abs() > 1 ||
                    (_viewportWidth - newW).abs() > 1) {
                  _viewportWidth = newW;
                  _viewportHeight = newH;
                  // 延迟重新渲染，避免在 build 中直接 setState
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _render();
                  });
                }
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: QBRenderWidget(root: _renderRoot!),
                  ),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }
}
