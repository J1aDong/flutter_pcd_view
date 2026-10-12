import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('demo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('PCD Viewer Demo'), findsOneWidget);
    expect(find.text('文件选择'), findsOneWidget);
    expect(find.text('查看器设置'), findsOneWidget);
    expect(find.text('添加 PCD 文件'), findsOneWidget);
    expect(find.text('开始查看'), findsOneWidget);
  });
}
