import 'package:flutter/foundation.dart';

import 'qb_engine.dart';
import 'qb_logger.dart';

/// 七巧板 Hot Reload 管理器 — 开发模式下支持模板/script 热更新。
///
/// 当 template 或 script 变更时，自动重编译 render 函数并触发组件 re-render,
/// 无需完全重建组件实例（保留 state）。
///
/// ```dart
/// // 组件实例注册
/// QBHotReloadManager.register(componentId, template, script);
///
/// // 更新模板 → 自动 re-render
/// QBHotReloadManager.hotReload(componentId, newTemplate: '...');
/// ```
class QBHotReloadManager {
  QBHotReloadManager._();

  /// 是否启用 Hot Reload (仅在 debug 模式下生效)。
  static bool enabled = kDebugMode;

  /// 已注册的组件信息。
  static final Map<int, _ComponentInfo> _components = {};

  /// Hot Reload 事件回调。
  static void Function(int componentId, String newVnodeJson)? onReloaded;

  /// 注册组件实例。
  static void register(int componentId, String template, String script) {
    _components[componentId] = _ComponentInfo(
      template: template,
      script: script,
    );
    QBLogger.debug('HotReload: registered component $componentId');
  }

  /// 取消注册。
  static void unregister(int componentId) {
    _components.remove(componentId);
    QBLogger.debug('HotReload: unregistered component $componentId');
  }

  /// 热更新组件。
  ///
  /// 重新编译模板，替换组件的 render 函数，触发 re-render。
  /// 组件的 data/state 保持不变。
  static Future<String?> hotReload(
    int componentId, {
    String? newTemplate,
    String? newScript,
  }) async {
    if (!enabled) return null;

    final info = _components[componentId];
    if (info == null) {
      QBLogger.warn('HotReload: component $componentId not registered');
      return null;
    }

    final template = newTemplate ?? info.template;
    final sw = QBLogger.startTimer('hot-reload-compile');

    try {
      // 1. 编译新模板
      final renderFn = await Qiqiaoban.compileTemplate(template: template);

      QBLogger.stopTimer(sw, 'hot-reload-compile');

      // 2. 替换组件的 render 函数 (保留 state)
      final replaceCode = '''
        (function() {
          var comp = __qb_components[$componentId];
          if (!comp) return JSON.stringify(null);
          comp.options.render = $renderFn;
          comp._rerender();
          return JSON.stringify(comp.__currentVNode);
        })()
      ''';

      final result = await Qiqiaoban.evalComponentJs(code: replaceCode);

      // 3. 更新注册信息
      _components[componentId] = _ComponentInfo(
        template: template,
        script: newScript ?? info.script,
      );

      QBLogger.info('HotReload: component $componentId reloaded');
      onReloaded?.call(componentId, result);

      return result;
    } catch (e) {
      QBLogger.error('HotReload failed: $e');
      return null;
    }
  }

  /// 清除所有注册。
  static void clear() {
    _components.clear();
  }
}

class _ComponentInfo {
  _ComponentInfo({required this.template, required this.script});
  final String template;
  final String script;
}
