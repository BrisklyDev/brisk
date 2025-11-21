import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';

class HotKeyManager {
  HotKeyManager._() {
    _platform.onKeyEventReceiver.listen(_handleSystemHotKeyEvent);
    HardwareKeyboard.instance.addHandler(_handleInAppHotKeyEvent);
  }

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  HotKeyManagerPlatform get _platform => HotKeyManagerPlatform.instance;

  final List<HotKey> _hotKeyList = [];
  final Map<String, HotKeyHandler> _keyDownHandlerMap = {};
  final Map<String, HotKeyHandler> _keyUpHandlerMap = {};

  HotKey? _lastPressedHotKey;

  /// Handle system hot key event.
  void _handleSystemHotKeyEvent(event) {
    String type = event['type'] as String;
    Map<Object?, Object?> data = event['data'] as Map;
    String identifier = data['identifier'] as String;
    HotKey? hotKey = _hotKeyList.firstWhereOrNull(
      (e) => e.identifier == identifier,
    );
    if (hotKey != null) {
      switch (type) {
        case 'onKeyDown':
          if (_keyDownHandlerMap.containsKey(identifier)) {
            _keyDownHandlerMap[identifier]!(hotKey);
          }
          break;
        case 'onKeyUp':
          if (_keyUpHandlerMap.containsKey(identifier)) {
            _keyUpHandlerMap[identifier]!(hotKey);
          }
          break;
        default:
          UnimplementedError();
      }
    }
  }

  /// Handle in-app hot key event.
  bool _handleInAppHotKeyEvent(KeyEvent keyEvent) {
    if (_hotKeyList.where((e) => e.scope == HotKeyScope.inapp).isEmpty) {
      return false;
    }

    if (keyEvent is KeyUpEvent && _lastPressedHotKey != null) {
      HotKeyHandler? handler = _keyUpHandlerMap[_lastPressedHotKey!.identifier];
      if (handler != null) handler(_lastPressedHotKey!);
      _lastPressedHotKey = null;
      return true;
    }

    if (keyEvent is KeyRepeatEvent && _lastPressedHotKey != null) {
      return true;
    }

    if (keyEvent is KeyDownEvent) {
      final physicalKeysPressed = HardwareKeyboard.instance.physicalKeysPressed;
      final hotKeys = _hotKeyList.where((e) {
        List<HotKeyModifier> modifiers = HotKeyModifier.values
            .where((e) => e.physicalKeys.any(physicalKeysPressed.contains))
            .toList();
        return e.scope == HotKeyScope.inapp &&
            keyEvent.logicalKey == e.logicalKey &&
            modifiers.length == (e.modifiers?.length ?? 0) &&
            modifiers.every((e.modifiers ?? []).contains);
      });
      if (hotKeys.isNotEmpty) {
        for (final hotKey in hotKeys) {
          HotKeyHandler? handler = _keyDownHandlerMap[hotKey.identifier];
          if (handler != null) handler(hotKey);
        }
        _lastPressedHotKey = hotKeys.last;
        return true;
      }
    }
    return false;
  }

  List<HotKey> get registeredHotKeyList => _hotKeyList;

  /// Register a hot key.
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    if (hotKey.scope == HotKeyScope.system) {
      await _platform.register(hotKey);
    }
    if (keyDownHandler != null) {
      _keyDownHandlerMap.update(
        hotKey.identifier,
        (_) => keyDownHandler,
        ifAbsent: () => keyDownHandler,
      );
    }
    if (keyUpHandler != null) {
      _keyUpHandlerMap.update(
        hotKey.identifier,
        (_) => keyUpHandler,
        ifAbsent: () => keyUpHandler,
      );
    }
    _hotKeyList.add(hotKey);
  }

  /// Unregister a hot key.
  Future<void> unregister(HotKey hotKey) async {
    if (hotKey.scope == HotKeyScope.system) {
      await _platform.unregister(hotKey);
    }
    if (_keyDownHandlerMap.containsKey(hotKey.identifier)) {
      _keyDownHandlerMap.remove(hotKey.identifier);
    }
    if (_keyUpHandlerMap.containsKey(hotKey.identifier)) {
      _keyUpHandlerMap.remove(hotKey.identifier);
    }
    _hotKeyList.removeWhere((e) => e.identifier == hotKey.identifier);
  }

  /// Unregister all hot keys.
  Future<void> unregisterAll() async {
    await _platform.unregisterAll();
    _keyDownHandlerMap.clear();
    _keyUpHandlerMap.clear();
    _hotKeyList.clear();
  }
}

final hotKeyManager = HotKeyManager.instance;
