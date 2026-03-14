import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'qb_bundle_config.dart';
import 'qb_logger.dart';

/// 七巧板 Bundle 管理器 — JS Bundle 加载/缓存/校验。
///
/// 支持多来源加载:
/// - 网络下载 (HTTP/HTTPS)
/// - Flutter Assets
/// - 本地文件
///
/// 并提供 LRU 内存缓存、磁盘缓存、SHA256 完整性校验。
///
/// ```dart
/// final bundle = await QBBundleManager.load(QBBundleConfig(
///   url: 'https://cdn.example.com/counter.js',
///   checksum: 'sha256:e3b0c44...',
/// ));
/// print(bundle.content); // JS 代码
/// ```
class QBBundleManager {
  QBBundleManager._();

  // ---------------------------------------------------------------------------
  // 配置
  // ---------------------------------------------------------------------------

  /// 内存缓存最大条目数。
  static int maxMemoryCacheEntries = 20;

  /// 磁盘缓存目录 (需调用方设置，否则不启用磁盘缓存)。
  static String? diskCacheDir;

  // ---------------------------------------------------------------------------
  // 缓存
  // ---------------------------------------------------------------------------

  static final Map<String, _CacheEntry> _memoryCache = {};

  // ---------------------------------------------------------------------------
  // 公开 API
  // ---------------------------------------------------------------------------

  /// 加载 Bundle (自动选择最优来源)。
  ///
  /// 优先级: 内存缓存 → 磁盘缓存 → Asset → 本地文件 → 网络
  static Future<QBBundleResult> load(QBBundleConfig config) async {
    final sw = QBLogger.startTimer('bundle-load');
    final key = config.effectiveCacheKey;

    try {
      // 1. 内存缓存
      final cached = _getFromMemory(key, config.maxCacheAge);
      if (cached != null) {
        QBLogger.stopTimer(sw, 'bundle-load');
        QBLogger.debug('Bundle loaded from memory cache: $key');
        return QBBundleResult(
          content: cached,
          source: QBBundleSource.memoryCache,
          version: config.version,
          loadDuration: sw.elapsed,
        );
      }

      // 2. 磁盘缓存
      final diskCached = await _getFromDisk(key, config.maxCacheAge);
      if (diskCached != null) {
        _putToMemory(key, diskCached);
        QBLogger.stopTimer(sw, 'bundle-load');
        QBLogger.debug('Bundle loaded from disk cache: $key');
        return QBBundleResult(
          content: diskCached,
          source: QBBundleSource.diskCache,
          version: config.version,
          loadDuration: sw.elapsed,
        );
      }

      // 3. Asset
      if (config.assetPath != null) {
        final content = await _loadFromAsset(config.assetPath!);
        final verified = _verifyChecksum(content, config.checksum);
        _putToMemory(key, content);
        await _putToDisk(key, content);
        QBLogger.stopTimer(sw, 'bundle-load');
        return QBBundleResult(
          content: content,
          source: QBBundleSource.asset,
          version: config.version,
          checksumVerified: verified,
          loadDuration: sw.elapsed,
        );
      }

      // 4. 本地文件
      if (config.filePath != null) {
        final content = await _loadFromFile(config.filePath!);
        final verified = _verifyChecksum(content, config.checksum);
        _putToMemory(key, content);
        QBLogger.stopTimer(sw, 'bundle-load');
        return QBBundleResult(
          content: content,
          source: QBBundleSource.file,
          version: config.version,
          checksumVerified: verified,
          loadDuration: sw.elapsed,
        );
      }

      // 5. 网络
      if (config.url != null) {
        final content = await _loadFromNetwork(config.url!);
        final verified = _verifyChecksum(content, config.checksum);
        if (config.checksum != null && !verified) {
          throw Exception(
            'Checksum verification failed for ${config.url}',
          );
        }
        _putToMemory(key, content);
        await _putToDisk(key, content);
        QBLogger.stopTimer(sw, 'bundle-load');
        return QBBundleResult(
          content: content,
          source: QBBundleSource.network,
          version: config.version,
          checksumVerified: verified,
          loadDuration: sw.elapsed,
        );
      }

      throw Exception('No valid source in BundleConfig: $config');
    } catch (e) {
      QBLogger.stopTimer(sw, 'bundle-load');
      QBLogger.error('Bundle load failed: $e');
      rethrow;
    }
  }

  /// 预加载 Bundle (后台加载到缓存)。
  static Future<void> preload(QBBundleConfig config) async {
    try {
      await load(config);
      QBLogger.info('Bundle preloaded: ${config.effectiveCacheKey}');
    } catch (e) {
      QBLogger.warn('Bundle preload failed: $e');
    }
  }

  /// 批量预加载。
  static Future<void> preloadAll(List<QBBundleConfig> configs) async {
    await Future.wait(configs.map(preload));
  }

  /// 从缓存中移除指定 Bundle。
  static void evict(String cacheKey) {
    _memoryCache.remove(cacheKey);
    _evictFromDisk(cacheKey);
    QBLogger.debug('Bundle evicted: $cacheKey');
  }

  /// 清除所有缓存。
  static void clearCache() {
    _memoryCache.clear();
    _clearDiskCache();
    QBLogger.info('Bundle cache cleared');
  }

  /// 获取缓存信息。
  static Map<String, dynamic> getCacheInfo() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'maxMemoryCacheEntries': maxMemoryCacheEntries,
      'diskCacheEnabled': diskCacheDir != null,
      'keys': _memoryCache.keys.toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // 内存缓存 (LRU)
  // ---------------------------------------------------------------------------

