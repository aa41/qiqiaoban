import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qiqiaoban_platform_interface.dart';

/// An implementation of [QiqiaobanPlatform] that uses method channels.
class MethodChannelQiqiaoban extends QiqiaobanPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('qiqiaoban');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
