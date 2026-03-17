#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_pcd_view.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_pcd_view'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for viewing PCD point cloud files.'
  s.description      = <<-DESC
A Flutter plugin for viewing PCD point cloud files with Rust-powered parsing.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -force_load "${PODS_TARGET_SRCROOT}/libflutter_pcd_view.a"'
  }
  s.prepare_command = 'sh build_rust_ios.sh'
  s.script_phase = {
    :name => 'Build Rust static library',
    :execution_position => :before_compile,
    :shell_path => '/bin/sh',
    :script => 'sh "${PODS_TARGET_SRCROOT}/build_rust_ios.sh"'
  }
  s.swift_version = '5.0'

  # Rust static library
  s.vendored_libraries = 'libflutter_pcd_view.a'
end
