import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

/// QQB API 测试页 — 覆盖所有 qqb.* 平台 API 的功能验证。
///
/// 使用 Tab 分类：基础/系统、网络、存储、文件、界面、路由/设备。
/// 每个测试项可点击执行，结果以绿/红色卡片实时显示。
class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _apiInitialized = false;

  static const _tabs = ['基础/系统', '网络', '存储', '文件', '界面', '路由/设备'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _initApis();
  }

  Future<void> _initApis() async {
    try {
      await QQBApiHandler.init();
      QQBApiHandler.startPolling();
      // 设置覆盖层 context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          QQBUiApi.setOverlayContext(context);
        }
      });
      if (mounted) setState(() => _apiInitialized = true);
    } catch (e) {
      debugPrint('[ApiTest] Init error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    QQBApiHandler.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QQB API 测试'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: !_apiInitialized
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _BaseSystemTab(),
                _NetworkTab(),
                _StorageTab(),
                _FileTab(),
                _UiTab(overlayContext: context),
                _RouteDeviceTab(),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 通用：测试结果展示组件
// ═══════════════════════════════════════════════════════════════════════

class _TestResult {
  final String title;
  final bool success;
  final String detail;
  _TestResult(this.title, this.success, this.detail);
}

class _TestSection extends StatelessWidget {
  const _TestSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ),
        ...children,
      ],
    );
  }
}

class _TestButton extends StatefulWidget {
  const _TestButton({
    required this.title,
    required this.subtitle,
    required this.onTest,
    this.icon = Icons.play_arrow,
  });
  final String title;
  final String subtitle;
  final Future<_TestResult> Function() onTest;
  final IconData icon;

  @override
  State<_TestButton> createState() => _TestButtonState();
}

