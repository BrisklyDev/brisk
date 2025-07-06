import 'package:brisk/constants/app_closure_behaviour.dart';
import 'package:brisk/constants/file_duplication_behaviour.dart';
import 'package:brisk/constants/file_type.dart';
import 'package:brisk/constants/setting_options.dart';
import 'package:brisk/constants/setting_type.dart';
import 'package:brisk/setting/rule/file_save_path_rule.dart';
import 'package:brisk/setting/rule/file_rule.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:csv/csv.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

bool parseBool(String val) {
  return val.toLowerCase() == "true" ? true : false;
}

SettingType parseSettingType(String val) {
  return SettingType.values.where((type) => type.name == val).first;
}

DLFileType parseFileType(String val) {
  return DLFileType.values.where((type) => type.name == val).first;
}

FileDuplicationBehaviour parseFileDuplicationBehaviour(String val) {
  return FileDuplicationBehaviour.values
      .where((type) => type.name == val)
      .first;
}

AppClosureBehaviour parseAppCloseBehaviour(String val) {
  return AppClosureBehaviour.values.where((type) => type.name == val).first;
}

ClientType resolveClientType(String clientType) {
  return ClientType.values.where((type) => type.name == clientType).first;
}

SettingOptions parseSettingOptions(String val) {
  return SettingOptions.values.where((type) => type.name == val).first;
}

String parseBoolStr(bool val) {
  return val ? "true" : "false";
}

String parseListToCsv(List<String> list) {
  if (list.isEmpty) return "";
  return const ListToCsvConverter().convert([list, []]);
}

bool isCsv(String str) {
  return str.contains(",");
}

String parseFileRulesToCsv(List<FileRule> fileRules) {
  if (fileRules.isEmpty) return "";
  final fileRulesStr = fileRules.map((o) => o.toString()).toList();
  return parseListToCsv(fileRulesStr);
}

String parseFileSavePathRulesToCsv(List<FileSavePathRule> rules) {
  if (rules.isEmpty) return "";
  final fileRulesStr = rules.map((o) => o.toString()).toList();
  return parseListToCsv(fileRulesStr);
}

List<FileSavePathRule> parseCsvToFileSavePathRuleList(String csv) {
  if (csv.isNullOrBlank) return [];
  final rulesStr = parseCsvToList(csv);
  print(csv);
  return rulesStr.map((str) => FileSavePathRule.fromString(str)).toList();
}

List<FileRule> parseCsvToFileRuleList(String csv) {
  if (csv.isNullOrBlank) return [];
  final rulesStr = parseCsvToList(csv);
  return rulesStr.map((str) => FileRule.fromString(str)).toList();
}

List<String> parseCsvToList(String csv) {
  if (csv.isNullOrBlank) return [];
  return csv.isEmpty ? [] : const CsvToListConverter().convert(csv)[0].cast();
}

HotKeyModifier? strToHotkeyModifier(String modifier) {
  if (modifier.isEmpty) return null;
  return HotKeyModifier.values.where((m) => m.name == modifier).firstOrNull;
}

HotKeyScope strToHotkeyScope(String scope) {
  return HotKeyScope.values.where((m) => m.name == scope).first;
}

LogicalKeyboardKey? strToLogicalKey(String keyLabel) {
  if (keyLabel.isEmpty || keyLabel.length != 1) return null;

  final upper = keyLabel.toUpperCase();

  // Letters A-Z
  final codeUnit = upper.codeUnitAt(0);
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
    return LogicalKeyboardKey(
      0x00000000061 + (codeUnit - 0x41),
    );
  }

  // Digits 0-9
  if (codeUnit >= 0x30 && codeUnit <= 0x39) {
    return LogicalKeyboardKey(
      0x00000000030 + (codeUnit - 0x30),
    );
  }
  return null;
}

String logicalKeyToStr(LogicalKeyboardKey? key) {
  if (key == null) return "";
  final keyLabel = key.keyLabel;
  if (keyLabel.length == 1 && RegExp(r'[A-Z0-9]').hasMatch(keyLabel)) {
    return keyLabel.toUpperCase();
  }
  return "";
}
