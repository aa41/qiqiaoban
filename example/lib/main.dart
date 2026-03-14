import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

import 'pages/api_test_page.dart';
import 'pages/compiler_demo_page.dart';
import 'pages/component_demo_page.dart';
import 'pages/component_test_page.dart';
import 'pages/devtools_demo_page.dart';
import 'pages/engine_demo_page.dart';
import 'pages/error_demo_page.dart';
import 'pages/render_demo_page.dart';
import 'pages/zhihu_demo_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Qiqiaoban.init();
  runApp(const QiqiaobanExampleApp());
}

/// 七巧板完整示例应用 — 涵盖 Phase 1-4 所有功能。
class QiqiaobanExampleApp extends StatelessWidget {
  const QiqiaobanExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '七巧板示例',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// 首页 — 功能目录。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('七巧板 Qiqiaoban'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showAbout(context),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '运行时信息',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _RuntimeInfoCard()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '功能演示',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _DemoItem(
                icon: Icons.code,
                color: Colors.blue,
                title: 'JS 引擎',
                subtitle: 'QuickJS 创建/执行/销毁 + 事件通信',
                page: const EngineDemoPage(),
              ),
              _DemoItem(
                icon: Icons.dashboard,
                color: Colors.teal,
                title: 'Flexbox 渲染',
                subtitle: 'JS 定义 → Rust 布局 → Flutter 绘制',
                page: const RenderDemoPage(),
              ),
              _DemoItem(
                icon: Icons.build_circle,
                color: Colors.deepPurple,
                title: 'Vue 模板编译',
                subtitle: '模板 → AST → JS render 函数',
                page: const CompilerDemoPage(),
              ),
              _DemoItem(
                icon: Icons.widgets,
                color: Colors.orange,
                title: '交互式 UI (信息流)',
                subtitle: '商业级信息流: Feed + 热榜 + 事件交互',
                page: const ComponentDemoPage(),
              ),
              _DemoItem(
                icon: Icons.grid_view_rounded,
                color: Colors.green,
                title: '组件测试',
                subtitle: '26 种微信组件属性预览: 表单/视图/内容',
                page: const ComponentTestPage(),
              ),
              _DemoItem(
                icon: Icons.error_outline,
                color: Colors.red,
                title: '错误处理 & 安全',
                subtitle: '结构化错误捕获 + 沙箱校验',
                page: const ErrorDemoPage(),
              ),
              _DemoItem(
                icon: Icons.bug_report,
                color: Colors.deepPurple,
                title: 'DevTools 面板',
                subtitle: '调试浮层: State / VNode / 性能',
                page: const DevToolsDemoPage(),
              ),
              _DemoItem(
                icon: Icons.api,
                color: Colors.cyan,
                title: 'QQB API 测试',
                subtitle: '平台 API 功能验证: 网络/存储/文件/界面',
                page: const ApiTestPage(),
              ),
              const Divider(indent: 16, endIndent: 16),
              _DemoItem(
                icon: Icons.phone_android,
                color: Colors.blue.shade700,
                title: '知乎首页 (高仿)',
                subtitle: '真实复杂页面: 导航+Feed流+热榜+底栏',
                page: const ZhihuDemoPage(),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '七巧板 Qiqiaoban',
      applicationVersion: 'v0.1.0',
      children: [
        const Text('Flutter + Rust (QuickJS) 动态化引擎'),
        const SizedBox(height: 8),
        Text('Rust Core: ${Qiqiaoban.rustCoreVersion}'),
      ],
    );
  }
}

/// 运行时信息卡片。
class _RuntimeInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Rust Core v${Qiqiaoban.rustCoreVersion}',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已初始化',
                    style: TextStyle(
                        fontSize: 11, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'JS 引擎: ${Qiqiaoban.activeEngineCount} 活跃',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '验证: ${Qiqiaoban.greet("七巧板")}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能列表项。
class _DemoItem extends StatelessWidget {
  const _DemoItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}
