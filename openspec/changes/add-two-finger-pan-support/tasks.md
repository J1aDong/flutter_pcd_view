## 1. Camera state model

- [x] 1.1 Extend `CameraConfig` and `NativeCameraController` with `panX` and `panY` defaulting to zero.
- [x] 1.2 Update `PcdView` native camera state and synchronization flow to carry pan values alongside rotation and zoom.
- [x] 1.3 Extend `NativeRendererBridge.updateCamera` and related method-channel payloads to include `panX` and `panY`.

## 2. Native renderer support

- [x] 2.1 Update the Android native renderer to store pan offsets, accept them in `updateCamera`, and apply them in the view matrix.
- [x] 2.2 Update the iOS native renderer to store pan offsets, accept them in `updateCamera`, and apply them in the view matrix.

## 3. Gesture handling

- [x] 3.1 Update `_NativePcdTextureRenderer` gesture handling so single-finger drag still rotates while two-finger focal-point movement updates pan.
- [x] 3.2 Keep two-finger zoom active during the same gesture update without resetting the current pan state.
- [x] 3.3 Ensure viewport refreshes, scene uploads, and widget rebuilds preserve the current pan offset.

## 4. Verification

- [x] 4.1 Verify the OpenSpec requirements are covered by checking single-finger rotation, two-finger pan, and pinch zoom behavior.
- [x] 4.2 Verify Android and iOS camera update paths stay aligned after the pan-state extension.
