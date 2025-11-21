import 'package:flutter/services.dart';
import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uni_platform/uni_platform.dart';
import 'package:uuid/uuid.dart';

part 'hotkey.g.dart';

const _uuid = Uuid();

typedef HotKeyHandler = void Function(HotKey hotKey);

enum HotKeyModifier {
  alt([
    PhysicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight,
  ]),
  capsLock([
    PhysicalKeyboardKey.capsLock,
  ]),
  control([
    PhysicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight,
  ]),
  fn([
    PhysicalKeyboardKey.fn,
  ]),
  meta([
    PhysicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight,
  ]),
  shift([
    PhysicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight,
  ]);

  const HotKeyModifier(this.physicalKeys);

  final List<PhysicalKeyboardKey> physicalKeys;

  bool get isModifierPressed {
    final physicalKeysPressed = HardwareKeyboard.instance.physicalKeysPressed;
    return physicalKeys.any(physicalKeysPressed.contains);
  }
}

enum HotKeyScope {
  system,
  inapp,
}

@JsonSerializable(
  converters: [_KeyboardKeyConverter()],
)
class HotKey {
  HotKey({
    String? identifier,
    required this.key,
    this.modifiers,
    this.scope = HotKeyScope.system,
  }) : identifier = identifier ?? _uuid.v4();

  factory HotKey.fromJson(Map<String, dynamic> json) {
    if (json['keyCode'] is String) return _$HotKeyFromOldJson(json);
    return _$HotKeyFromJson(json);
  }

  final String identifier;
  final KeyboardKey key;
  final List<HotKeyModifier>? modifiers;
  final HotKeyScope scope;

  LogicalKeyboardKey get logicalKey {
    if (key is LogicalKeyboardKey) {
      return key as LogicalKeyboardKey;
    } else if (key is PhysicalKeyboardKey) {
      return (key as PhysicalKeyboardKey).logicalKey!;
    }
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'Invalid keyboard key',
    );
  }

  PhysicalKeyboardKey get physicalKey {
    if (key is PhysicalKeyboardKey) {
      return key as PhysicalKeyboardKey;
    } else if (key is LogicalKeyboardKey) {
      return (key as LogicalKeyboardKey).physicalKey!;
    }
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'Invalid keyboard key',
    );
  }

  String get debugName {
    return [
      ...(modifiers ?? []).map((e) {
        final firstPhysicalKey = e.physicalKeys.first;
        return firstPhysicalKey.debugName;
      }),
      physicalKey.debugName,
    ].join(' + ');
  }

  Map<String, dynamic> toJson() => _$HotKeyToJson(this);
}

// Convert KeyboardKey to/from Map<Object?, Object?>
class _KeyboardKeyConverter
    extends JsonConverter<KeyboardKey, Map<Object?, Object?>> {
  const _KeyboardKeyConverter();

  @override
  KeyboardKey fromJson(json) {
    final map = json.cast<String, dynamic>();
    int? keyId = map['keyId'];
    int? usageCode = map['usageCode'];
    if (keyId != null) {
      final logicalKey = LogicalKeyboardKey.findKeyByKeyId(keyId);
      if (logicalKey != null) {
        return logicalKey;
      }
    }
    if (usageCode != null) {
      final physicalKey = PhysicalKeyboardKey.findKeyByCode(usageCode);
      if (physicalKey != null) {
        return physicalKey;
      }
    }
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'Invalid keyboard key',
    );
  }

  @override
  Map<String, dynamic> toJson(KeyboardKey object) {
    int? keyId = object is LogicalKeyboardKey ? object.keyId : null;
    int? usageCode = object is PhysicalKeyboardKey ? object.usbHidUsage : null;
    return {
      'keyId': keyId,
      'usageCode': usageCode,
    }..removeWhere((key, value) => value == null);
  }
}

// Convert HotKey from old JSON format
HotKey _$HotKeyFromOldJson(Map<String, dynamic> json) {
  LogicalKeyboardKey logicalKey =
      KeyCodeParser.parse(json['keyCode']).logicalKey;
  return HotKey(
    identifier: json['identifier'] as String,
    key: logicalKey.physicalKey!,
    modifiers: ((json['modifiers'] as List<dynamic>?) ?? []).map((modifier) {
      return HotKeyModifier.values.firstWhere((e) => e.name == modifier);
    }).toList(),
    scope: HotKeyScope.values.firstWhere(
      (e) => e.name == json['scope'] as String,
      orElse: () => HotKeyScope.system,
    ),
  );
}
