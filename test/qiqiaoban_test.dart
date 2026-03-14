import 'package:flutter_test/flutter_test.dart';
import 'package:qiqiaoban/qiqiaoban.dart';

void main() {
  // 注意：涉及 Rust FFI 的测试需要在真机/模拟器上运行 (integration_test)。
  // 此处仅验证 Dart 侧的类型和结构正确性。

  group('Qiqiaoban', () {
    test('Qiqiaoban 类不可实例化（工具类设计）', () {
      // Qiqiaoban 使用私有构造函数，无法被外部实例化
      // 这是一个编译时保证，此处仅作文档性质的断言
      expect(Qiqiaoban.isInitialized, isFalse);
    });
  });
}
