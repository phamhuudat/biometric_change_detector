Pod::Spec.new do |s|
  s.name             = 'biometric_change_detector'
  s.version          = '0.1.0'
  s.summary          = 'Detect when enrolled biometrics (Face ID, Touch ID) change.'
  s.description      = <<-DESC
Takes a snapshot of the enrolled biometrics (LAContext domain state, stored in
the Keychain) and reports when a face or fingerprint is added or removed.
                       DESC
  s.homepage         = 'https://github.com/phamhuudat/biometric_change_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Pham Huu Dat' => 'phamhuudatk58@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'biometric_change_detector/Sources/biometric_change_detector/**/*.swift'
  s.resource_bundles = { 'biometric_change_detector_privacy' => ['biometric_change_detector/Sources/biometric_change_detector/PrivacyInfo.xcprivacy'] }
  s.frameworks       = 'LocalAuthentication', 'Security'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
