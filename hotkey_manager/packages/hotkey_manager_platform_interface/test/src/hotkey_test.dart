import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager_platform_interface/src/hotkey.dart';

String oldHotKeyJson1 =
    '{"keyCode":"keyZ","modifiers":["meta","shift"],"identifier":"01","scope":"system"}';
String oldHotKeyJson2 =
    '{"keyCode":"keyA","modifiers":["alt","shift"],"identifier":"02","scope":"system"}';
String newHotKeyJson1 =
    '{"identifier":"01","key":{"usageCode":458781},"modifiers":["meta","shift"],"scope":"system"}';
String newHotKeyJson2 =
    '{"identifier":"02","key":{"usageCode":458756},"modifiers":["alt","shift"],"scope":"system"}';

void main() {
  test('should be compatible with old JSON', () async {
    final hotKey1 = HotKey.fromJson(json.decode(oldHotKeyJson1));
    expect(hotKey1.key, PhysicalKeyboardKey.keyZ);
    expect(hotKey1.modifiers?.first, HotKeyModifier.meta);
    expect(hotKey1.modifiers?.last, HotKeyModifier.shift);
    final hotKey2 = HotKey.fromJson(json.decode(oldHotKeyJson2));
    expect(hotKey2.key, PhysicalKeyboardKey.keyA);
    expect(hotKey2.modifiers?.first, HotKeyModifier.alt);
    expect(hotKey2.modifiers?.last, HotKeyModifier.shift);
    final newHotKey1 = HotKey.fromJson(json.decode(newHotKeyJson1));
    expect(newHotKey1.key, PhysicalKeyboardKey.keyZ);
    expect(newHotKey1.modifiers?.first, HotKeyModifier.meta);
    expect(newHotKey1.modifiers?.last, HotKeyModifier.shift);
    final newHotKey2 = HotKey.fromJson(json.decode(newHotKeyJson2));
    expect(newHotKey2.key, PhysicalKeyboardKey.keyA);
    expect(newHotKey2.modifiers?.first, HotKeyModifier.alt);
    expect(newHotKey2.modifiers?.last, HotKeyModifier.shift);
  });
}
