# Changelog

## 0.1.2

- Add the iOS Swift Package Manager package manifest and source layout for Flutter's SwiftPM plugin integration.
- Keep CocoaPods support by pointing the podspec at the shared Swift source location.

## 0.1.1

- Remove the unused root `flutter_hooks` dependency; the example keeps its own direct dependency.
- Keep pub.dev repository metadata available for package scoring.

## 0.1.0

- Prepare the package for the first public pub.dev release.
- Add Android OpenGL ES and iOS Metal native texture rendering.
- Add `PcdView.fromFile` and `PcdView.fromPoints` as the primary viewer API.
- Export the main viewer API from `package:flutter_pcd_view/flutter_pcd_view.dart`.
- Automatically initialize the Rust parser when loading files through `PcdView`.
- Add loading and preparing states for the default viewer.
- Add configurable point size, colors, axes, grid, native render scale, point budget, deduplication, voxel sampling, outlier removal, and point connectivity options.
- Update the example app with file selection, bundled sample files, renderer settings, and viewer controls.
## 0.1.4

- Upgrade `flutter_rust_bridge` to 2.12.0 to match the runtime version.

## 0.1.3

- Make Android Rust build tolerate missing `rust/Cargo.lock`.
- Ensure `rust/Cargo.lock` is not excluded from packaged sources.
