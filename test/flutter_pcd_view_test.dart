import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pcd_view/pcd_view.dart';
import 'package:flutter_pcd_view/src/native/native_renderer_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Point3D creation', () {
    final point = Point3D(
      x: 1.0,
      y: 2.0,
      z: 3.0,
      color: 0xFFFFFFFF,
      hasColor: true,
    );
    expect(point.x, 1.0);
    expect(point.y, 2.0);
    expect(point.z, 3.0);
    expect(point.color, 0xFFFFFFFF);
    expect(point.hasColor, true);
  });

  test('ViewerConfig supports pointColor in defaults and copyWith', () {
    const config = ViewerConfig();
    expect(config.pointColor, Colors.white);

    final updated = config.copyWith(pointColor: Colors.red);
    expect(updated.pointColor, Colors.red);
    expect(updated, const ViewerConfig(pointColor: Colors.red));
  });

  test('CameraConfig supports pan offsets in defaults and copyWith', () {
    final dynamic camera = Function.apply(
      CameraConfig.new,
      const [],
      {#panX: 1.25, #panY: -0.75},
    );

    expect(camera.panX, 1.25);
    expect(camera.panY, -0.75);

    final dynamic updated = camera.copyWith(panX: -0.5);
    expect(updated.panX, -0.5);
    expect(updated.panY, -0.75);
  });

  test('NativeCameraController updates pan offsets', () {
    final dynamic controller = Function.apply(
      NativeCameraController.new,
      const [],
      {#panX: 0.5, #panY: -0.25},
    );

    expect(controller.panX, 0.5);
    expect(controller.panY, -0.25);

    controller.update(panX: -1.0, panY: 2.0);
    expect(controller.panX, -1.0);
    expect(controller.panY, 2.0);
  });

  test('NativeRendererBridge updateCamera includes pan offsets', () async {
    const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
    const instanceChannel = MethodChannel('flutter_pcd_view/native_renderer/7');
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(rootChannel, (call) async {
      calls.add(call);
      if (call.method == 'createRenderer') {
        return 7;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(instanceChannel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(rootChannel, null);
      messenger.setMockMethodCallHandler(instanceChannel, null);
    });

    final dynamic camera = Function.apply(
      CameraConfig.new,
      const [],
      {#panX: 1.5, #panY: -2.5},
    );
    final config = ViewerConfig(camera: camera as CameraConfig);
    final bridge = await NativeRendererBridge.create(config: config);

    await Function.apply(
      bridge.updateCamera,
      const [],
      {
        #rotationX: 0.2,
        #rotationY: -0.4,
        #zoom: 1.8,
        #panX: 3.0,
        #panY: -4.0,
      },
    );

    final createCall = calls.firstWhere((call) => call.method == 'createRenderer');
    expect(createCall.arguments['panX'], 1.5);
    expect(createCall.arguments['panY'], -2.5);

    final updateCall = calls.firstWhere((call) => call.method == 'updateCamera');
    expect(updateCall.arguments['panX'], 3.0);
    expect(updateCall.arguments['panY'], -4.0);
  });

  testWidgets(
    'PcdView sends controller pan offsets in the initial camera sync',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel('flutter_pcd_view/native_renderer/7');
      final calls = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(rootChannel, (call) async {
        calls.add(call);
        if (call.method == 'createRenderer') {
          return 7;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(instanceChannel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(rootChannel, null);
        messenger.setMockMethodCallHandler(instanceChannel, null);
      });

      final controller = NativeCameraController(panX: 1.25, panY: -0.75);
      final errors = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PcdView.fromPoints(
              points: const [
                Point3D(
                  x: 0,
                  y: 0,
                  z: 0,
                  color: 0xFFFFFFFF,
                  hasColor: true,
                ),
              ],
              controller: controller,
              onError: errors.add,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final updateCall = calls.lastWhere((call) => call.method == 'updateCamera');
      expect(updateCall.arguments['panX'], 1.25);
      expect(updateCall.arguments['panY'], -0.75);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}),
  );

  testWidgets(
    'PcdView keeps pan offsets during single-finger rotation',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel('flutter_pcd_view/native_renderer/7');
      final calls = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(rootChannel, (call) async {
        calls.add(call);
        if (call.method == 'createRenderer') {
          return 7;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(instanceChannel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(rootChannel, null);
        messenger.setMockMethodCallHandler(instanceChannel, null);
      });

      final controller = NativeCameraController(panX: 1.25, panY: -0.75);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PcdView.fromPoints(
              points: const [
                Point3D(
                  x: 0,
                  y: 0,
                  z: 0,
                  color: 0xFFFFFFFF,
                  hasColor: true,
                ),
              ],
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(Texture)));
      await gesture.moveBy(const Offset(30, 20));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();

      final updateCall = calls.lastWhere((call) => call.method == 'updateCamera');
      expect(updateCall.arguments['panX'], 1.25);
      expect(updateCall.arguments['panY'], -0.75);
      expect(updateCall.arguments['rotationX'], isNot(-0.3));
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}),
  );

  testWidgets(
    'PcdView applies pan and zoom during a two-finger gesture',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel('flutter_pcd_view/native_renderer/7');
      final calls = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(rootChannel, (call) async {
        calls.add(call);
        if (call.method == 'createRenderer') {
          return 7;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(instanceChannel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(rootChannel, null);
        messenger.setMockMethodCallHandler(instanceChannel, null);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PcdView.fromPoints(
              points: [
                Point3D(
                  x: 0,
                  y: 0,
                  z: 0,
                  color: 0xFFFFFFFF,
                  hasColor: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final center = tester.getCenter(find.byType(Texture));
      final finger1 = await tester.createGesture(pointer: 1);
      final finger2 = await tester.createGesture(pointer: 2);

      await finger1.down(center + const Offset(-40, 0));
      await finger2.down(center + const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));

      await finger1.moveTo(center + const Offset(-30, 0));
      await finger2.moveTo(center + const Offset(70, 0));
      await tester.pump(const Duration(milliseconds: 16));

      final updateCall = calls.lastWhere((call) => call.method == 'updateCamera');
      expect(updateCall.arguments['panX'], isNot(0));
      expect(updateCall.arguments['zoom'], greaterThan(1.0));

      await finger1.up();
      await finger2.up();
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}),
  );

  testWidgets(
    'PcdView preserves pan offsets when scene config changes trigger a re-upload',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel('flutter_pcd_view/native_renderer/7');
      final calls = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(rootChannel, (call) async {
        calls.add(call);
        if (call.method == 'createRenderer') {
          return 7;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(instanceChannel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(rootChannel, null);
        messenger.setMockMethodCallHandler(instanceChannel, null);
      });

      final controller = NativeCameraController(panX: 1.25, panY: -0.75);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PcdView.fromPoints(
              points: const [
                Point3D(
                  x: 0,
                  y: 0,
                  z: 0,
                  color: 0xFFFFFFFF,
                  hasColor: true,
                ),
              ],
              controller: controller,
              config: const ViewerConfig(pointSize: 2),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      calls.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PcdView.fromPoints(
              points: const [
                Point3D(
                  x: 0,
                  y: 0,
                  z: 0,
                  color: 0xFFFFFFFF,
                  hasColor: true,
                ),
              ],
              controller: controller,
              config: const ViewerConfig(pointSize: 3),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final updateCall = calls.lastWhere((call) => call.method == 'updateCamera');
      expect(updateCall.arguments['panX'], 1.25);
      expect(updateCall.arguments['panY'], -0.75);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}),
  );
}
