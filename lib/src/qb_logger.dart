import 'package:flutter/foundation.dart';

/// 七巧板日志系统 — 统一日志输出和性能追踪。
///
/// 支持分级日志和编译/渲染耗时记录。
///
/// ```dart
/// QBLogger.info('Component created');
/// final stopwatch = QBLogger.startTimer('compile');
/// // ... 编译操作 ...
/// QBLogger.stopTimer(stopwatch, 'compile');
/// ```
class QBLogger {
  QBLogger._();

  /// 日志级别。
  static QBLogLevel level = QBLogLevel.info;

  /// 自定义日志输出。设置后替代默认 debugPrint。
  static void Function(String message, QBLogLevel level)? customOutput;

  /// 是否启用性能追踪。
  static bool enablePerfTracking = kDebugMode;

  /// 最近的性能指标记录。
  static final List<QBPerfEntry> perfEntries = [];

  /// 性能记录最大条数。
  static int maxPerfEntries = 100;

  // ---------------------------------------------------------------------------
  // 日志方法
  // ---------------------------------------------------------------------------

  static void debug(String message) => _log(message, QBLogLevel.debug);
  static void info(String message) => _log(message, QBLogLevel.info);
  static void warn(String message) => _log(message, QBLogLevel.warn);
  static void error(String message) => _log(message, QBLogLevel.error);

  // ---------------------------------------------------------------------------
  // 性能追踪
  // ---------------------------------------------------------------------------

  /// 开始计时。
  static Stopwatch startTimer(String label) {
    final sw = Stopwatch()..start();
    return sw;
  }

  /// 结束计时并记录。
  static Duration stopTimer(Stopwatch stopwatch, String label) {
    stopwatch.stop();
    final duration = stopwatch.elapsed;

    if (enablePerfTracking) {
      final entry = QBPerfEntry(
        label: label,
        duration: duration,
        timestamp: DateTime.now(),
      );
      perfEntries.add(entry);
      if (perfEntries.length > maxPerfEntries) {
        perfEntries.removeAt(0);
      }
      debug('⏱ $label: ${duration.inMilliseconds}ms');
    }

    return duration;
  }

  /// 清除性能记录。
  static void clearPerfEntries() => perfEntries.clear();

  // ---------------------------------------------------------------------------
  // 内部
  // ---------------------------------------------------------------------------

  static void _log(String message, QBLogLevel lvl) {
    if (lvl.index < level.index) return;

    final prefix = switch (lvl) {
      QBLogLevel.debug => '🔍 [QB-DEBUG]',
      QBLogLevel.info => 'ℹ️ [QB-INFO]',
      QBLogLevel.warn => '⚠️ [QB-WARN]',
      QBLogLevel.error => '❌ [QB-ERROR]',
    };

    if (customOutput != null) {
      customOutput!('$prefix $message', lvl);
    } else {
      debugPrint('$prefix $message');
    }
  }
}

/// 日志级别。
enum QBLogLevel { debug, info, warn, error }

/// 性能记录条目。
class QBPerfEntry {
  QBPerfEntry({
    required this.label,
    required this.duration,
    required this.timestamp,
  });

  final String label;
  final Duration duration;
  final DateTime timestamp;

  @override
  String toString() =>
      '[$label] ${duration.inMilliseconds}ms @ $timestamp';
}
