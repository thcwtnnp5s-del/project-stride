#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint stride_secure_store.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'stride_secure_store'
  s.version          = '0.0.1'
  s.summary          = 'Project Stride device-bound secure storage: the iOS Keychain reconciliation identity (AfterFirstUnlockThisDeviceOnly) and NSURLIsExcludedFromBackupKey for the save directory, behind a Pigeon-typed boundary.'
  s.description      = <<-DESC
Project Stride device-bound secure storage: the iOS Keychain reconciliation identity (AfterFirstUnlockThisDeviceOnly) and NSURLIsExcludedFromBackupKey for the save directory, behind a Pigeon-typed boundary.
                       DESC
  s.homepage         = 'https://github.com/thcwtnnp5s-del/project-stride'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Project Stride' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'stride_secure_store/Sources/stride_secure_store/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'stride_secure_store_privacy' => ['stride_secure_store/Sources/stride_secure_store/PrivacyInfo.xcprivacy']}
end
