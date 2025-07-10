import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:brisk/constants/setting_options.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/model/isolate/isolate_args.dart';
import 'package:brisk/util/file_extensions.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../constants/file_type.dart';
import '../setting/settings_cache.dart';

class FileUtil {
  static final versionedFileRegex = RegExp('.*_\d*');
  static late Directory defaultTempFileDir;
  static late Directory defaultSaveDir;

  /// Due to the fact that on Linux, temporary directory (/tmp) is cleaned on
  /// reboot, another default temp directory has to be created.
  static Future<Directory> setDefaultTempDir() async {
    final savePath = await HiveUtil.getSetting(SettingOptions.temporaryPath);
    Completer<Directory> completer = Completer();
    Directory tempDir =
        Platform.isLinux ? await linuxDefaultTempDir : await defaultTempDir;
    defaultTempFileDir = tempDir;
    if (savePath?.value != defaultTempFileDir.path) {
      completer.complete(tempDir);
      return completer.future;
    }
    tempDir.createSync(recursive: true);
    completer.complete(tempDir);
    return completer.future;
  }

  static Future<Directory> get defaultTempDir async {
    final baseTempDir = await getTemporaryDirectory();
    return Directory(join(baseTempDir.path, 'Brisk'));
  }

  static Future<Directory> get linuxDefaultTempDir async {
    final downloadsDir = await getDownloadsDirectory();
    return Directory(join(downloadsDir!.path, 'Brisk', 'Temp'));
  }

  static Future<Directory> setDefaultSaveDir() async {
    Completer<Directory> completer = Completer();
    final downloadDir = await getDownloadsDirectory();
    final savePath = await HiveUtil.getSetting(SettingOptions.savePath);
    defaultSaveDir = Directory(join(downloadDir!.path, 'Brisk'));
    if (savePath?.value != defaultSaveDir.path) {
      completer.complete(defaultSaveDir);
      return completer.future;
    }
    defaultSaveDir.createSync(recursive: true);
    completer.complete(defaultSaveDir);
    return completer.future;
  }

  static String getFilePath(
    String fileName, {
    Directory? baseSaveDir,
    bool checkFileDuplicationOnly = false,
    bool useTypeBasedSubDirs = true,
  }) {
    final saveDir = baseSaveDir ?? SettingsCache.saveDir;
    if (!saveDir.existsSync()) {
      saveDir.createSync();
      _createSubDirectories(saveDir.path);
    }

    final subDir = _fileTypeToFolderName(detectFileType(fileName));
    var filePath = join(saveDir.path, subDir, fileName);
    final subDirFullPath = join(saveDir.path, subDir);
    var file = File(filePath);
    final extension = fileName.endsWith("tar.gz")
        ? "tar.gz"
        : fileName.substring(fileName.lastIndexOf('.') + 1);
    int version = 1;

    while (checkDownloadDuplication(file, checkFileDuplicationOnly)) {
      var rawName = getRawFileName(fileName);
      if (versionedFileRegex.hasMatch(rawName)) {
        rawName = rawName.substring(0, rawName.lastIndexOf('_'));
      }
      ++version;
      fileName = '${rawName}_$version.$extension';
      file = File(join(subDirFullPath, fileName));
    }

    if (useTypeBasedSubDirs) {
      return join(saveDir.path, subDir, fileName);
    }
    return join(saveDir.path, fileName);
  }

  static bool checkDownloadDuplication(
      File file, bool checkFileDuplicationOnly) {
    if (checkFileDuplicationOnly) return file.existsSync();

    return HiveUtil.instance.downloadItemsBox.values
            .where((element) => element.filePath == file.path)
            .isNotEmpty ||
        file.existsSync();
  }

  // TODO FIX add other types with two dots
  static String getRawFileName(String fileName) {
    return fileName.substring(
        0,
        fileName.endsWith(".tar.gz")
            ? fileName.lastIndexOf('.') - 4
            : fileName.lastIndexOf('.'));
  }

  static void _createSubDirectories(String path) async {
    final dirs = [
      Directory(join(path, 'Music')),
      Directory(join(path, 'Compressed')),
      Directory(join(path, 'Videos')),
      Directory(join(path, 'Programs')),
      Directory(join(path, 'Documents')),
      Directory(join(path, 'Other'))
    ];
    for (var dir in dirs) {
      dir.createSync();
    }
  }

