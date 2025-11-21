// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotkey.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HotKey _$HotKeyFromJson(Map<String, dynamic> json) => HotKey(
      identifier: json['identifier'] as String?,
      key: const _KeyboardKeyConverter().fromJson(json['key'] as Map),
      modifiers: (json['modifiers'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$HotKeyModifierEnumMap, e))
          .toList(),
      scope: $enumDecodeNullable(_$HotKeyScopeEnumMap, json['scope']) ??
          HotKeyScope.system,
    );

Map<String, dynamic> _$HotKeyToJson(HotKey instance) => <String, dynamic>{
      'identifier': instance.identifier,
      'key': const _KeyboardKeyConverter().toJson(instance.key),
      'modifiers':
          instance.modifiers?.map((e) => _$HotKeyModifierEnumMap[e]!).toList(),
      'scope': _$HotKeyScopeEnumMap[instance.scope]!,
    };

const _$HotKeyModifierEnumMap = {
  HotKeyModifier.alt: 'alt',
  HotKeyModifier.capsLock: 'capsLock',
  HotKeyModifier.control: 'control',
  HotKeyModifier.fn: 'fn',
  HotKeyModifier.meta: 'meta',
  HotKeyModifier.shift: 'shift',
};

const _$HotKeyScopeEnumMap = {
  HotKeyScope.system: 'system',
  HotKeyScope.inapp: 'inapp',
};
