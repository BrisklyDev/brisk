import 'dart:io';
import 'package:archive/archive.dart';
import 'package:brisk/util/download_engine_util.dart';
import 'package:brisk/util/http_util.dart';
import 'package:brisk/util/platform.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/util/ffmpeg.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';

Future<void> extractFFmpegArchiveIsolate(
  String filePath,
  String outputDir,
) async {
  final file = File(filePath);
  final inputBytes = await file.readAsBytes();
  Archive archive;
  if (Platform.isLinux) {
    final tarBytes = XZDecoder().decodeBytes(inputBytes);
    archive = TarDecoder().decodeBytes(tarBytes);
  } else {
    archive = ZipDecoder().decodeBytes(inputBytes);
  }
  for (final archiveFile in archive) {
    if (archiveFile.name.trim().isEmpty) continue;

    final unixParts = archiveFile.name.split('/');
    final strippedPath = unixParts.length > 1
        ? unixParts.sublist(1).join(Platform.pathSeparator)
        : unixParts.first;
    final outPath = join(outputDir, strippedPath);

    if (archiveFile.isFile) {
      final outFile = File(outPath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(archiveFile.content as List<int>);
    } else {
      await Directory(outPath).create(recursive: true);
    }
  }
}

Future<void> extractArchiveIsolate(Map<String, String> args) async {
  await extractFFmpegArchiveIsolate(args['filePath']!, args['outputDir']!);
}

class FFmpegInstallationProvider with ChangeNotifier {
  DownloadProgressMessage? progress;

  void start({Function? onComplete}) async {
    final downloadItem = DownloadItem.fromUrl(await installationUrl);
    final baseInstallationPath = await FFmpeg.ffmpegBaseInstallationPath;
    Directory ffmpegDir = Directory(join(baseInstallationPath, "ffmpeg"));
    downloadItem.filePath = join(
      baseInstallationPath,
      Platform.isWindows ? "ffmpeg.zip" : "ffmpeg.tar.xz",
    );
    if (File(downloadItem.filePath).existsSync()) {
      File(downloadItem.filePath).deleteSync();
    }
    if (ffmpegDir.existsSync()) {
      ffmpegDir.deleteSync(recursive: true);
    }
    final fileInfo = await requestFileInfo(downloadItem, null);
    downloadItem.contentLength = fileInfo!.contentLength;
    downloadItem.supportsPause = fileInfo.supportsPause;
    final downloadItemModel = buildFromDownloadItem(downloadItem);
    DownloadEngine.start(
      downloadItemModel,
      downloadSettingsFromCache(),
      downloadItemModel.downloadType,
      onButtonAvailability: (_) {},
      onDownloadProgress: (progress) async {
        this.progress = progress;
        if (progress.status == DownloadStatus.assembling ||
            progress.status == DownloadStatus.validatingFiles) {
          this.progress!.status = "Finalizing...";
        } else if (progress.status == DownloadStatus.assembleComplete) {
          this.progress!.status = "Finalizing...";
          await extractFFmpegCompute(downloadItem);
          File(downloadItem.filePath).deleteSync();
          SettingsCache.ffmpegPath = await FFmpeg.downloadedFFmpegPath;
          await SettingsCache.saveCachedSettingsToDB();
          onComplete?.call();
        } else {
          this.progress!.status = "Downloading FFmpeg...";
        }
        notifyListeners();
      },
    );
  }

  Future<void> extractFFmpegCompute(DownloadItem downloadItem) async {
    await compute(
      extractArchiveIsolate,
      {
        'filePath': downloadItem.filePath,
        'outputDir': join(await FFmpeg.ffmpegBaseInstallationPath, "ffmpeg")
      },
    );
  }

  Future<String> get installationUrl async {
    if (await isLinux_x86_64) {
      return FFmpeg.linux_x64_InstallationUrl;
    }
    if (await isLinux_arm64) {
      return FFmpeg.linux_arm64_InstallationUrl;
    }
    if (Platform.isWindows) {
      return FFmpeg.windowsInstallationUrl;
    }
    return "";
  }
}
