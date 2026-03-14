import 'dart:convert';

import 'qb_logger.dart';

/// 七巧板错误处理器 — 全链路错误捕获与上报。
///
/// 所有组件生命周期错误、编译错误、运行时错误统一收集。
///
/// ```dart
/// QBErrorHandler.onError = (error) {
///   print('QB Error: ${error.source} - ${error.message}');
///   // 上报到 Sentry / 自定义服务
/// };
/// ```
class QBErrorHandler {
  QBErrorHandler._();

  /// 全局错误回调。
  static void Function(QBErrorInfo error)? onError;

  /// 最近的错误记录。
  static final List<QBErrorInfo> recentErrors = [];

  /// 最大错误记录条数。
  static int maxErrors = 50;

  /// 错误去重窗口 (相同 message 在此时间内不重复记录)。
  static Duration deduplicateWindow = const Duration(seconds: 5);

  // ---------------------------------------------------------------------------
  // 报告方法
  // ---------------------------------------------------------------------------

  /// 报告编译错误。
  static void reportCompileError(String message, {String? template}) {
    _report(QBErrorInfo(
      source: QBErrorSource.compile,
      message: message,
      details: template != null ? {'template': template} : null,
    ));
  }

  /// 报告运行时错误。
  static void reportRuntimeError(
    String message, {
    int? componentId,
    String? stack,
  }) {
    _report(QBErrorInfo(
      source: QBErrorSource.runtime,
      message: message,
      componentId: componentId,
      stack: stack,
    ));
  }

  /// 报告渲染错误。
  static void reportRenderError(
    String message, {
    int? componentId,
  }) {
    _report(QBErrorInfo(
      source: QBErrorSource.render,
      message: message,
      componentId: componentId,
    ));
  }

  /// 报告网络错误。
  static void reportNetworkError(String message, {String? url}) {
    _report(QBErrorInfo(
      source: QBErrorSource.network,
      message: message,
      details: url != null ? {'url': url} : null,
    ));
  }

  /// 从 Rust 结构化错误 JSON 报告。
  static void reportFromJson(String errorJson) {
    try {
      final map = jsonDecode(errorJson) as Map<String, dynamic>;
      _report(QBErrorInfo(
        source: QBErrorSource.values.firstWhere(
          (s) => s.name == map['source'],
          orElse: () => QBErrorSource.runtime,
        ),
        message: map['message'] as String? ?? 'Unknown error',
        componentId: map['component_id'] as int?,
        stack: map['stack'] as String?,
      ));
    } catch (_) {
      _report(QBErrorInfo(
        source: QBErrorSource.runtime,
        message: errorJson,
      ));
    }
  }

  /// 清除所有错误记录。
  static void clear() => recentErrors.clear();

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  static void _report(QBErrorInfo error) {
    // 去重
    if (_isDuplicate(error)) return;

    recentErrors.add(error);
    if (recentErrors.length > maxErrors) {
      recentErrors.removeAt(0);
    }

    QBLogger.error('[${error.source.name}] ${error.message}');
    onError?.call(error);
  }

  static bool _isDuplicate(QBErrorInfo error) {
    final cutoff = DateTime.now().subtract(deduplicateWindow);
    return recentErrors.any((e) =>
        e.message == error.message &&
        e.source == error.source &&
        e.timestamp.isAfter(cutoff));
  }
}

/// 错误信息。
class QBErrorInfo {
  QBErrorInfo({
    required this.source,
    required this.message,
    this.componentId,
    this.stack,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final QBErrorSource source;
  final String message;
  final int? componentId;
  final String? stack;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  @override
  String toString() => '[${source.name}] $message';
}

/// 错误来源分类。
enum QBErrorSource {
  compile,
  runtime,
  render,
  network,
}
