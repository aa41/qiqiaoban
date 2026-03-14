/// 七巧板 (Qiqiaoban) — Flutter + JS 动态化引擎。
///
/// 该库提供了基于 Vue 模板语法的动态化 Flutter UI 渲染能力，
/// 通过 Rust (QuickJS) 作为逻辑层，Flutter 作为渲染层。
///
/// ## 快速开始
///
/// ```dart
/// import 'package:qiqiaoban/qiqiaoban.dart';
///
/// void main() async {
///   // 初始化七巧板引擎
///   await Qiqiaoban.init();
///
///   runApp(const MyApp());
/// }
/// ```
library;

// 导出公开 API
export 'src/qb_bundle_config.dart';
export 'src/qb_bundle_manager.dart';
export 'src/qb_component_widget.dart';
export 'src/qb_devtools.dart';
export 'src/qb_engine.dart';
export 'src/qb_error_handler.dart';
export 'src/qb_hot_reload.dart';
export 'src/qb_logger.dart';
export 'src/qb_render_widget.dart';
export 'src/qb_widget_factory.dart';
export 'src/rust/api/compiler_api.dart'
    show compileTemplate, compileAndCreateComponent;
export 'src/rust/api/component_api.dart'
    show createComponent, callComponentMethod, destroyComponent;
export 'src/rust/api/error_api.dart'
    show safeCompileTemplate, getRecentErrors;
export 'src/rust/api/poc_render.dart' show RenderNode, renderFromJs;
export 'src/rust/api/vnode_api.dart' show renderVnodeFromJs, renderVnodeFromJson;
