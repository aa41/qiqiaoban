import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// 组件测试演示页 — 覆盖所有 26 种微信小程序组件的属性预览。
///
/// 使用 Tab 分类导航，每个 tab 通过 JS DSL 实时渲染组件。
class ComponentTestPage extends StatefulWidget {
  const ComponentTestPage({super.key});

  @override
  State<ComponentTestPage> createState() => _ComponentTestPageState();
}

class _ComponentTestPageState extends State<ComponentTestPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    '视图容器',
    '基础内容',
    '表单组件',
    '滚动容器',
    '导航/画布',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 防止键盘弹出时重建树
      appBar: AppBar(
        title: const Text('组件测试'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabPage(jsCode: _viewContainerJs),
          _TabPage(jsCode: _basicContentJs),
          _TabPage(jsCode: _formComponentJs),
          _TabPage(jsCode: _scrollContainerJs),
          _TabPage(jsCode: _navCanvasJs),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // JS 模板: 通用辅助函数
  // ═══════════════════════════════════════════════════════════════════
  static const _jsHelpers = r'''
  var uid = 0;
  function id() { return "t" + (uid++); }

  function text(content, opts) {
    opts = opts || {};
    var s = {};
    if (opts.height) s.height = opts.height;
    if (opts.fontSize) s.fontSize = opts.fontSize;
    if (opts.color) s.color = opts.color;
    if (opts.fontWeight) s.fontWeight = opts.fontWeight;
    if (opts.flexGrow) s.flexGrow = opts.flexGrow;
    if (opts.width) s.width = opts.width;
    if (opts.textAlign) s.textAlign = opts.textAlign;
    var node = { id: id(), type: "text", text: content, style: s };
    if (opts.maxLines) node["maxLines"] = opts.maxLines;
    return node;
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
  function gap(h) { return box([], { height: h }); }
  function divider() { return box([], { height: 1, backgroundColor: "#E8E8E8" }); }

  // 组件节点工厂 — 防止 props 中的 type/id 覆盖 node.type/id
  function comp(nodeType, props, style, children) {
    var reserved = {"id":1, "type":1, "style":1, "children":1, "text":1};
    var node = { id: id(), type: nodeType, style: style || {}, children: children || [] };
    for (var k in (props||{})) {
      if (k === "type") {
        // WeChat 的 type 属性 (如 button type=primary) 存为 _type 避免覆盖 node type
        node["_type"] = String(props[k]);
      } else if (!reserved[k]) {
        node[k] = props[k];
      }
    }
    return node;
  }

  // 章节标题
  function sectionTitle(title) {
    return box([
      text(title, { fontSize: 16, color: "#333", fontWeight: "bold", height: 22 })
    ], { paddingLeft: 16, paddingTop: 16, paddingBottom: 8 });
  }

  // 子标题
  function subTitle(title) {
    return box([
      text(title, { fontSize: 13, color: "#888", height: 18 })
    ], { paddingLeft: 16, paddingTop: 8, paddingBottom: 4 });
  }

  // 白色卡片容器
  function card(children) {
    return box(children, {
      backgroundColor: "#FFFFFF",
      paddingLeft: 16, paddingRight: 16,
      paddingTop: 12, paddingBottom: 12,
      flexDirection: "column", gap: 8
    });
  }
''';

  // ═══════════════════════════════════════════════════════════════════
  // Tab 1: 视图容器 (view, scroll-view, swiper)
  // ═══════════════════════════════════════════════════════════════════
  static const _viewContainerJs = r'''
(function() {
  ''' + _jsHelpers + r'''

  var scrollView = {
    id: id(), type: "scroll-view",
    style: { flexGrow: 1, flexDirection: "column" },
    children: [

      // ── view 组件 ──
      sectionTitle("view 视图容器"),
      subTitle("基础 view — backgroundColor"),
      card([
        hStack([
          box([], { width: 60, height: 60, backgroundColor: "#FF6B6B" }),
          box([], { width: 60, height: 60, backgroundColor: "#4ECDC4" }),
          box([], { width: 60, height: 60, backgroundColor: "#45B7D1" }),
          box([], { width: 60, height: 60, backgroundColor: "#96CEB4" })
        ], { gap: 12 })
      ]),

      subTitle("borderRadius"),
      card([
        hStack([
          box([], { width: 60, height: 60, backgroundColor: "#FF6B6B", borderRadius: 0 }),
          box([], { width: 60, height: 60, backgroundColor: "#4ECDC4", borderRadius: 8 }),
          box([], { width: 60, height: 60, backgroundColor: "#45B7D1", borderRadius: 16 }),
          box([], { width: 60, height: 60, backgroundColor: "#96CEB4", borderRadius: 30 })
        ], { gap: 12 }),
        hStack([
          text("r=0", { fontSize: 11, color: "#999", width: 60, height: 14 }),
          text("r=8", { fontSize: 11, color: "#999", width: 60, height: 14 }),
          text("r=16", { fontSize: 11, color: "#999", width: 60, height: 14 }),
          text("r=30", { fontSize: 11, color: "#999", width: 60, height: 14 })
        ], { gap: 12 })
      ]),

      subTitle("opacity 不透明度"),
      card([
        hStack([
          box([text("1.0", {fontSize:11,color:"#FFF",height:14})], {width:60,height:60,backgroundColor:"#FF6B6B",opacity:1.0,justifyContent:"center",alignItems:"center"}),
          box([text("0.7", {fontSize:11,color:"#FFF",height:14})], {width:60,height:60,backgroundColor:"#FF6B6B",opacity:0.7,justifyContent:"center",alignItems:"center"}),
          box([text("0.4", {fontSize:11,color:"#FFF",height:14})], {width:60,height:60,backgroundColor:"#FF6B6B",opacity:0.4,justifyContent:"center",alignItems:"center"}),
          box([text("0.1", {fontSize:11,color:"#FFF",height:14})], {width:60,height:60,backgroundColor:"#FF6B6B",opacity:0.1,justifyContent:"center",alignItems:"center"})
        ], { gap: 12 })
      ]),

      subTitle("嵌套 view + flexDirection"),
      card([
        hStack([
          vStack([
            box([], { width: 40, height: 40, backgroundColor: "#E8E8E8" }),
            box([], { width: 40, height: 40, backgroundColor: "#CCCCCC" }),
            box([], { width: 40, height: 40, backgroundColor: "#AAAAAA" })
          ], { gap: 4, backgroundColor: "#F5F5F5", paddingTop: 4, paddingBottom: 4, paddingLeft: 4, paddingRight: 4 }),
          vStack([
            hStack([
              box([], { width: 30, height: 30, backgroundColor: "#FFD93D" }),
              box([], { width: 30, height: 30, backgroundColor: "#FF6B6B" })
            ], { gap: 4 }),
            hStack([
              box([], { width: 30, height: 30, backgroundColor: "#4ECDC4" }),
              box([], { width: 30, height: 30, backgroundColor: "#45B7D1" })
            ], { gap: 4 })
          ], { gap: 4, backgroundColor: "#F5F5F5", paddingTop: 4, paddingBottom: 4, paddingLeft: 4, paddingRight: 4 })
        ], { gap: 12 })
      ]),

      gap(8),
      divider(),

      // ── scroll-view 组件 ──
      sectionTitle("scroll-view 滚动视图"),
      subTitle("垂直滚动 (默认)"),
      card([
        {
          id: id(), type: "scroll-view",
          style: { height: 120, flexDirection: "column", backgroundColor: "#F5F5F5" },
          children: [
            box([text("Item 1", {fontSize:14,color:"#333",height:18})], {height:40,backgroundColor:"#FFF",paddingLeft:12,justifyContent:"center"}),
            box([], {height:1,backgroundColor:"#EEE"}),
            box([text("Item 2", {fontSize:14,color:"#333",height:18})], {height:40,backgroundColor:"#FFF",paddingLeft:12,justifyContent:"center"}),
            box([], {height:1,backgroundColor:"#EEE"}),
            box([text("Item 3", {fontSize:14,color:"#333",height:18})], {height:40,backgroundColor:"#FFF",paddingLeft:12,justifyContent:"center"}),
            box([], {height:1,backgroundColor:"#EEE"}),
            box([text("Item 4", {fontSize:14,color:"#333",height:18})], {height:40,backgroundColor:"#FFF",paddingLeft:12,justifyContent:"center"}),
            box([], {height:1,backgroundColor:"#EEE"}),
            box([text("Item 5 (滚动查看)", {fontSize:14,color:"#999",height:18})], {height:40,backgroundColor:"#FFF",paddingLeft:12,justifyContent:"center"}),
            box([], {height:1,backgroundColor:"#EEE"}),
            box([text("Item 6", {fontSize:14,color:"#333",height:18})], {height:40,backgroundColor:"#FFF",paddingLeft:12,justifyContent:"center"})
          ]
        }
      ]),

      subTitle("水平滚动 (scroll-x)"),
      card([
        {
          id: id(), type: "scroll-view", "scroll-x": true,
          style: { height: 80, flexDirection: "row", gap: 8 },
          children: [
            box([text("A",{fontSize:16,color:"#FFF",height:20})], {width:80,height:70,backgroundColor:"#FF6B6B",justifyContent:"center",alignItems:"center",borderRadius:8}),
            box([text("B",{fontSize:16,color:"#FFF",height:20})], {width:80,height:70,backgroundColor:"#4ECDC4",justifyContent:"center",alignItems:"center",borderRadius:8}),
            box([text("C",{fontSize:16,color:"#FFF",height:20})], {width:80,height:70,backgroundColor:"#45B7D1",justifyContent:"center",alignItems:"center",borderRadius:8}),
            box([text("D",{fontSize:16,color:"#FFF",height:20})], {width:80,height:70,backgroundColor:"#96CEB4",justifyContent:"center",alignItems:"center",borderRadius:8}),
            box([text("E",{fontSize:16,color:"#FFF",height:20})], {width:80,height:70,backgroundColor:"#FFD93D",justifyContent:"center",alignItems:"center",borderRadius:8}),
            box([text("← 滑动 →",{fontSize:12,color:"#FFF",height:16})], {width:80,height:70,backgroundColor:"#DDA0DD",justifyContent:"center",alignItems:"center",borderRadius:8})
          ]
        }
      ]),

      gap(8),
      divider(),

      // ── swiper 组件 ──
      sectionTitle("swiper 轮播"),
      subTitle("默认轮播 (indicator-dots)"),
      card([
        comp("swiper", { "indicator-dots": true }, { height: 150, backgroundColor: "#F5F5F5" }, [
          box([text("Page 1", {fontSize:18,color:"#FFF",height:24})], {backgroundColor:"#FF6B6B",justifyContent:"center",alignItems:"center"}),
          box([text("Page 2", {fontSize:18,color:"#FFF",height:24})], {backgroundColor:"#4ECDC4",justifyContent:"center",alignItems:"center"}),
          box([text("Page 3", {fontSize:18,color:"#FFF",height:24})], {backgroundColor:"#45B7D1",justifyContent:"center",alignItems:"center"})
        ])
      ]),

      gap(24)
    ]
  };

  return vStack([scrollView], {
    width: "100%",
    height: "100%",
    backgroundColor: "#F5F6F7"
  });
})()
  ''';

  // ═══════════════════════════════════════════════════════════════════
  // Tab 2: 基础内容 (text, icon, rich-text)
  // ═══════════════════════════════════════════════════════════════════
  static const _basicContentJs = r'''
(function() {
  ''' + _jsHelpers + r'''

  var scrollView = {
    id: id(), type: "scroll-view",
    style: { flexGrow: 1, flexDirection: "column" },
    children: [

      // ── text 组件 ──
      sectionTitle("text 文本"),

      subTitle("fontSize"),
      card([
        vStack([
          text("fontSize: 12", { fontSize: 12, color: "#333", height: 16 }),
          text("fontSize: 14 (默认)", { fontSize: 14, color: "#333", height: 18 }),
          text("fontSize: 18", { fontSize: 18, color: "#333", height: 24 }),
          text("fontSize: 24", { fontSize: 24, color: "#333", height: 32 }),
          text("fontSize: 32", { fontSize: 32, color: "#333", height: 42 })
        ], { gap: 4 })
      ]),

      subTitle("color"),
      card([
        hStack([
          text("红色", { fontSize: 14, color: "#FF4D4F", height: 18 }),
          text("蓝色", { fontSize: 14, color: "#1890FF", height: 18 }),
          text("绿色", { fontSize: 14, color: "#52C41A", height: 18 }),
          text("橙色", { fontSize: 14, color: "#FA8C16", height: 18 }),
          text("紫色", { fontSize: 14, color: "#722ED1", height: 18 })
        ], { gap: 12 })
      ]),

      subTitle("fontWeight 字重"),
      card([
        vStack([
          text("默认字重 normal", { fontSize: 16, color: "#333" }),
          text("中等字重 medium 500", { fontSize: 16, color: "#333", fontWeight: "500" }),
          text("半粗字重 semibold 600", { fontSize: 16, color: "#333", fontWeight: "600" }),
          text("粗体字重 bold 700", { fontSize: 16, color: "#333", fontWeight: "bold" }),
          text("特粗字重 heavy 900", { fontSize: 16, color: "#333", fontWeight: "900" })
        ], { gap: 8 })
      ]),

      subTitle("多行文本 & maxLines"),
      card([
        vStack([
          text("这是一段较长的文本，用于测试多行文本渲染能力。Rust 布局引擎会自动估算文本换行高度，不需要手动设置 height。当文本超过容器宽度时会自动换行。", { fontSize: 14, color: "#333" }),
          gap(8),
          text("maxLines=2: 这段文本设置了maxLines为2，超出部分将被截断显示省略号。如果文本内容超过两行，多余的内容不会显示。", { fontSize: 14, color: "#666", maxLines: 2 }),
          gap(8),
          text("maxLines=1: 单行文本超出显示省略号。这是一段很长的文本。", { fontSize: 14, color: "#999", maxLines: 1 })
        ], { gap: 0 })
      ]),

      subTitle("textAlign 对齐"),
      card([
        vStack([
          box([text("左对齐 (默认)", { fontSize: 14, color: "#333", height: 18 })], { backgroundColor: "#F5F5F5", paddingTop: 4, paddingBottom: 4, paddingLeft: 8, paddingRight: 8 }),
          box([text("居中对齐 center", { fontSize: 14, color: "#333", height: 18, textAlign: "center" })], { backgroundColor: "#F5F5F5", paddingTop: 4, paddingBottom: 4, paddingLeft: 8, paddingRight: 8 }),
          box([text("右对齐 right", { fontSize: 14, color: "#333", height: 18, textAlign: "right" })], { backgroundColor: "#F5F5F5", paddingTop: 4, paddingBottom: 4, paddingLeft: 8, paddingRight: 8 })
        ], { gap: 4 })
      ]),

      gap(8),
      divider(),

      // ── icon 组件 ──
      sectionTitle("icon 图标"),
      subTitle("type — 微信内置图标"),
      card([
        hStack([
          vStack([
            comp("icon", { _type: "success" }, { width: 32, height: 32 }),
            text("success", { fontSize: 10, color: "#999", height: 14 })
          ], { alignItems: "center", gap: 4 }),
          vStack([
            comp("icon", { _type: "info" }, { width: 32, height: 32 }),
            text("info", { fontSize: 10, color: "#999", height: 14 })
          ], { alignItems: "center", gap: 4 }),
          vStack([
            comp("icon", { _type: "warn" }, { width: 32, height: 32 }),
            text("warn", { fontSize: 10, color: "#999", height: 14 })
          ], { alignItems: "center", gap: 4 }),
          vStack([
            comp("icon", { _type: "waiting" }, { width: 32, height: 32 }),
            text("waiting", { fontSize: 10, color: "#999", height: 14 })
          ], { alignItems: "center", gap: 4 }),
          vStack([
            comp("icon", { _type: "cancel" }, { width: 32, height: 32 }),
            text("cancel", { fontSize: 10, color: "#999", height: 14 })
          ], { alignItems: "center", gap: 4 }),
          vStack([
            comp("icon", { _type: "download" }, { width: 32, height: 32 }),
            text("download", { fontSize: 10, color: "#999", height: 14 })
          ], { alignItems: "center", gap: 4 })
        ], { gap: 10 })
      ]),

      subTitle("size"),
      card([
        hStack([
          comp("icon", { _type: "success", size: "20" }, { width: 20, height: 20 }),
          comp("icon", { _type: "success", size: "28" }, { width: 28, height: 28 }),
          comp("icon", { _type: "success", size: "36" }, { width: 36, height: 36 }),
          comp("icon", { _type: "success", size: "48" }, { width: 48, height: 48 })
        ], { gap: 16 })
      ]),

      subTitle("color"),
      card([
        hStack([
          comp("icon", { _type: "success", color: "#FF4D4F" }, { width: 32, height: 32 }),
          comp("icon", { _type: "success", color: "#1890FF" }, { width: 32, height: 32 }),
          comp("icon", { _type: "success", color: "#52C41A" }, { width: 32, height: 32 }),
          comp("icon", { _type: "success", color: "#722ED1" }, { width: 32, height: 32 })
        ], { gap: 16 })
      ]),

      gap(8),
      divider(),

      // ── rich-text 组件 ──
      sectionTitle("rich-text 富文本"),
      subTitle("nodes — 结构化富文本"),
      card([
        comp("rich-text", {
          nodes: JSON.stringify([
            { text: "这是 ", attrs: { style: "font-size:14px;color:#333" } },
            { text: "加粗", attrs: { style: "font-weight:bold;color:#FF4D4F" } },
            { text: " 和 ", attrs: {} },
            { text: "斜体", attrs: { style: "font-style:italic;color:#1890FF" } },
            { text: " 以及 ", attrs: {} },
            { text: "下划线", attrs: { style: "text-decoration:underline;color:#52C41A" } },
            { text: " 混排文本。", attrs: {} }
          ])
        }, { height: 30 })
      ]),

      gap(24)
    ]
  };

  return vStack([scrollView], {
    width: "100%",
    height: "100%",
    backgroundColor: "#F5F6F7"
  });
})()
  ''';

  // ═══════════════════════════════════════════════════════════════════
  // Tab 3: 表单组件
  // ═══════════════════════════════════════════════════════════════════
  static const _formComponentJs = r'''
(function() {
  ''' + _jsHelpers + r'''

  var scrollView = {
    id: id(), type: "scroll-view",
    style: { flexGrow: 1, flexDirection: "column" },
    children: [

      // ── button 按钮 ──
      sectionTitle("button 按钮"),
      subTitle("type — primary / default / warn"),
      card([
        vStack([
          comp("button", { _type: "primary" }, { height: 44 },
            [text("Primary 按钮", { fontSize: 16, color: "#FFF", height: 20 })]),
          comp("button", { _type: "default" }, { height: 44 },
            [text("Default 按钮", { fontSize: 16, color: "#000", height: 20 })]),
          comp("button", { _type: "warn" }, { height: 44 },
            [text("Warn 按钮", { fontSize: 16, color: "#FFF", height: 20 })])
        ], { gap: 8 })
      ]),

      subTitle("size=mini"),
      card([
        hStack([
          comp("button", { _type: "primary", size: "mini" }, { height: 30 },
            [text("Mini", { fontSize: 13, color: "#FFF", height: 16 })]),
          comp("button", { _type: "default", size: "mini" }, { height: 30 },
            [text("Mini", { fontSize: 13, color: "#000", height: 16 })]),
          comp("button", { _type: "warn", size: "mini" }, { height: 30 },
            [text("Mini", { fontSize: 13, color: "#FFF", height: 16 })])
        ], { gap: 8 })
      ]),

      subTitle("plain / disabled / loading"),
      card([
        vStack([
          comp("button", { _type: "primary", plain: true }, { height: 44 },
            [text("Plain 镂空按钮", { fontSize: 16, color: "#07C160", height: 20 })]),
          comp("button", { _type: "primary", disabled: true }, { height: 44 },
            [text("Disabled 禁用", { fontSize: 16, color: "#FFF", height: 20 })]),
          comp("button", { _type: "primary", loading: true }, { height: 44 },
            [text("Loading 加载中", { fontSize: 16, color: "#FFF", height: 20 })])
        ], { gap: 8 })
      ]),

      gap(8),
      divider(),

      // ── input 输入框 ──
      sectionTitle("input 输入框"),
      subTitle("type — text / number / password"),
      card([
        vStack([
          hStack([
            text("文本:", { fontSize: 14, color: "#333", width: 60, height: 18 }),
            comp("input", { _type: "text", placeholder: "请输入文本" }, { flexGrow: 1, height: 36, backgroundColor: "#F5F5F5" })
          ]),
          hStack([
            text("数字:", { fontSize: 14, color: "#333", width: 60, height: 18 }),
            comp("input", { _type: "number", placeholder: "请输入数字" }, { flexGrow: 1, height: 36, backgroundColor: "#F5F5F5" })
          ]),
          hStack([
            text("密码:", { fontSize: 14, color: "#333", width: 60, height: 18 }),
            comp("input", { _type: "password", password: true, placeholder: "请输入密码" }, { flexGrow: 1, height: 36, backgroundColor: "#F5F5F5" })
          ]),
          hStack([
            text("禁用:", { fontSize: 14, color: "#999", width: 60, height: 18 }),
            comp("input", { disabled: true, placeholder: "禁用状态" }, { flexGrow: 1, height: 36, backgroundColor: "#F5F5F5" })
          ])
        ], { gap: 8 })
      ]),

      gap(8),
      divider(),

      // ── textarea 多行输入 ──
      sectionTitle("textarea 多行输入"),
      card([
        comp("textarea", {
          placeholder: "请输入多行文本...",
          maxlength: "200"
        }, { height: 100, backgroundColor: "#F5F5F5" }),
        comp("textarea", {
          placeholder: "禁用状态的多行输入",
          disabled: true
        }, { height: 60, backgroundColor: "#F5F5F5" })
      ]),

      gap(8),
      divider(),

      // ── checkbox 复选框 ──
      sectionTitle("checkbox 复选框"),
      subTitle("checkbox-group + checkbox"),
      card([
        comp("checkbox-group", {}, { flexDirection: "column", gap: 8 }, [
          comp("checkbox", { value: "apple", checked: true, color: "#07C160" }, { height: 30 }),
          comp("checkbox", { value: "banana" }, { height: 30 }),
          comp("checkbox", { value: "grape", disabled: true }, { height: 30 })
        ])
      ]),

      gap(8),
      divider(),

      // ── radio 单选按钮 ──
      sectionTitle("radio 单选按钮"),
      subTitle("radio-group + radio"),
      card([
        comp("radio-group", {}, { flexDirection: "column", gap: 8 }, [
          comp("radio", { value: "male", checked: true, color: "#1890FF" }, { height: 30 }),
          comp("radio", { value: "female" }, { height: 30 }),
          comp("radio", { value: "other", disabled: true }, { height: 30 })
        ])
      ]),

      gap(8),
      divider(),

      // ── slider 滑条 ──
      sectionTitle("slider 滑条"),
      subTitle("基础 / show-value / step / 自定义颜色"),
      card([
        vStack([
          hStack([
            text("默认:", { fontSize: 13, color: "#666", width: 60, height: 16 }),
            comp("slider", { value: "30" }, { flexGrow: 1, height: 30 })
          ]),
          hStack([
            text("显示值:", { fontSize: 13, color: "#666", width: 60, height: 16 }),
            comp("slider", { value: "50", "show-value": true }, { flexGrow: 1, height: 30 })
          ]),
          hStack([
            text("步长10:", { fontSize: 13, color: "#666", width: 60, height: 16 }),
            comp("slider", { value: "40", step: "10", "show-value": true }, { flexGrow: 1, height: 30 })
          ]),
          hStack([
            text("颜色:", { fontSize: 13, color: "#666", width: 60, height: 16 }),
            comp("slider", {
              value: "60",
              "show-value": true,
              activeColor: "#FF4D4F",
              backgroundColor: "#FFE0E0"
            }, { flexGrow: 1, height: 30 })
          ]),
          hStack([
            text("禁用:", { fontSize: 13, color: "#666", width: 60, height: 16 }),
            comp("slider", { value: "70", disabled: true }, { flexGrow: 1, height: 30 })
          ])
        ], { gap: 4 })
      ]),

      gap(8),
      divider(),

      // ── switch 开关 ──
      sectionTitle("switch 开关"),
      subTitle("type=switch / type=checkbox / checked / disabled / color"),
      card([
        vStack([
          hStack([
            text("默认:", { fontSize: 13, color: "#666", width: 80, height: 16 }),
            comp("switch", { checked: true }, { width: 52, height: 30 })
          ]),
          hStack([
            text("未选中:", { fontSize: 13, color: "#666", width: 80, height: 16 }),
            comp("switch", { checked: false }, { width: 52, height: 30 })
          ]),
          hStack([
            text("自定义色:", { fontSize: 13, color: "#666", width: 80, height: 16 }),
            comp("switch", { checked: true, color: "#FF4D4F" }, { width: 52, height: 30 })
          ]),
          hStack([
            text("禁用:", { fontSize: 13, color: "#666", width: 80, height: 16 }),
            comp("switch", { checked: true, disabled: true }, { width: 52, height: 30 })
          ]),
          hStack([
            text("checkbox:", { fontSize: 13, color: "#666", width: 80, height: 16 }),
            comp("switch", { _type: "checkbox", checked: true }, { width: 24, height: 24 })
          ])
        ], { gap: 8 })
      ]),

      gap(8),
      divider(),

      // ── picker 选择器 ──
      sectionTitle("picker 选择器"),
      subTitle("picker-view 嵌入式选择器"),
      card([
        comp("picker-view", {
          range: JSON.stringify(["北京","上海","广州","深圳","杭州","成都","武汉","南京"])
        }, { height: 120 })
      ]),

      gap(24)
    ]
  };

  return vStack([scrollView], {
    width: "100%",
    height: "100%",
    backgroundColor: "#F5F6F7"
  });
})()
  ''';

  // ═══════════════════════════════════════════════════════════════════
  // Tab 4: 滚动容器 (list-view, grid-view, draggable-sheet)
  // ═══════════════════════════════════════════════════════════════════
  static const _scrollContainerJs = r'''
(function() {
  ''' + _jsHelpers + r'''

  // 生成列表项
  function listItem(index, color) {
    return hStack([
      box([], { width: 40, height: 40, backgroundColor: color, borderRadius: 20 }),
      vStack([
        text("列表项 " + index, { fontSize: 14, color: "#333", height: 18 }),
        text("描述信息 #" + index, { fontSize: 12, color: "#999", height: 16 })
      ], { gap: 2, flexGrow: 1 })
    ], { gap: 12, height: 56, paddingLeft: 16, paddingRight: 16, backgroundColor: "#FFFFFF" });
  }

  // 生成网格项
  function gridItem(label, color) {
    return vStack([
      box([], { width: 50, height: 50, backgroundColor: color, borderRadius: 8 }),
      text(label, { fontSize: 12, color: "#666", height: 16 })
    ], { alignItems: "center", gap: 6, width: 80, height: 80 });
  }

  var colors = ["#FF6B6B","#4ECDC4","#45B7D1","#96CEB4","#FFD93D","#DDA0DD","#FA8C16","#722ED1"];

  var scrollView = {
    id: id(), type: "scroll-view",
    style: { flexGrow: 1, flexDirection: "column" },
    children: [

      // ── list-view ──
      sectionTitle("list-view 列表"),
      subTitle("可滚动列表 (height: 200)"),
      card([
        comp("list-view", {}, { height: 200, flexDirection: "column" }, [
          listItem("1", colors[0]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("2", colors[1]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("3", colors[2]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("4", colors[3]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("5", colors[4]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("6", colors[5]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("7", colors[6]),
          box([], {height:1,backgroundColor:"#F0F0F0"}),
          listItem("8", colors[7])
        ])
      ]),

      gap(8),
      divider(),

      // ── grid-view ──
      sectionTitle("grid-view 网格"),
      subTitle("网格布局"),
      card([
        comp("grid-view", {}, { height: 200, flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "center" }, [
          gridItem("相册", colors[0]),
          gridItem("音乐", colors[1]),
          gridItem("视频", colors[2]),
          gridItem("文档", colors[3]),
          gridItem("下载", colors[4]),
          gridItem("收藏", colors[5]),
          gridItem("设置", colors[6]),
          gridItem("更多", colors[7])
        ])
      ]),

      gap(8),
      divider(),

      // ── draggable-sheet ──
      sectionTitle("draggable-sheet 可拖拽面板"),
      subTitle("可上下拖拽展开/收起"),
      card([
        box([
          comp("draggable-sheet", {
            "initial-child-size": "0.4",
            "min-child-size": "0.2",
            "max-child-size": "0.9"
          }, { height: 200, backgroundColor: "#F5F5F5", flexDirection: "column", alignItems: "center" }, [
            box([
              box([], { width: 40, height: 4, backgroundColor: "#DDD", borderRadius: 2 })
            ], { flexDirection: "row", justifyContent: "center", paddingTop: 8, paddingBottom: 8, height: 20 }),
            box([
              text("拖拽手柄区域", { fontSize: 14, color: "#666", height: 18 })
            ], { paddingLeft: 16, paddingTop: 4, height: 26 }),
            box([
              text("内容区域 — 向上拖拽展开", { fontSize: 13, color: "#999", height: 18 })
            ], { paddingLeft: 16, paddingTop: 4, height: 26 })
          ])
        ], { height: 200, backgroundColor: "#E8E8E8", borderRadius: 8 })
      ]),

      gap(24)
    ]
  };

  return vStack([scrollView], {
    width: "100%",
    height: "100%",
    backgroundColor: "#F5F6F7"
  });
})()
  ''';

  // ═══════════════════════════════════════════════════════════════════
  // Tab 5: 导航 + 画布
  // ═══════════════════════════════════════════════════════════════════
  static const _navCanvasJs = r'''
(function() {
  ''' + _jsHelpers + r'''

  var scrollView = {
    id: id(), type: "scroll-view",
    style: { flexGrow: 1, flexDirection: "column" },
    children: [

      // ── navigator ──
      sectionTitle("navigator 导航"),
      subTitle("点击触发导航事件"),
      card([
        vStack([
          comp("navigator", { url: "/pages/index" }, {
            height: 44, backgroundColor: "#F5F5F5",
            flexDirection: "row", alignItems: "center",
            paddingLeft: 16, paddingRight: 16
          }, [
            text("跳转到首页", { fontSize: 14, color: "#1890FF", height: 18, flexGrow: 1 }),
            text("›", { fontSize: 18, color: "#CCC", height: 22 })
          ]),
          box([], {height:1,backgroundColor:"#E8E8E8"}),
          comp("navigator", { url: "/pages/detail", "open-type": "navigate" }, {
            height: 44, backgroundColor: "#F5F5F5",
            flexDirection: "row", alignItems: "center",
            paddingLeft: 16, paddingRight: 16
          }, [
            text("navigate 详情页", { fontSize: 14, color: "#1890FF", height: 18, flexGrow: 1 }),
            text("›", { fontSize: 18, color: "#CCC", height: 22 })
          ]),
          box([], {height:1,backgroundColor:"#E8E8E8"}),
          comp("navigator", { url: "/pages/list", "open-type": "redirect" }, {
            height: 44, backgroundColor: "#F5F5F5",
            flexDirection: "row", alignItems: "center",
            paddingLeft: 16, paddingRight: 16
          }, [
            text("redirect 列表页", { fontSize: 14, color: "#FA8C16", height: 18, flexGrow: 1 }),
            text("›", { fontSize: 18, color: "#CCC", height: 22 })
          ]),
          box([], {height:1,backgroundColor:"#E8E8E8"}),
          comp("navigator", { url: "/pages/back", "open-type": "navigateBack" }, {
            height: 44, backgroundColor: "#F5F5F5",
            flexDirection: "row", alignItems: "center",
            paddingLeft: 16, paddingRight: 16
          }, [
            text("navigateBack 返回", { fontSize: 14, color: "#FF4D4F", height: 18, flexGrow: 1 }),
            text("›", { fontSize: 18, color: "#CCC", height: 22 })
          ])
        ], { gap: 0 })
      ]),

      gap(8),
      divider(),

      // ── canvas ──
      sectionTitle("canvas 画布"),
      subTitle("canvas-id — 画布占位 (实际绘制需 JS Bridge)"),
      card([
        comp("canvas", { "canvas-id": "myCanvas" }, {
          width: 300, height: 200, backgroundColor: "#FAFAFA"
        }),
        text("canvas-id: myCanvas", { fontSize: 12, color: "#999", height: 16 }),
        text("画布绘制需通过 JS-Dart Bridge 通信，当前为占位渲染", { fontSize: 12, color: "#999" })
      ]),

      gap(8),
      divider(),

      // ── form 容器 ──
      sectionTitle("form 表单容器"),
      subTitle("form 包裹表单元素"),
      card([
        comp("form", {}, { flexDirection: "column", gap: 12 }, [
          hStack([
            text("姓名:", { fontSize: 14, color: "#333", width: 60, height: 18 }),
            comp("input", { placeholder: "请输入姓名" }, { flexGrow: 1, height: 36, backgroundColor: "#F5F5F5" })
          ]),
          hStack([
            text("性别:", { fontSize: 14, color: "#333", width: 60, height: 18 }),
            comp("radio-group", {}, { flexDirection: "row", gap: 16, flexGrow: 1, flexShrink: 1 }, [
              comp("radio", { value: "M", checked: true }, { height: 30 }),
              comp("radio", { value: "F" }, { height: 30 })
            ])
          ]),
          hStack([
            text("爱好:", { fontSize: 14, color: "#333", width: 60, height: 18 }),
            comp("checkbox-group", {}, { flexDirection: "row", gap: 12, flexGrow: 1, flexShrink: 1 }, [
              comp("checkbox", { value: "code", checked: true }, { height: 30 }),
              comp("checkbox", { value: "music" }, { height: 30 })
            ])
          ]),
          comp("button", { _type: "primary" }, { height: 44 },
            [text("提交表单", { fontSize: 16, color: "#FFF", height: 20 })])
        ])
      ]),

      gap(24)
    ]
  };

  return vStack([scrollView], {
    width: "100%",
    height: "100%",
    backgroundColor: "#F5F6F7"
  });
})()
  ''';
}

// ═══════════════════════════════════════════════════════════════════
// 单个 Tab 页面 — 独立渲染一个 JS 模板
// ═══════════════════════════════════════════════════════════════════
class _TabPage extends StatefulWidget {
  const _TabPage({required this.jsCode});
  final String jsCode;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with AutomaticKeepAliveClientMixin {
  RenderNode? _root;
  String? _error;
  bool _loading = true;

  double _viewportWidth = 375;
  double _viewportHeight = 600;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  String _buildJs() {
    return widget.jsCode;
  }

  Future<void> _render() async {
    setState(() { _loading = true; _error = null; });

    try {
      final root = await renderFromJs(
        jsCode: _buildJs(),
        viewportWidth: _viewportWidth,
        viewportHeight: _viewportHeight,
      );

      if (mounted) {
        setState(() { _root = root; _loading = false; });
      }
    } catch (e) {
      debugPrint('[ComponentTest] Error: $e');
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  void _handleEvent(String nodeId, String eventName, Map<String, dynamic>? extra) {
    final msg = 'Event: $eventName on $nodeId';
    debugPrint('[ComponentTest] $msg');
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            SelectableText(_error!, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _render, icon: const Icon(Icons.refresh), label: const Text('重试')),
          ],
        ),
      );
    }

    if (_root == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final newW = constraints.maxWidth.clamp(0.0, 430.0);
        // 只在宽度变化时重渲染 — 防止键盘弹出导致高度变化时无限重建
        if ((_viewportWidth - newW).abs() > 1) {
          _viewportWidth = newW;
          _viewportHeight = constraints.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _render();
          });
        }
        return Center(
          child: QBRenderWidget(root: _root!, onEvent: _handleEvent),
        );
      },
    );
  }
}