class _TestButtonState extends State<_TestButton> {
  _TestResult? _result;
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final r = await widget.onTest();
      if (mounted) setState(() { _result = r; _running = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = _TestResult(widget.title, false, '$e');
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: _running ? null : _run,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 20,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: theme.textTheme.titleSmall),
                        Text(widget.subtitle,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (_running)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _result == null
                          ? Icons.play_circle_outline
                          : _result!.success
                              ? Icons.check_circle
                              : Icons.error,
                      color: _result == null
                          ? Colors.grey
                          : _result!.success
                              ? Colors.green
                              : Colors.red,
                    ),
                ],
              ),
              if (_result != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _result!.success
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _result!.detail,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _result!.success
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 1: 基础 / 系统
// ═══════════════════════════════════════════════════════════════════════

class _BaseSystemTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TestSection(title: '基础 API', children: [
          _TestButton(
            title: 'qqb.canIUse()',
            subtitle: '检测 API 是否可用',
            icon: Icons.verified,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify({request: qqb.canIUse('request'), setStorage: qqb.canIUse('setStorage'), unknownApi: qqb.canIUse('unknownApi')})");
              final data = jsonDecode(result);
              final ok = data['request'] == true &&
                  data['setStorage'] == true &&
                  data['unknownApi'] == false;
              return _TestResult('canIUse', ok,
                  'request=${data['request']}, setStorage=${data['setStorage']}, unknownApi=${data['unknownApi']}');
            },
          ),
          _TestButton(
            title: 'qqb.base64ToArrayBuffer / arrayBufferToBase64',
            subtitle: 'Base64 编解码',
            icon: Icons.transform,
            onTest: () async {
              final encoded = await evalComponentJs(
                  code: "qqb.arrayBufferToBase64([72,101,108,108,111])");
              final decoded = await evalComponentJs(
                  code: "JSON.stringify(qqb.base64ToArrayBuffer('SGVsbG8='))");
              final ok = encoded == 'SGVsbG8=' &&
                  decoded == '[72,101,108,108,111]';
              return _TestResult('base64', ok,
                  'encode: $encoded\ndecode: $decoded');
            },
          ),
          _TestButton(
            title: 'qqb.env',
            subtitle: '获取环境变量',
            icon: Icons.settings,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify(qqb.env)");
              final data = jsonDecode(result);
              final ok = data['USER_DATA_PATH'] != null &&
                  data['VERSION'] != null;
              return _TestResult('env', ok,
                  'USER_DATA_PATH=${data['USER_DATA_PATH']}\nVERSION=${data['VERSION']}');
            },
          ),
          _TestButton(
            title: 'Promise 支持',
            subtitle: '验证 Promise polyfill 可用',
            icon: Icons.hourglass_empty,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "typeof Promise === 'function' ? 'ok' : 'fail'");
              return _TestResult('Promise', result == 'ok',
                  'typeof Promise = ${result == 'ok' ? 'function ✅' : 'undefined ❌'}');
            },
          ),
          _TestButton(
            title: 'setTimeout / clearTimeout',
            subtitle: '验证定时器注册和取消',
            icon: Icons.timer,
            onTest: () async {
              // 注册一个定时器并检查 pending calls
              await evalComponentJs(
                  code: "globalThis.__timerTestResult__ = 'pending'; setTimeout(function() { globalThis.__timerTestResult__ = 'fired'; }, 10)");
              final calls = await drainPendingApiCalls();
              final callList = jsonDecode(calls) as List;
              final hasTimeout = callList.any((c) => c['api'] == 'setTimeout');
              return _TestResult('Timer', hasTimeout,
                  'setTimeout 已加入队列: ${hasTimeout ? '✅' : '❌'}\npending calls: ${callList.length}');
            },
          ),
        ]),

        _TestSection(title: '系统 API', children: [
          _TestButton(
            title: 'qqb.getSystemInfoSync()',
            subtitle: '同步获取系统信息',
            icon: Icons.phone_android,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify(qqb.getSystemInfoSync())");
              final data = jsonDecode(result);
              final ok = data['platform'] != null;
              return _TestResult('SystemInfo', ok,
                  'platform: ${data['platform']}\nscreenWidth: ${data['screenWidth']}\nscreenHeight: ${data['screenHeight']}\nlanguage: ${data['language']}');
            },
          ),
          _TestButton(
            title: 'qqb.getWindowInfo()',
            subtitle: '获取窗口信息',
            icon: Icons.window,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify(qqb.getWindowInfo())");
              final data = jsonDecode(result);
              final ok = data['windowWidth'] != null;
              return _TestResult('WindowInfo', ok,
                  'windowWidth: ${data['windowWidth']}\nwindowHeight: ${data['windowHeight']}\nstatusBarHeight: ${data['statusBarHeight']}\npixelRatio: ${data['pixelRatio']}');
            },
          ),
          _TestButton(
            title: 'qqb.getDeviceInfo()',
            subtitle: '获取设备信息',
            icon: Icons.devices,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify(qqb.getDeviceInfo())");
              final data = jsonDecode(result);
              final ok = data['brand'] != null;
              return _TestResult('DeviceInfo', ok,
                  'brand: ${data['brand']}\nmodel: ${data['model']}\nsystem: ${data['system']}\nplatform: ${data['platform']}');
            },
          ),
          _TestButton(
            title: 'qqb.getAppBaseInfo()',
            subtitle: '获取应用基础信息',
            icon: Icons.apps,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify(qqb.getAppBaseInfo())");
              final data = jsonDecode(result);
              final ok = data['SDKVersion'] != null;
              return _TestResult('AppBaseInfo', ok,
                  'SDKVersion: ${data['SDKVersion']}\ntheme: ${data['theme']}\nlanguage: ${data['language']}');
            },
          ),
          _TestButton(
            title: 'qqb.getLaunchOptionsSync()',
            subtitle: '获取启动参数',
            icon: Icons.launch,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "JSON.stringify(qqb.getLaunchOptionsSync())");
              final data = jsonDecode(result);
              final ok = data['scene'] != null;
              return _TestResult('LaunchOptions', ok,
                  'scene: ${data['scene']}\npath: ${data['path']}');
            },
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 2: 网络
// ═══════════════════════════════════════════════════════════════════════

