import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pcd_view/pcd_view.dart';
import 'package:flutter_pcd_view/src/native/native_renderer_bridge.dart';
import 'package:flutter_pcd_view/src/native/trackball_orientation.dart';

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

    final updated = config.copyWith(
      pointColor: Colors.red,
      pointColorStrategy: PointColorStrategy.sourceOrHeight,
      interaction: const InteractionConfig(rotationSensitivity: 1.6),
    );
    expect(updated.pointColor, Colors.red);
    expect(updated.pointColorStrategy, PointColorStrategy.sourceOrHeight);
    expect(updated.interaction.rotationSensitivity, 1.6);
  });

  test('HeightColorRamp maps relative height to green blue red', () {
    const ramp = HeightColorRamp(
      low: Colors.green,
      middle: Colors.blue,
      high: Colors.red,
    );

    expect(
      ramp.colorForHeight(z: 0, minZ: 0, maxZ: 10).toARGB32(),
      Colors.green.toARGB32(),
    );
    expect(
      ramp.colorForHeight(z: 5, minZ: 0, maxZ: 10).toARGB32(),
      Colors.blue.toARGB32(),
    );
    expect(
      ramp.colorForHeight(z: 10, minZ: 0, maxZ: 10).toARGB32(),
      Colors.red.toARGB32(),
    );
  });

  test(
    'HeightColorRamp falls back to middle color when height range is flat',
    () {
      const ramp = HeightColorRamp(
        low: Colors.green,
        middle: Colors.blue,
        high: Colors.red,
      );

      expect(
        ramp.colorForHeight(z: 3, minZ: 3, maxZ: 3).toARGB32(),
        Colors.blue.toARGB32(),
      );
    },
  );

  test('binary XYZ fixture has no source color field', () {
    final headerText = String.fromCharCodes(
      File('example/assets/sample_binary.pcd').readAsBytesSync().take(128),
    );

    expect(headerText, contains('FIELDS x y z'));
    expect(headerText, contains('DATA binary'));
    expect(headerText, isNot(contains('rgb')));
    expect(headerText, isNot(contains('color')));
  });

  test('CameraConfig supports pan offsets in defaults and copyWith', () {
    final dynamic camera = Function.apply(CameraConfig.new, const [], {
      #panX: 1.25,
      #panY: -0.75,
    });

    expect(camera.panX, 1.25);
    expect(camera.panY, -0.75);

    final dynamic updated = camera.copyWith(panX: -0.5);
    expect(updated.panX, -0.5);
    expect(updated.panY, -0.75);
  });

  test('TrackballOrientation preserves the initial yaw convention', () {
    final orientation = TrackballOrientation.fromEuler(
      rotationX: 0,
      rotationY: 1.5707963267948966,
    );

    expect(orientation.x, closeTo(0, 0.000001));
    expect(orientation.y, closeTo(0.70710678, 0.000001));
    expect(orientation.z, closeTo(0, 0.000001));
    expect(orientation.w, closeTo(0.70710678, 0.000001));
  });

  test('TrackballOrientation composes successive view-space drags', () {
    final orientation = TrackballOrientation.fromEuler(
      rotationX: 0,
      rotationY: 0,
    );
    final afterYaw = orientation.drag(
      from: const Offset(0.5, 0.5),
      to: const Offset(-0.5, 0.5),
      aspectRatio: 1,
      sensitivity: 1,
    );
    final afterPitch = afterYaw.drag(
      from: const Offset(0.5, 0.5),
      to: const Offset(0.5, 0.0),
      aspectRatio: 1,
      sensitivity: 1,
    );

    expect(afterYaw, isNot(orientation));
    expect(afterPitch, isNot(afterYaw));
    expect(afterPitch.toList(), hasLength(4));
    expect(afterPitch.toList().any((value) => value.abs() > 0.01), isTrue);
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
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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

    final dynamic camera = Function.apply(CameraConfig.new, const [], {
      #panX: 1.5,
      #panY: -2.5,
    });
    final config = ViewerConfig(camera: camera as CameraConfig);
    final bridge = await NativeRendererBridge.create(config: config);

    await Function.apply(bridge.updateCamera, const [], {
      #rotationX: 0.2,
      #rotationY: -0.4,
      #zoom: 1.8,
      #panX: 3.0,
      #panY: -4.0,
      #orientation: TrackballOrientation.identity(),
    });

    final createCall = calls.firstWhere(
      (call) => call.method == 'createRenderer',
    );
    expect(createCall.arguments['panX'], 1.5);
    expect(createCall.arguments['panY'], -2.5);

    final updateCall = calls.firstWhere(
      (call) => call.method == 'updateCamera',
    );
    expect(updateCall.arguments['panX'], 3.0);
    expect(updateCall.arguments['panY'], -4.0);
    expect(updateCall.arguments['orientation'], [0.0, 0.0, 0.0, 1.0]);
  });

  testWidgets(
    'PcdView sends controller pan offsets in the initial camera sync',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
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

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      expect(updateCall.arguments['panX'], 1.25);
      expect(updateCall.arguments['panY'], -0.75);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView keeps pan offsets during single-finger rotation',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
              ],
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Texture)),
      );
      await gesture.moveBy(const Offset(30, 20));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      expect(updateCall.arguments['panX'], 1.25);
      expect(updateCall.arguments['panY'], -0.75);
      expect(updateCall.arguments['rotationX'], isNot(-0.3));
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView applies rotationSensitivity to a leftward horizontal drag',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
              ],
              config: ViewerConfig(
                interaction: InteractionConfig(rotationSensitivity: 1.0),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final textureFinder = find.byType(Texture);
      final gesture = await tester.startGesture(
        tester.getCenter(textureFinder),
      );
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      final textureWidth = tester.getSize(textureFinder).width;
      expect(
        updateCall.arguments['rotationY'],
        closeTo(0.5 - 120 / textureWidth, 0.001),
      );
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView applies upward pitch around the current view axis',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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

      final controller = NativeCameraController(
        rotationX: 0,
        rotationY: 3.141592653589793,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PcdView.fromPoints(
              points: const [
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
              ],
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final textureFinder = find.byType(Texture);
      final gesture = await tester.startGesture(
        tester.getCenter(textureFinder),
      );
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      expect(updateCall.arguments['rotationX'], closeTo(-0.2, 0.001));
      expect(
        updateCall.arguments['rotationY'],
        closeTo(3.141592653589793, 0.001),
      );
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView composes an upward drag after horizontal rotation',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(rootChannel, (call) async {
        calls.add(call);
        if (call.method == 'createRenderer') return 7;
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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
              ],
              config: ViewerConfig(
                interaction: InteractionConfig(rotationSensitivity: 1.0),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final texture = find.byType(Texture);
      final center = tester.getCenter(texture);
      final yaw = await tester.startGesture(center);
      await yaw.moveBy(const Offset(-150, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await yaw.up();
      final yawOrientation = List<double>.from(
        calls
                .lastWhere((call) => call.method == 'updateCamera')
                .arguments['orientation']
            as List,
      );

      final pitch = await tester.startGesture(center);
      await pitch.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 16));
      await pitch.up();
      final combinedOrientation = List<double>.from(
        calls
                .lastWhere((call) => call.method == 'updateCamera')
                .arguments['orientation']
            as List,
      );

      expect(yawOrientation, hasLength(4));
      expect(combinedOrientation, hasLength(4));
      expect(combinedOrientation, isNot(yawOrientation));
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView retains a normalized orientation after repeated large drags',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final textureFinder = find.byType(Texture);
      final textureSize = tester.getSize(textureFinder);
      final gesture = await tester.startGesture(
        tester.getCenter(textureFinder),
      );
      for (final delta in [
        Offset(-textureSize.width, 0),
        Offset(0, -textureSize.height),
        Offset(textureSize.width, 0),
        Offset(0, textureSize.height),
        Offset(-textureSize.width, 0),
        Offset(0, -textureSize.height),
        Offset(textureSize.width, 0),
        Offset(0, textureSize.height),
      ]) {
        await gesture.moveBy(delta);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      final orientation = List<double>.from(
        updateCall.arguments['orientation'] as List,
      );
      expect(orientation, hasLength(4));
      expect(
        orientation.fold<double>(
          0,
          (sum, component) => sum + component * component,
        ),
        closeTo(1, 0.0001),
      );
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView colors source-less points by relative height',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: false),
                Point3D(x: 0, y: 0, z: 5, color: 0xFFFFFFFF, hasColor: false),
                Point3D(x: 0, y: 0, z: 10, color: 0xFFFFFFFF, hasColor: false),
              ],
              config: ViewerConfig(
                showAxes: false,
                grid: GridConfig(visible: false),
                pointColorStrategy: PointColorStrategy.sourceOrHeight,
                heightColorRamp: HeightColorRamp(
                  low: Colors.green,
                  middle: Colors.blue,
                  high: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      final sceneCall = calls.lastWhere(
        (call) => call.method == 'loadPackedScene',
      );
      final packedBytes = sceneCall.arguments['points'] as Uint8List;
      final packedData = ByteData.sublistView(packedBytes);
      double packedFloat(int index) => packedData.getFloat32(
        index * Float32List.bytesPerElement,
        Endian.host,
      );
      void expectPackedColor(int base, Color color) {
        expect(packedFloat(base), closeTo(color.r, 0.000001));
        expect(packedFloat(base + 1), closeTo(color.g, 0.000001));
        expect(packedFloat(base + 2), closeTo(color.b, 0.000001));
      }

      expect(sceneCall.arguments['pointCount'], 3);
      expectPackedColor(3, Colors.green);
      expectPackedColor(10, Colors.blue);
      expectPackedColor(17, Colors.red);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView applies pan and zoom during a two-finger gesture',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
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

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      expect(updateCall.arguments['panX'], isNot(0));
      expect(updateCall.arguments['zoom'], greaterThan(1.0));

      await finger1.up();
      await finger2.up();
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'PcdView preserves pan offsets when scene config changes trigger a re-upload',
    (tester) async {
      const rootChannel = MethodChannel('flutter_pcd_view/native_renderer');
      const instanceChannel = MethodChannel(
        'flutter_pcd_view/native_renderer/7',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
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
                Point3D(x: 0, y: 0, z: 0, color: 0xFFFFFFFF, hasColor: true),
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

      final updateCall = calls.lastWhere(
        (call) => call.method == 'updateCamera',
      );
      expect(updateCall.arguments['panX'], 1.25);
      expect(updateCall.arguments['panY'], -0.75);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );
}