  /// Detects the [DLFileType] based on the file extension.
  static DLFileType detectFileType(String fileName) {
    final type = extension(fileName.toLowerCase()).replaceFirst(".", "");
    if (SettingsCache.documentFormats.any((f) => type.contains(f))) {
      return DLFileType.documents;
    } else if (SettingsCache.programFormats.any((f) => type.contains(f))) {
      return DLFileType.program;
    } else if (SettingsCache.compressedFormats.any((f) => type.contains(f))) {
      return DLFileType.compressed;
    } else if (SettingsCache.musicFormats.any((f) => type.contains(f))) {
      return DLFileType.music;
    } else if (SettingsCache.videoFormats.any((f) => type.contains(f))) {
      return DLFileType.video;
    } else {
      return DLFileType.other;
    }
  }

  static String _fileTypeToFolderName(DLFileType fileType) {
    if (fileType == DLFileType.video) {
      return 'Videos';
    } else if (fileType == DLFileType.music) {
      return 'Music';
    } else if (fileType == DLFileType.program) {
      return 'Programs';
    } else if (fileType == DLFileType.documents) {
      return 'Documents';
    } else if (fileType == DLFileType.compressed) {
      return 'Compressed';
    } else {
      return 'Other';
    }
  }

  /// Iterates through all written file parts and adds their byte length.
  /// Returns the total byte length which is used to display part write progress
  /// in the UI and also to set the proper download headers for a resume download request.
  static int calculateReceivedBytesSync(Directory dir) {
    int totalLength = 0;
    for (var file in dir.listSync(recursive: true)) {
      totalLength += (file as File).lengthSync();
    }
    return totalLength;
  }

  /// Simply calls [calculateReceivedBytesSync] but is intended to be used by an isolate
  static void calculateReceivedBytesIsolated(IsolateSingleArg<Directory> args) {
    args.sendPort.send(calculateReceivedBytesSync(args.obj));
  }

  static String resolveFileTypeIconPath(String fileType) {
    if (fileType == DLFileType.music.name) {
      return 'assets/icons/music.svg';
    } else if (fileType == DLFileType.video.name) {
      return 'assets/icons/video_2.svg';
    } else if (fileType == DLFileType.compressed.name) {
      return 'assets/icons/archive.svg';
    } else if (fileType == DLFileType.documents.name) {
      return 'assets/icons/document.svg';
    } else if (fileType == DLFileType.program.name) {
      return 'assets/icons/program.svg';
    } else {
      return 'assets/icons/file.svg';
    }
  }

  static Color resolveFileTypeIconColor(String fileType) {
    if (fileType == DLFileType.music.name) {
      return Colors.cyanAccent;
    } else if (fileType == DLFileType.video.name) {
      return Colors.pinkAccent;
    } else if (fileType == DLFileType.compressed.name) {
      return Colors.blue;
    } else if (fileType == DLFileType.documents.name) {
      return const Color(0xFF4CAF50);
    } else if (fileType == DLFileType.program.name) {
      return Colors.indigoAccent;
    } else {
      return Colors.grey;
    }
  }

  static void deleteDownloadTempDirectory(String uid) {
    final path = join(defaultTempFileDir.path, uid);
    final dir = Directory(path);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  static bool checkFileDuplication(String fileName) {
    final subDir = _fileTypeToFolderName(detectFileType(fileName));
    final filePath = join(SettingsCache.saveDir.path, subDir, fileName);
    return File(filePath).existsSync();
  }

  static bool isFilePathInvalid(String filePath) {
    if (filePath.endsWith(separator)) return true;
    final segments = split(filePath)..removeAt(0);
    return segments.any(isFileNameInvalid);
  }

  static bool isFileNameInvalid(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
    if (invalidChars.hasMatch(name)) return true;
    if (name.endsWith(' ') || name.endsWith('.')) return true;
    final reservedNames = <String>{
      'CON',
      'PRN',
      'AUX',
      'NUL',
      for (int i = 1; i <= 9; i++) ...{'COM$i', 'LPT$i'},
    };
    final baseName = name.split('.').first.toUpperCase();
    if (reservedNames.contains(baseName)) return true;
    return false;
  }
}

extension Util on File {
  Uint8List safeReadSync(int count) {
    final fileOpen = openSync();
    final result = fileOpen.readSync(count);
    fileOpen.closeSync();
    return result;
  }
}

void openFileLocation(DownloadItem downloadItem) {
  final folder = downloadItem.filePath.substring(
    0,
    downloadItem.filePath.lastIndexOf(Platform.pathSeparator),
  );
  if (Platform.isWindows) {
    Process.run('explorer.exe', ['/select,', downloadItem.filePath]);
  } else {
    launchUrlString("file:$folder");
  }
}
