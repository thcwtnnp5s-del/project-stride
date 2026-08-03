#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint stride_health.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'stride_health'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  # Inline, not a :file reference.
  #
  # This was `{ :file => '../LICENSE' }`, pointing at a Flutter-template stub
  # that was deleted when the repository went public and adopted an
  # all-rights-reserved policy (COPYRIGHT.md). A podspec whose license file is
  # missing fails to parse, and nothing caught it because the iOS builds here
  # resolve through Swift Package Manager -- the break only surfaces on a
  # CocoaPods fallback, which is exactly what a first device build on an
  # unfamiliar Mac does.
  s.license          = { :type => 'Proprietary', :text => 'Copyright (c) Rob Hathaway. All rights reserved. See COPYRIGHT.md.' }
  s.author           = { 'Studio Stride' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'stride_health/Sources/stride_health/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'stride_health_privacy' => ['stride_health/Sources/stride_health/PrivacyInfo.xcprivacy']}
end
