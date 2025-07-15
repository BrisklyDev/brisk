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

LogicalKeyboardKey? strToLogicalKey(String input) {
  switch (input.toUpperCase()) {
    case 'A':
      return LogicalKeyboardKey.keyA;
    case 'B':
      return LogicalKeyboardKey.keyB;
    case 'C':
      return LogicalKeyboardKey.keyC;
    case 'D':
      return LogicalKeyboardKey.keyD;
    case 'E':
      return LogicalKeyboardKey.keyE;
    case 'F':
      return LogicalKeyboardKey.keyF;
    case 'G':
      return LogicalKeyboardKey.keyG;
    case 'H':
      return LogicalKeyboardKey.keyH;
    case 'I':
      return LogicalKeyboardKey.keyI;
    case 'J':
      return LogicalKeyboardKey.keyJ;
    case 'K':
      return LogicalKeyboardKey.keyK;
    case 'L':
      return LogicalKeyboardKey.keyL;
    case 'M':
      return LogicalKeyboardKey.keyM;
    case 'N':
      return LogicalKeyboardKey.keyN;
    case 'O':
      return LogicalKeyboardKey.keyO;
    case 'P':
      return LogicalKeyboardKey.keyP;
    case 'Q':
      return LogicalKeyboardKey.keyQ;
    case 'R':
      return LogicalKeyboardKey.keyR;
    case 'S':
      return LogicalKeyboardKey.keyS;
    case 'T':
      return LogicalKeyboardKey.keyT;
    case 'U':
      return LogicalKeyboardKey.keyU;
    case 'V':
      return LogicalKeyboardKey.keyV;
    case 'W':
      return LogicalKeyboardKey.keyW;
    case 'X':
      return LogicalKeyboardKey.keyX;
    case 'Y':
      return LogicalKeyboardKey.keyY;
    case 'Z':
      return LogicalKeyboardKey.keyZ;
    default:
      return null;
  }
}

String logicalKeyToStr(LogicalKeyboardKey? key) {
  if (key == null) return "";
  final keyLabel = key.keyLabel;
  if (keyLabel.length == 1 && RegExp(r'[A-Z0-9]').hasMatch(keyLabel)) {
    return keyLabel.toUpperCase();
  }
  return "";
}
