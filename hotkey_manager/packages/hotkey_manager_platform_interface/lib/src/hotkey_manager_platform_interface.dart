import 'package:hotkey_manager_platform_interface/src/hotkey.dart';
import 'package:hotkey_manager_platform_interface/src/hotkey_manager_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class HotKeyManagerPlatform extends PlatformInterface {
  /// Constructs a HotKeyManagerPlatform.
  HotKeyManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static HotKeyManagerPlatform _instance = MethodChannelHotKeyManager();

  /// The default instance of [HotKeyManagerPlatform] to use.
  ///
  /// Defaults to [MethodChannelHotKeyManager].
  static HotKeyManagerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HotKeyManagerPlatform] when
  /// they register themselves.
  static set instance(HotKeyManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Stream<Map<Object?, Object?>> get onKeyEventReceiver {
    throw UnimplementedError('onKeyEventReceiver() has not been implemented.');
  }

  Future<void> register(HotKey hotKey) async {
    throw UnimplementedError('register() has not been implemented.');
  }

  Future<void> unregister(HotKey hotKey) {
    throw UnimplementedError('unregister() has not been implemented.');
  }

  Future<void> unregisterAll() async {
    throw UnimplementedError('unregisterAll() has not been implemented.');
  }
}
