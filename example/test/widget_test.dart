import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'AssetManifest.json') {
        final bytes = Uint8List.fromList(utf8.encode('{}'));
        return ByteData.view(bytes.buffer);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('demo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('PCD Viewer Demo'), findsOneWidget);
    expect(find.text('文件选择'), findsOneWidget);
    expect(find.text('查看器设置'), findsOneWidget);
    expect(find.text('添加 PCD 文件'), findsOneWidget);
    expect(find.text('开始查看'), findsOneWidget);
  });
}