  static String? _getFromMemory(String key, Duration maxAge) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > maxAge) {
      _memoryCache.remove(key);
      return null;
    }

    // LRU: 移到末尾
    _memoryCache.remove(key);
    _memoryCache[key] = entry;
    return entry.content;
  }

  static void _putToMemory(String key, String content) {
    // LRU 淘汰
    while (_memoryCache.length >= maxMemoryCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = _CacheEntry(
      content: content,
      timestamp: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // 磁盘缓存
  // ---------------------------------------------------------------------------

  static Future<String?> _getFromDisk(String key, Duration maxAge) async {
    if (diskCacheDir == null) return null;
    try {
      final file = File(_diskPath(key));
      if (!await file.exists()) return null;

      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > maxAge) {
        await file.delete();
        return null;
      }
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _putToDisk(String key, String content) async {
    if (diskCacheDir == null) return;
    try {
      final file = File(_diskPath(key));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } catch (e) {
      QBLogger.warn('Disk cache write failed: $e');
    }
  }

  static void _evictFromDisk(String key) {
    if (diskCacheDir == null) return;
    try {
      final file = File(_diskPath(key));
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static void _clearDiskCache() {
    if (diskCacheDir == null) return;
    try {
      final dir = Directory(diskCacheDir!);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  static String _diskPath(String key) {
    // 将 key 做简单 hash 避免文件名过长
    final hash = key.hashCode.toUnsigned(32).toRadixString(16);
    return '${diskCacheDir!}/qb_bundle_$hash.js';
  }

  // ---------------------------------------------------------------------------
  // 加载器
  // ---------------------------------------------------------------------------

  static Future<String> _loadFromAsset(String assetPath) async {
    return await rootBundle.loadString(assetPath);
  }

  static Future<String> _loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Bundle file not found: $filePath');
    }
    return await file.readAsString();
  }

  static Future<String> _loadFromNetwork(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient();

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} for $url');
      }

      final bytes = await response.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      return utf8.decode(bytes);
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // SHA256 校验
  // ---------------------------------------------------------------------------

  /// 验证内容的 SHA256 校验和。
  ///
  /// checksum 格式: 'sha256:hex_string'
  static bool _verifyChecksum(String content, String? checksum) {
    if (checksum == null) return false;

    if (!checksum.startsWith('sha256:')) {
      QBLogger.warn('Unknown checksum format: $checksum');
      return false;
    }

    final expected = checksum.substring(7).toLowerCase();
    final actual = sha256Hex(content);

    final match = actual == expected;
    if (!match) {
      QBLogger.error(
        'Checksum mismatch! Expected: $expected, Got: $actual',
      );
    }
    return match;
  }

  /// 计算 SHA256 (纯 Dart 实现，无需外部依赖)。
  static String sha256Hex(String input) {
    final data = utf8.encode(input);
    return _SHA256.hash(data);
  }
}

/// 缓存条目。
class _CacheEntry {
  _CacheEntry({required this.content, required this.timestamp});
  final String content;
  final DateTime timestamp;
}

// ---------------------------------------------------------------------------
// 纯 Dart SHA-256 实现 (无需外部 crypto 包依赖)
// ---------------------------------------------------------------------------

class _SHA256 {
  static final List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) =>
      ((x & 0xFFFFFFFF) >>> n) | ((x << (32 - n)) & 0xFFFFFFFF);

  static int _ch(int x, int y, int z) => (x & y) ^ (~x & 0xFFFFFFFF & z);
  static int _maj(int x, int y, int z) => (x & y) ^ (x & z) ^ (y & z);
  static int _sigma0(int x) => _rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22);
  static int _sigma1(int x) => _rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25);
  static int _gamma0(int x) =>
      _rotr(x, 7) ^ _rotr(x, 18) ^ ((x & 0xFFFFFFFF) >>> 3);
  static int _gamma1(int x) =>
      _rotr(x, 17) ^ _rotr(x, 19) ^ ((x & 0xFFFFFFFF) >>> 10);

  static String hash(List<int> data) {
    // Pre-processing
    final bitLen = data.length * 8;
    final msg = Uint8List.fromList(data);
    final padded = <int>[...msg, 0x80];

    while ((padded.length % 64) != 56) {
      padded.add(0);
    }

    // Append bit length as big-endian 64-bit
    for (int i = 56; i >= 0; i -= 8) {
      padded.add((bitLen >> i) & 0xFF);
    }

    // Initialize hash values
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    // Process each 512-bit block
    for (int offset = 0; offset < padded.length; offset += 64) {
      final w = List<int>.filled(64, 0);

      for (int i = 0; i < 16; i++) {
        w[i] = (padded[offset + i * 4] << 24) |
            (padded[offset + i * 4 + 1] << 16) |
            (padded[offset + i * 4 + 2] << 8) |
            padded[offset + i * 4 + 3];
      }

      for (int i = 16; i < 64; i++) {
        w[i] = (_gamma1(w[i - 2]) + w[i - 7] + _gamma0(w[i - 15]) + w[i - 16]) &
            0xFFFFFFFF;
      }

      var a = h0, b = h1, c = h2, d = h3;
      var e = h4, f = h5, g = h6, h = h7;

      for (int i = 0; i < 64; i++) {
        final t1 = (h + _sigma1(e) + _ch(e, f, g) + _k[i] + w[i]) & 0xFFFFFFFF;
        final t2 = (_sigma0(a) + _maj(a, b, c)) & 0xFFFFFFFF;
        h = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    // Produce hex digest
    String hex(int v) => v.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return '${hex(h0)}${hex(h1)}${hex(h2)}${hex(h3)}'
        '${hex(h4)}${hex(h5)}${hex(h6)}${hex(h7)}';
  }
}
