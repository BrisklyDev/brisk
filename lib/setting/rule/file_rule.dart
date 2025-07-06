import 'package:brisk/model/download_item.dart';
import 'package:brisk/model/file_metadata.dart';
import 'package:brisk/setting/rule/file_condition.dart';
import 'package:path/path.dart';

class FileRule {
  FileCondition condition;
  String value;

  FileRule({required this.condition, required this.value});

  @override
  String toString() {
    return "${condition.name}:$value";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FileRule) return false;
    return this.condition == other.condition && this.value == other.value;
  }

  String get valueWithTypeConsidered {
    return readableValue
        .replaceAll(" GB", "")
        .replaceAll(" MB", "")
        .replaceAll(" KB", "");
  }

  String get readableValue {
    if (condition.hasTextValue()) {
      return value;
    }
    double bytes = double.tryParse(value) ?? 0;
    if (bytes >= 1024 * 1024 * 1024) {
      double gb = bytes / (1024 * 1024 * 1024);
      return "${gb.toStringAsFixed(2)} GB";
    } else if (bytes >= 1024 * 1024) {
      double mb = bytes / (1024 * 1024);
      return "${mb.toStringAsFixed(2)} MB";
    } else {
      double kb = bytes / 1024;
      return "${kb.toStringAsFixed(2)} KB";
    }
  }

  factory FileRule.fromString(String str) {
    final conditionStr = str.substring(0, str.indexOf(":"));
    final condition = FileCondition.values.byName(conditionStr);
    final value = str.substring(str.indexOf(":") + 1);
    return FileRule(condition: condition, value: value);
  }

  bool isSatisfiedByFileInfo(FileInfo fileInfo) {
    return isSatisfied(fileInfo.fileName, fileInfo.url, fileInfo.contentLength);
  }

  bool isSatisfiedByDownloadItem(DownloadItem downloadItem) {
    return isSatisfied(
      downloadItem.fileName,
      downloadItem.downloadUrl,
      downloadItem.contentLength,
    );
  }

  bool isSatisfied(String fileName, String url, int fileSize) {
    switch (this.condition) {
      case FileCondition.fileNameContains:
        return fileName.toLowerCase().contains(value.toLowerCase());
      case FileCondition.fileExtensionIs:
        return extension(fileName).contains(value.toLowerCase());
      case FileCondition.fileSizeGreaterThan:
        return fileSize > (double.tryParse(value) ?? double.infinity);
      case FileCondition.fileSizeLessThan:
        return fileSize < (double.tryParse(value) ?? double.infinity);
      case FileCondition.downloadUrlContains:
        return url.contains(value);
    }
  }
}
