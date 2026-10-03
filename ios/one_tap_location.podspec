Pod::Spec.new do |s|
  s.name             = 'one_tap_location'
  s.version          = '0.1.1'
  s.summary          = 'One-tap location using CLLocationButton.'
  s.description      = 'Flutter plugin that embeds CLLocationButton to obtain one-time location access with a single tap.'
  s.homepage         = 'https://github.com/Chemeindefer/one_tap_location'
  s.license          = { :type => 'BSD-3-Clause', :file => '../LICENSE' }
  s.author           = { 'Batuhan Delice' => 'developer@batuhandelice.com' }
  s.source           = { :http => 'https://github.com/Chemeindefer/one_tap_location' }
  s.source_files     = 'one_tap_location/Sources/one_tap_location/**/*.swift'
  s.resource_bundles = { 'one_tap_location_privacy' => ['one_tap_location/Sources/one_tap_location/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'CoreLocation', 'CoreLocationUI'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
