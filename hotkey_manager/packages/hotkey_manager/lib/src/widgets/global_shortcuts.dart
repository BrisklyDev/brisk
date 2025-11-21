import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

extension _SingleActivatorExtension on SingleActivator {
  HotKey _toHotKey() {
    List<HotKeyModifier> modifiers = [
      if (control) HotKeyModifier.control,
      if (shift) HotKeyModifier.shift,
      if (alt) HotKeyModifier.alt,
      if (meta) HotKeyModifier.meta,
    ];
    return HotKey(
      identifier: [
        ...modifiers.map((m) => m.name),
        '${trigger.keyId}',
      ].join('+'),
      key: trigger,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }
}

class GlobalShortcuts extends StatefulWidget {
  const GlobalShortcuts({
    super.key,
    required this.shortcuts,
    required this.child,
  });

  final Map<SingleActivator, Intent> shortcuts;

  final Widget child;

  @override
  State<GlobalShortcuts> createState() => _GlobalShortcutsState();
}

class _GlobalShortcutsState extends State<GlobalShortcuts> {
  final List<HotKey> _registeredHotKeys = [];

  @override
  void initState() {
    super.initState();
    for (final entry in widget.shortcuts.entries) {
      final hotKey = entry.key._toHotKey();
      hotKeyManager.register(hotKey, keyDownHandler: _onKeyDown);
      _registeredHotKeys.add(hotKey);
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (final hotKey in _registeredHotKeys) {
      hotKeyManager.unregister(hotKey);
    }
    _registeredHotKeys.clear();
  }

  void _onKeyDown(HotKey hotKey) {
    final activator = widget.shortcuts.keys.firstWhere(
      (activator) => activator._toHotKey().identifier == hotKey.identifier,
    );
    final Intent? matchedIntent = widget.shortcuts[activator];
    if (matchedIntent != null) {
      final Action<Intent>? action = Actions.maybeFind<Intent>(
        context,
        intent: matchedIntent,
      );
      if (action != null) {
        final (bool enabled, Object? invokeResult) =
            Actions.of(context).invokeActionIfEnabled(
          action,
          matchedIntent,
          context,
        );
        if (enabled) {
          action.toKeyEventResult(matchedIntent, invokeResult);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class CallbackGlobalShortcuts extends StatefulWidget {
  const CallbackGlobalShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<SingleActivator, VoidCallback> bindings;

  final Widget child;

  @override
  State<CallbackGlobalShortcuts> createState() =>
      _CallbackGlobalShortcutsState();
}

class _CallbackGlobalShortcutsState extends State<CallbackGlobalShortcuts> {
  final List<HotKey> _registeredHotKeys = [];

  Map<SingleActivator, VoidCallback> get bindings => widget.bindings;

  @override
  void initState() {
    super.initState();
    for (final entry in widget.bindings.entries) {
      final hotKey = entry.key._toHotKey();
      hotKeyManager.register(hotKey, keyDownHandler: _onKeyDown);
      _registeredHotKeys.add(hotKey);
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (final hotKey in _registeredHotKeys) {
      hotKeyManager.unregister(hotKey);
    }
    _registeredHotKeys.clear();
  }

  void _onKeyDown(HotKey hotKey) {
    final activator = bindings.keys.firstWhere(
      (activator) => activator._toHotKey().identifier == hotKey.identifier,
    );
    bindings[activator]!.call();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
