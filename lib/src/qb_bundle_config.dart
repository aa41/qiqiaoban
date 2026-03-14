/// Bundle 配置 — JS Bundle 的元数据定义。
///
/// ```dart
/// final config = QBBundleConfig(
///   url: 'https://cdn.example.com/bundles/counter.js',
///   version: '1.0.0',
///   checksum: 'sha256:abc123...',
/// );
/// ```
class QBBundleConfig {
  const QBBundleConfig({
    this.url,
    this.assetPath,
    this.filePath,
    this.version,
    this.checksum,
    this.maxCacheAge = const Duration(days: 7),
    this.cacheKey,
  }) : assert(
          url != null || assetPath != null || filePath != null,
          'Must specify at least one of url, assetPath, or filePath',
        );

  /// 远端 Bundle URL (HTTP/HTTPS)。
  final String? url;

  /// Flutter asset 路径 (如 'bundles/counter.js')。
  final String? assetPath;

  /// 本地文件路径。
  final String? filePath;

  /// Bundle 版本号。
  final String? version;

  /// SHA256 校验和 (格式: 'sha256:hex_string')。
  final String? checksum;

  /// 缓存最大存活时间。
  final Duration maxCacheAge;

  /// 自定义缓存键 (默认使用 URL/path)。
  final String? cacheKey;

  /// 获取缓存键。
  String get effectiveCacheKey =>
      cacheKey ?? url ?? assetPath ?? filePath ?? 'unknown';

  @override
  String toString() => 'QBBundleConfig($effectiveCacheKey, v$version)';
}

/// Bundle 加载结果。
class QBBundleResult {
  const QBBundleResult({
    required this.content,
    required this.source,
    this.version,
    this.checksumVerified = false,
    this.loadDuration,
  });

  /// JS 代码内容。
  final String content;

  /// 加载来源。
  final QBBundleSource source;

  /// 版本号。
  final String? version;

  /// 校验和是否通过验证。
  final bool checksumVerified;

  /// 加载耗时。
  final Duration? loadDuration;

  @override
  String toString() =>
      'QBBundleResult(${source.name}, ${content.length} bytes, v$version)';
}

/// Bundle 来源。
enum QBBundleSource {
  /// 内存缓存。
  memoryCache,

  /// 磁盘缓存。
  diskCache,

  /// Flutter Asset。
  asset,

  /// 本地文件。
  file,

  /// 网络下载。
  network,
}
