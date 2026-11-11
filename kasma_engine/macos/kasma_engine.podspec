# Builds the kasma Rust engine as a static library and links it into this pod's framework.
# Dart looks the symbols up with DynamicLibrary.process() / the pod framework.
Pod::Spec.new do |s|
  s.name             = 'kasma_engine'
  s.version          = '0.1.0'
  s.summary          = 'Native kasma download engine for Brisk'
  s.homepage         = 'https://github.com/BrisklyDev/kasma'
  s.license          = { :type => 'GPL' }
  s.author           = { 'Brisk' => 'brisk@localhost' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.script_phase = {
    :name => 'Build kasma engine (Rust)',
    :script => 'sh "$PODS_TARGET_SRCROOT/../scripts/build_macos.sh"',
    :execution_position => :before_compile,
    :output_files => ['${BUILT_PRODUCTS_DIR}/kasma_rust/libkasma.a'],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/kasma_rust/libkasma.a -framework Security -framework CoreFoundation -framework SystemConfiguration',
  }
end
