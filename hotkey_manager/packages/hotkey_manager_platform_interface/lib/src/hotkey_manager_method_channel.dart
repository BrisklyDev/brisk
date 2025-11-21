import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';
// ignore: implementation_imports
import 'package:uni_platform/src/extensions/keyboard_key.dart';

/// An implementation of [HotKeyManagerPlatform] that uses method channels.
class MethodChannelHotKeyManager extends HotKeyManagerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'dev.leanflutter.plugins/hotkey_manager',
  );

  /// The event channel used to receive events from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel(
    'dev.leanflutter.plugins/hotkey_manager_event',
  );

  @override
  Stream<Map<Object?, Object?>> get onKeyEventReceiver {
    return eventChannel.receiveBroadcastStream().cast<Map<Object?, Object?>>();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> register(HotKey hotKey) async {
    await methodChannel.invokeMethod('register', {
      'keyCode': hotKey.physicalKey.keyCode,
      ...hotKey.toJson(),
    });
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    await methodChannel.invokeMethod('unregister', {
      'keyCode': hotKey.physicalKey.keyCode,
      ...hotKey.toJson(),
    });
  }

  @override
  Future<void> unregisterAll() async {
    await methodChannel.invokeMethod('unregisterAll');
  }
}
