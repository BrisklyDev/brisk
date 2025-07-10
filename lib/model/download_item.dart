import 'package:brisk/constants/download_type.dart';
import 'package:brisk/model/file_metadata.dart';
import 'package:brisk/util/file_util.dart';
import 'package:brisk/util/http_util.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'download_item.g.dart';

@HiveType(typeId: 0)
class DownloadItem extends HiveObject {
  @HiveField(1)
  String uid;

  @HiveField(2)
  String fileName;

  @HiveField(3)
  String filePath;

  @HiveField(4)
  String downloadUrl;

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  int contentLength;

  @HiveField(7)
  DateTime? finishDate;

  @HiveField(8)
  double progress;

  @HiveField(9)
  String fileType;

  @HiveField(10)
  bool supportsPause;

  @HiveField(11)
  String status;

  @HiveField(12, defaultValue: {})
  Map<String, dynamic> extraInfo;

  @HiveField(13, defaultValue: "HTTP")
  String downloadType;

  @HiveField(14)
  String? referer;

  @HiveField(15, defaultValue: [])
  List<Map<String, String>> subtitles;

  @HiveField(16, defaultValue: {})
  Map<String, String> requestHeaders;

  DownloadItem({
    required this.uid,
    required this.fileName,
    this.filePath = '',
    required this.downloadUrl,
    required this.startDate,
    this.finishDate,
    this.progress = 0,
    this.contentLength = 0,
    this.fileType = "other",
    this.supportsPause = false,
    this.status = "In Queue",
    this.extraInfo = const {},
    this.downloadType = "HTTP",
    this.subtitles = const [],
    this.requestHeaders = const {},
  });

  factory DownloadItem.fromFileInfo(FileInfo fileInfo) {
    final item = DownloadItem.fromUrl(fileInfo.url);
    item.fileName = fileInfo.fileName;
    item.fileType = FileUtil.detectFileType(item.fileName).name;
    item.contentLength = fileInfo.contentLength;
    item.supportsPause = fileInfo.supportsPause;
    item.filePath = FileUtil.getFilePath(
      item.fileName,
      useTypeBasedSubDirs: SettingsCache.automaticFileSavePathCategorization,
    );
    return item;
  }

  factory DownloadItem.fromUrl(String url) {
    final fileName = extractFileNameFromUrl(url);
    final fileType = FileUtil.detectFileType(fileName);
    return DownloadItem(
      uid: const Uuid().v4(),
      fileName: fileName,
      downloadUrl: url,
      startDate: DateTime.now(),
      progress: 0,
      fileType: fileType.name,
    );
  }

  void setM3u8Content(String m3u8Content) {
    extraInfo["m3u8Content"] = m3u8Content;
  }
}