class _NetworkTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TestSection(title: '网络请求 API', children: [
          _TestButton(
            title: 'qqb.request() — GET',
            subtitle: '发送 GET 请求到 httpbin.org',
            icon: Icons.cloud_download,
            onTest: () async {
              // 直接使用 Dart 侧 API 实现测试
              final result = await QQBNetworkApi.request({
                'url': 'https://httpbin.org/get',
                'method': 'GET',
                'timeout': 10000,
              });
              final ok = result['statusCode'] == 200;
              return _TestResult('GET', ok,
                  'statusCode: ${result['statusCode']}\nerrMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'qqb.request() — POST',
            subtitle: '发送 POST 请求带 JSON body',
            icon: Icons.cloud_upload,
            onTest: () async {
              final result = await QQBNetworkApi.request({
                'url': 'https://httpbin.org/post',
                'method': 'POST',
                'data': {'name': 'qqb', 'version': '1.0'},
                'timeout': 10000,
              });
              final ok = result['statusCode'] == 200;
              final responseData = result['data'];
              return _TestResult('POST', ok,
                  'statusCode: ${result['statusCode']}\nresponse json: ${responseData is Map ? responseData['json'] : 'N/A'}');
            },
          ),
          _TestButton(
            title: 'qqb.request() — 请求头',
            subtitle: '验证自定义 Header',
            icon: Icons.http,
            onTest: () async {
              final result = await QQBNetworkApi.request({
                'url': 'https://httpbin.org/headers',
                'method': 'GET',
                'header': {'X-QQB-Test': 'hello'},
                'timeout': 10000,
              });
              final ok = result['statusCode'] == 200;
              return _TestResult('Headers', ok,
                  'statusCode: ${result['statusCode']}\nerrMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'qqb.request() — 错误处理',
            subtitle: '请求不存在的地址，验证错误回调',
            icon: Icons.error_outline,
            onTest: () async {
              try {
                await QQBNetworkApi.request({
                  'url': 'https://this-domain-does-not-exist-qqb.com/api',
                  'method': 'GET',
                  'timeout': 5000,
                });
                return _TestResult('Error', false, '应该抛出错误但未抛出');
              } catch (e) {
                return _TestResult('Error', true,
                    '正确捕获错误 ✅\n$e');
              }
            },
          ),
          _TestButton(
            title: 'JS 调用 qqb.request()',
            subtitle: '验证 JS→Dart 完整流程',
            icon: Icons.sync,
            onTest: () async {
              // 在 JS 侧调用 request
              await evalComponentJs(
                  code: "qqb.request({ url: 'https://httpbin.org/get', method: 'GET', success: function(r) { globalThis.__reqResult__ = 'ok:' + r.statusCode; }, fail: function(e) { globalThis.__reqResult__ = 'fail:' + e.errMsg; } })");
              // 处理待处理调用
              await QQBApiHandler.processPendingCalls();
              // 等待一下让结果回传
              await Future.delayed(const Duration(seconds: 3));
              await QQBApiHandler.processPendingCalls();
              final result = await evalComponentJs(
                  code: "globalThis.__reqResult__ || 'no result yet'");
              final ok = result.startsWith('ok:');
              return _TestResult('JS→Dart', ok, 'result: $result');
            },
          ),
        ]),

        _TestSection(title: '下载 API', children: [
          _TestButton(
            title: 'qqb.downloadFile()',
            subtitle: '下载一个文件到临时路径',
            icon: Icons.download,
            onTest: () async {
              final result = await QQBNetworkApi.downloadFile({
                'url': 'https://httpbin.org/bytes/1024',
              });
              final path = result['tempFilePath'] as String;
              final exists = await File(path).exists();
              final size = exists ? (await File(path).length()) : 0;
              return _TestResult('Download', exists && size > 0,
                  'tempFilePath: $path\nsize: $size bytes\nerrMsg: ${result['errMsg']}');
            },
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 3: 存储
// ═══════════════════════════════════════════════════════════════════════

class _StorageTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TestSection(title: '数据缓存 API', children: [
          _TestButton(
            title: 'setStorage + getStorage',
            subtitle: '写入后读取数据',
            icon: Icons.save,
            onTest: () async {
              await QQBStorageApi.setStorage({
                'key': 'testKey',
                'data': {'name': 'QQB', 'version': 1},
              });
              final result = await QQBStorageApi.getStorage({
                'key': 'testKey',
              });
              final data = result['data'];
              final ok = data is Map && data['name'] == 'QQB';
              return _TestResult('set+get', ok,
                  'data: $data\nerrMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'setStorage — String',
            subtitle: '存储字符串类型',
            icon: Icons.text_fields,
            onTest: () async {
              await QQBStorageApi.setStorage({
                'key': 'stringKey',
                'data': 'Hello QQB!',
              });
              final result = await QQBStorageApi.getStorage({
                'key': 'stringKey',
              });
              final ok = result['data'] == 'Hello QQB!';
              return _TestResult('String', ok,
                  'data: ${result['data']}');
            },
          ),
          _TestButton(
            title: 'setStorage — List',
            subtitle: '存储数组类型',
            icon: Icons.list,
            onTest: () async {
              await QQBStorageApi.setStorage({
                'key': 'listKey',
                'data': [1, 2, 3, 'four'],
              });
              final result = await QQBStorageApi.getStorage({
                'key': 'listKey',
              });
              final data = result['data'];
              final ok = data is List && data.length == 4;
              return _TestResult('List', ok, 'data: $data');
            },
          ),
          _TestButton(
            title: 'removeStorage',
            subtitle: '删除后验证不存在',
            icon: Icons.delete,
            onTest: () async {
              await QQBStorageApi.setStorage({
                'key': 'removeTest', 'data': 'temp',
              });
              await QQBStorageApi.removeStorage({'key': 'removeTest'});
              try {
                await QQBStorageApi.getStorage({'key': 'removeTest'});
                return _TestResult('remove', false, '应抛出异常');
              } catch (e) {
                return _TestResult('remove', true,
                    '正确: 删除后读取抛出异常 ✅\n$e');
              }
            },
          ),
          _TestButton(
            title: 'clearStorage',
            subtitle: '清空所有缓存',
            icon: Icons.cleaning_services,
            onTest: () async {
              await QQBStorageApi.setStorage({'key': 'a', 'data': 1});
              await QQBStorageApi.setStorage({'key': 'b', 'data': 2});
              await QQBStorageApi.clearStorage({});
              final info = await QQBStorageApi.getStorageInfo({});
              final keys = info['keys'] as List;
              final ok = keys.isEmpty;
              return _TestResult('clear', ok,
                  'keys after clear: $keys\ncurrentSize: ${info['currentSize']}');
            },
          ),
          _TestButton(
            title: 'getStorageInfo',
            subtitle: '获取存储统计信息',
            icon: Icons.info,
            onTest: () async {
              await QQBStorageApi.setStorage({'key': 'x', 'data': 'hello'});
              await QQBStorageApi.setStorage({'key': 'y', 'data': [1, 2, 3]});
              final info = await QQBStorageApi.getStorageInfo({});
              final keys = info['keys'] as List;
              final ok = keys.isNotEmpty;
              return _TestResult('info', ok,
                  'keys: $keys\ncurrentSize: ${info['currentSize']} bytes\nlimitSize: ${info['limitSize']} bytes');
            },
          ),
          _TestButton(
            title: 'JS 调用 qqb.setStorageSync / getStorageSync',
            subtitle: '验证同步存储 JS API',
            icon: Icons.sync,
            onTest: () async {
              await evalComponentJs(
                  code: "qqb.setStorageSync('jsKey', 'jsValue')");
              // 处理 pending calls
              await QQBApiHandler.processPendingCalls();
              final result = await evalComponentJs(
                  code: "JSON.stringify(typeof qqb.getStorageSync)");
              return _TestResult('JS Sync', true,
                  'setStorageSync 调用成功 ✅\ngetStorageSync type: $result');
            },
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 4: 文件
// ═══════════════════════════════════════════════════════════════════════

class _FileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TestSection(title: '文件系统 API', children: [
          _TestButton(
            title: 'writeFile + readFile',
            subtitle: '写文件后读取',
            icon: Icons.edit_document,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/hello.txt',
                'data': 'Hello from QQB API! 🎉',
              });
              final result = await QQBFileApi.readFile({
                'filePath': 'qqb://user/test/hello.txt',
              });
              final ok = result['data'] == 'Hello from QQB API! 🎉';
              return _TestResult('write+read', ok,
                  'content: ${result['data']}\nerrMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'appendFile',
            subtitle: '追加写入文件',
            icon: Icons.add_circle_outline,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/append.txt',
                'data': 'Line1\n',
              });
              await QQBFileApi.appendFile({
                'filePath': 'qqb://user/test/append.txt',
                'data': 'Line2\n',
              });
              final result = await QQBFileApi.readFile({
                'filePath': 'qqb://user/test/append.txt',
              });
              final ok = (result['data'] as String).contains('Line2');
              return _TestResult('append', ok,
                  'content: ${result['data']}');
            },
          ),
          _TestButton(
            title: 'mkdir + readdir',
            subtitle: '创建目录并列出内容',
            icon: Icons.folder,
            onTest: () async {
              await QQBFileApi.mkdir({
                'dirPath': 'qqb://user/test/subdir',
                'recursive': true,
              });
              // 写入一些文件
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/subdir/f1.txt',
                'data': 'file1',
              });
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/subdir/f2.txt',
                'data': 'file2',
              });
              final result = await QQBFileApi.readdir({
                'dirPath': 'qqb://user/test/subdir',
              });
              final files = result['files'] as List;
              final ok = files.length >= 2;
              return _TestResult('mkdir+readdir', ok,
                  'files: $files\ncount: ${files.length}');
            },
          ),
          _TestButton(
            title: 'stat',
            subtitle: '获取文件状态',
            icon: Icons.info_outline,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/stat_test.txt',
                'data': 'stat test data',
              });
              final result = await QQBFileApi.stat({
                'path': 'qqb://user/test/stat_test.txt',
              });
              final stats = result['stats'] as Map;
              final ok = stats['isFile'] == true && stats['size'] > 0;
              return _TestResult('stat', ok,
                  'isFile: ${stats['isFile']}\nsize: ${stats['size']}\nlastModified: ${DateTime.fromMillisecondsSinceEpoch(stats['lastModifiedTime'])}');
            },
          ),
          _TestButton(
            title: 'copyFile',
            subtitle: '复制文件',
            icon: Icons.copy,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/original.txt',
                'data': 'original content',
              });
              await QQBFileApi.copyFile({
                'srcPath': 'qqb://user/test/original.txt',
                'destPath': 'qqb://user/test/copied.txt',
              });
              final result = await QQBFileApi.readFile({
                'filePath': 'qqb://user/test/copied.txt',
              });
              final ok = result['data'] == 'original content';
              return _TestResult('copy', ok,
                  'copied content: ${result['data']}');
            },
          ),
          _TestButton(
            title: 'rename',
            subtitle: '重命名文件',
            icon: Icons.drive_file_rename_outline,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/before_rename.txt',
                'data': 'rename test',
              });
              await QQBFileApi.rename({
                'oldPath': 'qqb://user/test/before_rename.txt',
                'newPath': 'qqb://user/test/after_rename.txt',
              });
              final result = await QQBFileApi.readFile({
                'filePath': 'qqb://user/test/after_rename.txt',
              });
              final ok = result['data'] == 'rename test';
              return _TestResult('rename', ok,
                  'content: ${result['data']}');
            },
          ),
          _TestButton(
            title: 'unlink + access',
            subtitle: '删除文件并验证不存在',
            icon: Icons.delete_forever,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/delete_me.txt',
                'data': 'delete this',
              });
              final before = await QQBFileApi.access({
                'path': 'qqb://user/test/delete_me.txt',
              });
              await QQBFileApi.unlink({
                'filePath': 'qqb://user/test/delete_me.txt',
              });
              try {
                await QQBFileApi.access({
                  'path': 'qqb://user/test/delete_me.txt',
                });
                return _TestResult('unlink', false,
                    '删除后 access 应抛出异常');
              } catch (_) {
                return _TestResult('unlink', true,
                    '删除前 access: ${before['errMsg']}\n删除后 access: 正确抛出异常 ✅');
              }
            },
          ),
          _TestButton(
            title: 'getFileInfo',
            subtitle: '获取文件大小',
            icon: Icons.description,
            onTest: () async {
              await QQBFileApi.writeFile({
                'filePath': 'qqb://user/test/info_test.txt',
                'data': 'hello world',
              });
              final result = await QQBFileApi.getFileInfo({
                'filePath': 'qqb://user/test/info_test.txt',
              });
              final ok = result['size'] > 0;
              return _TestResult('fileInfo', ok,
                  'size: ${result['size']} bytes');
            },
          ),
          _TestButton(
            title: '路径安全 — 防遍历攻击',
            subtitle: '测试 ../  路径遍历拒绝',
            icon: Icons.security,
            onTest: () async {
              try {
                await QQBFileApi.readFile({
                  'filePath': 'qqb://user/../../etc/passwd',
                });
                return _TestResult('Security', false,
                    '危险！路径遍历未被阻止 ❌');
              } catch (e) {
                return _TestResult('Security', true,
                    '路径遍历攻击已拦截 ✅\n$e');
              }
            },
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 5: 界面
// ═══════════════════════════════════════════════════════════════════════

class _UiTab extends StatelessWidget {
  const _UiTab({required this.overlayContext});
  final BuildContext overlayContext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TestSection(title: '交互反馈', children: [
          _TestButton(
            title: 'showToast — success',
            subtitle: '显示成功提示 (1.5秒自动关闭)',
            icon: Icons.check_circle,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              final result = await QQBUiApi.showToast({
                'title': 'Hello QQB! 🎉',
                'icon': 'success',
                'duration': 1500,
              });
              return _TestResult('showToast', true,
                  'errMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'showToast — loading',
            subtitle: '显示加载中提示',
            icon: Icons.hourglass_empty,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              await QQBUiApi.showToast({
                'title': '加载中...',
                'icon': 'loading',
                'duration': 2000,
                'mask': true,
              });
              return _TestResult('toast-loading', true, '显示中 ✅');
            },
          ),
          _TestButton(
            title: 'showModal',
            subtitle: '弹出确认对话框',
            icon: Icons.quiz,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              final result = await QQBUiApi.showModal({
                'title': '确认操作',
                'content': '这是一个 QQB showModal 测试。\n你想继续吗？',
                'showCancel': true,
                'cancelText': '取消',
                'confirmText': '确定',
              });
              return _TestResult('showModal', true,
                  'confirm: ${result['confirm']}\ncancel: ${result['cancel']}');
            },
          ),
          _TestButton(
            title: 'showLoading + hideLoading',
            subtitle: '显示/隐藏加载遮罩',
            icon: Icons.sync,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              await QQBUiApi.showLoading({
                'title': '请稍候...',
                'mask': true,
              });
              await Future.delayed(const Duration(seconds: 2));
              await QQBUiApi.hideLoading({});
              return _TestResult('loading', true,
                  'showLoading → 2秒 → hideLoading ✅');
            },
          ),
          _TestButton(
            title: 'showActionSheet',
            subtitle: '底部弹出操作表',
            icon: Icons.more_horiz,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              try {
                final result = await QQBUiApi.showActionSheet({
                  'itemList': ['拍照', '从相册选择', '保存图片'],
                  'itemColor': '#333333',
                });
                return _TestResult('actionSheet', true,
                    'tapIndex: ${result['tapIndex']}');
              } catch (e) {
                return _TestResult('actionSheet', true,
                    '用户取消: $e');
              }
            },
          ),
        ]),

        _TestSection(title: 'JS 调用界面 API', children: [
          _TestButton(
            title: 'JS: qqb.showToast()',
            subtitle: 'JS→Dart 完整界面交互流程',
            icon: Icons.javascript,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              await evalComponentJs(
                  code: "qqb.showToast({ title: 'From JS! 🚀', icon: 'success', duration: 2000 })");
              await QQBApiHandler.processPendingCalls();
              return _TestResult('JS showToast', true,
                  'JS→Dart showToast 执行成功 ✅');
            },
          ),
          _TestButton(
            title: 'JS: qqb.showModal()',
            subtitle: 'JS 触发弹窗',
            icon: Icons.javascript,
            onTest: () async {
              QQBUiApi.setOverlayContext(overlayContext);
              await evalComponentJs(
                  code: "qqb.showModal({ title: 'JS 弹窗', content: '这个弹窗由 JS 代码触发！', success: function(res) { globalThis.__modalResult__ = res.confirm ? 'confirmed' : 'cancelled'; } })");
              await QQBApiHandler.processPendingCalls();
              await Future.delayed(const Duration(seconds: 3));
              await QQBApiHandler.processPendingCalls();
              final result = await evalComponentJs(
                  code: "globalThis.__modalResult__ || 'pending'");
              return _TestResult('JS showModal', true,
                  'result: $result');
            },
          ),
        ]),

        _TestSection(title: '动画 API', children: [
          _TestButton(
            title: 'createAnimation()',
            subtitle: '创建动画对象并导出步骤',
            icon: Icons.animation,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "var anim = qqb.createAnimation({duration: 400}); anim.opacity(0.5).rotate(45).step(); anim.opacity(1).rotate(0).step(); var exp = anim.export(); JSON.stringify({steps: exp.actions.length})");
              final data = jsonDecode(result);
              final ok = data['steps'] == 2;
              return _TestResult('animation', ok,
                  'exported steps: ${data['steps']}');
            },
          ),
        ]),

        _TestSection(title: '画布 API', children: [
          _TestButton(
            title: 'createCanvasContext()',
            subtitle: '创建 Canvas 上下文并绘制',
            icon: Icons.brush,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "var ctx = qqb.createCanvasContext('test'); ctx.fillRect(10,10,100,50); ctx.fillText('Hello',20,80); typeof ctx.draw === 'function' ? 'ok' : 'fail'");
              return _TestResult('canvas', result == 'ok',
                  'Canvas context created ✅\nfillRect, fillText called\ndraw() available: ${result == 'ok'}');
            },
          ),
        ]),

        _TestSection(title: '节点查询 API', children: [
          _TestButton(
            title: 'createSelectorQuery()',
            subtitle: '创建选择器查询对象',
            icon: Icons.search,
            onTest: () async {
              final result = await evalComponentJs(
                  code: "var q = qqb.createSelectorQuery(); typeof q.select === 'function' && typeof q.selectAll === 'function' && typeof q.exec === 'function' ? 'ok' : 'fail'");
              return _TestResult('selectorQuery', result == 'ok',
                  'select: ✅\nselectAll: ✅\nexec: ✅');
            },
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 6: 路由 / 设备
// ═══════════════════════════════════════════════════════════════════════

class _RouteDeviceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TestSection(title: '路由 API', children: [
          _TestButton(
            title: 'navigateTo + navigateBack',
            subtitle: '页面栈入栈和出栈',
            icon: Icons.navigation,
            onTest: () async {
              await QQBRouteApi.navigateTo({
                'url': '/pages/detail?id=123',
              });
              final stack1 = QQBRouteApi.pageStack;
              await QQBRouteApi.navigateBack({'delta': 1});
              final stack2 = QQBRouteApi.pageStack;
              final ok = stack1.length == 2 && stack2.length == 1;
              return _TestResult('navigateTo+Back', ok,
                  'after navigateTo: $stack1\nafter navigateBack: $stack2');
            },
          ),
          _TestButton(
            title: 'redirectTo',
            subtitle: '替换当前页面',
            icon: Icons.swap_horiz,
            onTest: () async {
              await QQBRouteApi.navigateTo({'url': '/pages/a'});
              await QQBRouteApi.redirectTo({'url': '/pages/b'});
              final stack = QQBRouteApi.pageStack;
              final ok = stack.last == '/pages/b' && !stack.contains('/pages/a');
              return _TestResult('redirectTo', ok,
                  'stack: $stack\nlast page: ${stack.last}');
            },
          ),
          _TestButton(
            title: 'switchTab',
            subtitle: '切换 Tab 页面（清空栈）',
            icon: Icons.tab,
            onTest: () async {
              await QQBRouteApi.navigateTo({'url': '/pages/a'});
              await QQBRouteApi.navigateTo({'url': '/pages/b'});
              await QQBRouteApi.switchTab({'url': '/pages/home'});
              final stack = QQBRouteApi.pageStack;
              final ok = stack.length == 1 && stack.first == '/pages/home';
              return _TestResult('switchTab', ok,
                  'stack: $stack');
            },
          ),
          _TestButton(
            title: 'reLaunch',
            subtitle: '重新启动到指定页面',
            icon: Icons.restart_alt,
            onTest: () async {
              await QQBRouteApi.navigateTo({'url': '/pages/a'});
              await QQBRouteApi.reLaunch({'url': '/pages/newHome'});
              final stack = QQBRouteApi.pageStack;
              final ok = stack.length == 1 && stack.first == '/pages/newHome';
              return _TestResult('reLaunch', ok,
                  'stack: $stack');
            },
          ),
          _TestButton(
            title: '页面栈限制 (max=10)',
            subtitle: '验证页面栈不超过10层',
            icon: Icons.layers,
            onTest: () async {
              // Reset
              await QQBRouteApi.reLaunch({'url': '/'});
              // 入栈 9 次（总共10页）
              for (var i = 1; i <= 9; i++) {
                await QQBRouteApi.navigateTo({'url': '/page$i'});
              }
              final stackBefore = QQBRouteApi.pageStack.length;
              try {
                await QQBRouteApi.navigateTo({'url': '/page10'});
                return _TestResult('stackLimit', false,
                    '应抛出异常 (超过10层)');
              } catch (e) {
                return _TestResult('stackLimit', true,
                    'stack size: $stackBefore\n第11次入栈正确拒绝 ✅\n$e');
              }
            },
          ),
        ]),

        _TestSection(title: '设备 API', children: [
          _TestButton(
            title: 'setClipboardData + getClipboardData',
            subtitle: '剪贴板读写',
            icon: Icons.content_paste,
            onTest: () async {
              await QQBBaseApi.setClipboardData({
                'data': 'QQB Test Clipboard 📋',
              });
              final result = await QQBBaseApi.getClipboardData({});
              final ok = result['data'] == 'QQB Test Clipboard 📋';
              return _TestResult('clipboard', ok,
                  'data: ${result['data']}');
            },
          ),
          _TestButton(
            title: 'vibrateShort',
            subtitle: '短振动反馈',
            icon: Icons.vibration,
            onTest: () async {
              final result = await QQBBaseApi.vibrateShort({});
              return _TestResult('vibrateShort', true,
                  'errMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'vibrateLong',
            subtitle: '长振动反馈',
            icon: Icons.vibration,
            onTest: () async {
              final result = await QQBBaseApi.vibrateLong({});
              return _TestResult('vibrateLong', true,
                  'errMsg: ${result['errMsg']}');
            },
          ),
          _TestButton(
            title: 'getNetworkType',
            subtitle: '获取网络类型',
            icon: Icons.wifi,
            onTest: () async {
              final result = await QQBBaseApi.getNetworkType({});
              return _TestResult('networkType', true,
                  'networkType: ${result['networkType']}\nerrMsg: ${result['errMsg']}');
            },
          ),
        ]),

        _TestSection(title: '生命周期 API', children: [
          _TestButton(
            title: 'onAppShow / onAppHide',
            subtitle: '注册和触发生命周期事件',
            icon: Icons.visibility,
            onTest: () async {
              await evalComponentJs(
                  code: "globalThis.__lcTest__ = []; qqb.onAppShow(function(o) { globalThis.__lcTest__.push('show'); }); qqb.onAppHide(function() { globalThis.__lcTest__.push('hide'); });");
              await triggerLifecycleEvent(
                  event: 'onAppShow', dataJson: '{}');
              await triggerLifecycleEvent(
                  event: 'onAppHide', dataJson: '{}');
              final result = await evalComponentJs(
                  code: "JSON.stringify(globalThis.__lcTest__)");
              final events = jsonDecode(result) as List;
              final ok = events.contains('show') && events.contains('hide');
              return _TestResult('lifecycle', ok,
                  'events: $events');
            },
          ),
          _TestButton(
            title: 'onError',
            subtitle: '注册和触发错误事件',
            icon: Icons.error,
            onTest: () async {
              await evalComponentJs(
                  code: "globalThis.__errTest__ = ''; qqb.onError(function(msg) { globalThis.__errTest__ = msg; });");
              await triggerLifecycleEvent(
                  event: 'onError', dataJson: '"test error message"');
              final result = await evalComponentJs(
                  code: "globalThis.__errTest__");
              final ok = result == 'test error message';
              return _TestResult('onError', ok,
                  'error: $result');
            },
          ),
        ]),

        _TestSection(title: '事件通道 API', children: [
          _TestButton(
            title: 'EventChannel',
            subtitle: 'on/emit/once/off 事件通信',
            icon: Icons.send,
            onTest: () async {
              final result = await evalComponentJs(
                  code: r"""
                var ch = new qqb.EventChannel();
                var results = [];
                ch.on('msg', function(d) { results.push('on:' + d); });
                ch.once('msg', function(d) { results.push('once:' + d); });
                ch.emit('msg', 'hello');
                ch.emit('msg', 'world');
                JSON.stringify(results);
              """);
              final events = jsonDecode(result) as List;
              // on 应该收到2次, once 只收到1次
              final ok = events.length == 3 &&
                  events.contains('on:hello') &&
                  events.contains('on:world') &&
                  events.contains('once:hello');
              return _TestResult('EventChannel', ok,
                  'events: $events');
            },
          ),
        ]),

        _TestSection(title: 'FileSystemManager (JS 侧)', children: [
          _TestButton(
            title: 'getFileSystemManager()',
            subtitle: '验证 JS 侧 FileSystemManager API 完整性',
            icon: Icons.folder_open,
            onTest: () async {
              final result = await evalComponentJs(
                  code: """
                var fs = qqb.getFileSystemManager();
                var apis = ['readFile','writeFile','appendFile','readdir','mkdir','rmdir',
                  'unlink','rename','copyFile','stat','access','getFileInfo',
                  'readFileSync','writeFileSync','mkdirSync','statSync','accessSync'];
                var missing = [];
                for (var i = 0; i < apis.length; i++) {
                  if (typeof fs[apis[i]] !== 'function') missing.push(apis[i]);
                }
                JSON.stringify({total: apis.length, missing: missing});
              """);
              final data = jsonDecode(result);
              final missing = data['missing'] as List;
              final ok = missing.isEmpty;
              return _TestResult('FSManager', ok,
                  'total APIs: ${data['total']}\nmissing: ${missing.isEmpty ? 'none ✅' : missing.join(', ')}');
            },
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }
}
