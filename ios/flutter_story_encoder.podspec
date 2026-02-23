Pod::Spec.new do |s|
  s.name             = 'flutter_story_encoder'
  s.version          = '1.1.5'
  s.summary          = 'A production-grade, hardware-accelerated video export engine for Flutter.'
  s.description      = <<-DESC
  A production-grade, hardware-accelerated video export engine for Flutter. Specifically designed for high-scale social media story editors requiring premium performance, thermal stability, and 4K capability.
                       DESC
  s.homepage         = 'http://lucasveneno.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Lucas Veneno' => 'webmaster@lucasveneno.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
