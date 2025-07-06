import 'package:brisk/setting/rule/file_condition.dart';
import 'package:brisk/setting/rule/file_rule.dart';

class FileSavePathRule extends FileRule {
  String savePath;

  FileSavePathRule({
    required this.savePath,
    required super.condition,
    required super.value,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FileSavePathRule) return false;
    return this.condition == other.condition &&
        this.value == other.value &&
        this.savePath == other.savePath;
  }

  @override
  String toString() {
    return "${condition.name}:$value@:/$savePath";
  }

  factory FileSavePathRule.fromString(String str) {
    final regex = RegExp(r'^(.+?):(.+?)@:/(.+)$');
    final match = regex.firstMatch(str)!;
    return FileSavePathRule(
      condition: FileCondition.values.byName(match.group(1)!),
      value: match.group(2)!,
      savePath: match.group(3)!,
    );
  }
}
