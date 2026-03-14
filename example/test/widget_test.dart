import 'package:flutter_test/flutter_test.dart';
import 'package:qiqiaoban_example/main.dart';

void main() {
  testWidgets('七巧板 Example App 渲染验证', (WidgetTester tester) async {
    // 注意：此 Widget 测试不涉及 Rust FFI 调用。
    // FFI 相关的测试请参见 integration_test/。
    //
    // 由于 Example App 依赖 RustLib.init() 完成初始化，
    // 纯 Widget 测试中 Rust 未初始化，需跳过涉及 FFI 的断言。
    // 此处仅验证 App Widget 可正常构建。
    await tester.pumpWidget(const QiqiaobanExampleApp());
    expect(find.text('七巧板 PoC — Dart ↔ Rust'), findsOneWidget);
  });
}
