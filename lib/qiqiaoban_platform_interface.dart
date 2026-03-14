import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'qiqiaoban_method_channel.dart';

abstract class QiqiaobanPlatform extends PlatformInterface {
  /// Constructs a QiqiaobanPlatform.
  QiqiaobanPlatform() : super(token: _token);

  static final Object _token = Object();

  static QiqiaobanPlatform _instance = MethodChannelQiqiaoban();

  /// The default instance of [QiqiaobanPlatform] to use.
  ///
  /// Defaults to [MethodChannelQiqiaoban].
  static QiqiaobanPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QiqiaobanPlatform] when
  /// they register themselves.
  static set instance(QiqiaobanPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
