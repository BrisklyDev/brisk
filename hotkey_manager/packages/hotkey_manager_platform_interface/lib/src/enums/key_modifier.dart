// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

const Map<KeyModifier, List<LogicalKeyboardKey>> _knownLogicalKeys =
    <KeyModifier, List<LogicalKeyboardKey>>{
  KeyModifier.capsLock: [
    LogicalKeyboardKey.capsLock,
  ],
  KeyModifier.shift: [
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  ],
  KeyModifier.control: [
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
  ],
  KeyModifier.alt: [
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  ],
  KeyModifier.meta: [
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  ],
  KeyModifier.fn: [
    LogicalKeyboardKey.fn,
  ],
};

const Map<KeyModifier, ModifierKey> _knownModifierKeys =
    <KeyModifier, ModifierKey>{
  KeyModifier.capsLock: ModifierKey.capsLockModifier,
  KeyModifier.shift: ModifierKey.shiftModifier,
  KeyModifier.control: ModifierKey.controlModifier,
  KeyModifier.alt: ModifierKey.altModifier,
  KeyModifier.meta: ModifierKey.metaModifier,
  KeyModifier.fn: ModifierKey.functionModifier,
};

final Map<KeyModifier, String> _knownKeyLabels = <KeyModifier, String>{
  KeyModifier.capsLock: '⇪',
  KeyModifier.shift: '⇧',
  KeyModifier.control: (!kIsWeb && Platform.isMacOS) ? '⌃' : 'Ctrl',
  KeyModifier.alt: (!kIsWeb && Platform.isMacOS) ? '⌥' : 'Alt',
  KeyModifier.meta: (!kIsWeb && Platform.isMacOS) ? '⌘' : '⊞',
  KeyModifier.fn: 'fn',
};

@Deprecated(
  'No longer supported, Use `HotKeyModifier` instead. ',
)
enum KeyModifier {
  capsLock,
  shift,
  control,
  alt, // Alt / Option key
  meta, // Command / Win key
  fn,
}

extension KeyModifierParser on KeyModifier {
  static KeyModifier parse(String string) {
    return KeyModifier.values.firstWhere((e) => e.name == string);
  }

  static KeyModifier? fromModifierKey(ModifierKey modifierKey) {
    return _knownModifierKeys.entries
        .firstWhere((entry) => entry.value == modifierKey)
        .key;
  }

  ModifierKey get modifierKey {
    return _knownModifierKeys[this]!;
  }

  static KeyModifier? fromLogicalKey(LogicalKeyboardKey logicalKey) {
    List<int> logicalKeyIdList = [];

    for (List<LogicalKeyboardKey> item in _knownLogicalKeys.values) {
      logicalKeyIdList.addAll(item.map((e) => e.keyId).toList());
    }
    if (!logicalKeyIdList.contains(logicalKey.keyId)) return null;

    return _knownLogicalKeys.entries
        .firstWhere(
          (entry) => entry.value.map((e) => e.keyId).contains(logicalKey.keyId),
        )
        .key;
  }

  List<LogicalKeyboardKey> get logicalKeys {
    return _knownLogicalKeys[this]!;
  }

  String get stringValue => name;

  String get keyLabel {
    return _knownKeyLabels[this] ?? name;
  }
}
