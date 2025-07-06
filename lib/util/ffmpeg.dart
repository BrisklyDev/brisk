import 'dart:async';
import 'dart:io';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/provider/ffmpeg_installation_provider.dart';
import 'package:brisk/util/app_logger.dart';
import 'package:brisk/util/platform.dart';
import 'package:brisk/util/settings_cache.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:path/path.dart';
import 'package:brisk/widget/base/info_dialog.dart';
import 'package:brisk/widget/download/ffmpg_installation_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class FFmpeg {
  /// TODO url has latest tag
  static const String linux_x64_InstallationUrl =
      "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-linux64-gpl-7.1.tar.xz";

  static const String linux_arm64_InstallationUrl =
      "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-linuxarm64-gpl-7.1.tar.xz";

  static const String windowsInstallationUrl =
      "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-win64-gpl-7.1.zip";

  static Future<String> get downloadedFFmpegPath async =>
      '${await ffmpegBaseInstallationPath}'
      '${Platform.pathSeparator}'
      'ffmpeg'
      '${Platform.pathSeparator}'
      'bin'
      '${Platform.pathSeparator}'
      'ffmpeg';

  static bool get ignoreWarning {
    return HiveUtil.instance.generalDataBox.values
        .where((element) => element.fieldName == 'ffmpegWarningIgnore')
        .first
        .value;
  }

  static Future<void> _ensureExecutable() async {
    if (Platform.isWindows || SettingsCache.ffmpegPath == 'ffmpeg') {
      return;
    }
    final result = await Process.run(
      'chmod',
      ['+x', await downloadedFFmpegPath],
    );
    if (result.exitCode != 0) {
      Logger.log('chmod failed: ${result.stderr}');
    }
  }

  static Future<bool> isInstalled() async {
    try {
      await _ensureExecutable();
      final result = await Process.run(ffmpegPath, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static String get ffmpegPath {
    var ffmpegPath = SettingsCache.ffmpegPath;
    if (Directory(ffmpegPath).existsSync()) {
      ffmpegPath = join(
        ffmpegPath,
        "ffmpeg${Platform.isWindows ? ".exe" : ""}",
      );
    }
    return ffmpegPath;
  }

  static Future<void> install(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    if (Platform.isMacOS) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          width: 500,
          height: 140,
          textHeight: 70,
          title: loc.ffmpeg_installationNotSupported_title,
          description: loc.ffmpeg_installationNotSupported_description,
          descriptionHint: loc.ffmpeg_installationNotSupported_descriptionHint,
        ),
      );
      return;
    }
    final dialogContextCompleter = Completer<BuildContext>();
    final completer = Completer<void>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        dialogContextCompleter.complete(dialogContext);
        return FfmpegInstallationProgressDialog();
      },
    );
    final installationProvider = Provider.of<FFmpegInstallationProvider>(
      context,
      listen: false,
    );
    installationProvider.start(onComplete: () async {
      final dialogContext = await dialogContextCompleter.future;
      if (Navigator.canPop(dialogContext)) {
        Navigator.of(dialogContext).pop(); // Close progress dialog
      }
      showDialog(
        context: context,
        builder: (context) => InfoDialog(
          titleText: loc.ffmpegInstalled,
          titleIcon: Icon(Icons.done),
          titleIconBackgroundColor: Colors.lightGreen,
        ),
      );
      completer.complete();
    });
    return completer.future;
  }

  static Future<void> addSoftSubsToVideo(
    File video,
    List<File> subtitles,
  ) async {
    final arguments = [
      '-f',
      'mpegts',
      '-i',
      video.path,
    ];
    subtitles.forEach((sub) => arguments.addAll(['-i', sub.path]));
    arguments.addAll(['-map', '0:v', '-map', '0:a']);
    for (int i = 1; i <= subtitles.length; i++) {
      arguments.addAll(['-map', i.toString()]);
    }
    arguments.addAll(['-c', 'copy']);
    for (int i = 0; i < subtitles.length; i++) {
      final sub = subtitles[i];
      arguments.addAll([
        '-metadata:s:s:$i',
        'language=${basenameWithoutExtension(sub.path)}',
      ]);
    }
    final outputFileName = basenameWithoutExtension(video.path) + ".mkv";
    arguments.add('${join(video.parent.path, outputFileName)}');
    await Process.run(ffmpegPath, arguments);
  }

  static Future<void> addSoftSubsToDownloadedFile(DownloadItem dl) async {
    final subDirPath = join(
      await tempSubtitlesPath,
      "${basenameWithoutExtension(dl.fileName)}_subs",
    );
    final subsDir = Directory(subDirPath);
    subsDir.createSync(recursive: true);
    List<File> subtitles = [];
    for (final subObj in dl.subtitles) {
      final url = subObj['url'];
      if (url == null) continue;
      final subName = url.substring(url.lastIndexOf("/") + 1);
      final subFile = File(join(subDirPath, subName));
      subFile.writeAsStringSync(subObj['content']!);
      subtitles.add(subFile);
    }
    await addSoftSubsToVideo(File(dl.filePath), subtitles);
    subsDir.deleteSync(recursive: true);
  }

  static Future<String> get ffmpegBaseInstallationPath async {
    if (isFlatpak || isSnap) {
      return (await getDownloadsDirectory())!.path;
    }
    return File(Platform.resolvedExecutable).parent.path;
  }

  static Future<String> get tempSubtitlesPath async {
    if (isFlatpak || isSnap) {
      return (await getDownloadsDirectory())!.path;
    }
    return (await getTemporaryDirectory()).path;
  }
}
