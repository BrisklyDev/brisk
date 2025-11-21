import 'dart:collection';

import 'package:flutter/material.dart';

final class _ListenerEntry extends LinkedListEntry<_ListenerEntry> {
  _ListenerEntry(this.listener);
  final VoidCallback listener;
}

class _ConfigChangeNotifier implements Listenable {
  final LinkedList<_ListenerEntry> _listeners = LinkedList<_ListenerEntry>();

  @protected
  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(_ListenerEntry(listener));
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final _ListenerEntry entry in _listeners) {
      if (entry.listener == listener) {
        entry.unlink();
        return;
      }
    }
  }

  @protected
  @visibleForTesting
  void notifyListeners() {
    if (_listeners.isEmpty) return;

    final List<_ListenerEntry> localListeners =
        List<_ListenerEntry>.from(_listeners);

    for (final _ListenerEntry entry in localListeners) {
      try {
        if (entry.list != null) entry.listener();
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
          ),
        );
      }
    }
  }
}

class Config {
  Config._();

  /// The shared instance of [Config].
  static final Config instance = Config._();

  ThemeMode themeMode = ThemeMode.light;
}

class ConfigManager extends _ConfigChangeNotifier {
  ConfigManager._();

  /// The shared instance of [ConfigManager].
  static final ConfigManager instance = ConfigManager._();

  Config getConfig() => Config.instance;

  Future<void> setThemeMode(ThemeMode value) async {
    sharedConfig.themeMode = value;
    notifyListeners();
  }
}

final sharedConfig = Config.instance;
final sharedConfigManager = ConfigManager.instance;
