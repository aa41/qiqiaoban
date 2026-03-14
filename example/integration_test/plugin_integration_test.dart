import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qiqiaoban/qiqiaoban.dart';
import 'package:qiqiaoban/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => await RustLib.init());

  testWidgets('Qiqiaoban plugin 基本通信验证', (WidgetTester tester) async {
    // 验证同步调用
    final greeting = Qiqiaoban.greet('Plugin');
    expect(greeting.isNotEmpty, isTrue);

    // 验证版本号
    final version = Qiqiaoban.rustCoreVersion;
    expect(version.isNotEmpty, isTrue);

    // 验证异步调用
    final sum = await Qiqiaoban.sumToN(10);
    expect(sum, equals(55));
  });
}
