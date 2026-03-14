import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qiqiaoban/qiqiaoban.dart';
import 'package:qiqiaoban/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => await RustLib.init());

  group('Dart ↔ Rust 通信验证', () {
    testWidgets('同步调用: greet 返回正确消息', (WidgetTester tester) async {
      final result = Qiqiaoban.greet('测试');
      expect(result, contains('测试'));
      expect(result, contains('Rust'));
    });

    testWidgets('同步调用: rustCoreVersion 返回非空版本号', (
      WidgetTester tester,
    ) async {
      final version = Qiqiaoban.rustCoreVersion;
      expect(version.isNotEmpty, isTrue);
      // 版本号格式: x.y.z
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    testWidgets('异步调用: sumToN 返回正确结果', (WidgetTester tester) async {
      final result = await Qiqiaoban.sumToN(100);
      expect(result, equals(5050)); // 高斯公式: 100 * 101 / 2
    });

    testWidgets('Stream 推送: tickStream 推送正确数量', (
      WidgetTester tester,
    ) async {
      final ticks = await Qiqiaoban.tickStream(count: 3).toList();
      expect(ticks, equals([1, 2, 3]));
    });
  });
}
