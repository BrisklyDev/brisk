import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/download_command.dart';
import 'package:brisk_download_engine/src/download_engine/download_type.dart';
import 'package:brisk_download_engine/src/download_engine/engine/http_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/engine/m3u8_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/model/file_info.dart';
import 'package:brisk_download_engine/src/download_engine/util/isolate_args.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'message/terminated_message.dart';

class DownloadEngine {
  static final Map<String, StreamChannel?> engineChannels = {};
  static final Map<String, Isolate?> engineIsolates = {};
  static final Map<String, DownloadItemModel> downloadItems = {};
  static final Map<String, ButtonAvailabilityMessage> buttonAvailabilities = {};
  static final Map<String, Completer> engineTerminationCompleter = {};
  static DownloadSettings? _settings;
  static Isolate? fileInfoExtractorIsolate;

  static void pause(String uid) {
    if (KasmaDownloadEngine.isRunning(uid)) {
      KasmaDownloadEngine.pause(uid);
      return;
    }
    if (downloadItems[uid] == null || engineChannels[uid] == null) return;
    if (checkDownloadCompletion(downloadItems[uid]!)) {
      return;
    }
    _executeCommand(uid, DownloadCommand.pause);
  }

  static void resume(String uid) {
    if (KasmaDownloadEngine.isRunning(uid)) {
      KasmaDownloadEngine.resume(uid);
      return;
    }
    if (downloadItems[uid] == null || engineChannels[uid] == null) return;
    if (checkDownloadCompletion(downloadItems[uid]!)) {
      return;
    }
    if (buttonAvailabilities[uid] != null &&
        !buttonAvailabilities[uid]!.startButtonEnabled) {
      return;
    }
    _executeCommand(uid, DownloadCommand.start);
  }

  static Future<void> terminate(String uid) async {
    if (KasmaDownloadEngine.isRunning(uid)) {
      return KasmaDownloadEngine.terminate(uid);
    }
    if (engineChannels[uid] == null) {
      return Completer().complete();
    }
    _executeCommand(uid, DownloadCommand.terminate);
    engineTerminationCompleter[uid] = Completer();
    return engineTerminationCompleter[uid]!.future;
  }

  static void _executeCommand(String uid, DownloadCommand command) {
    final downloadItem = downloadItems[uid]!;
    final message = DownloadIsolateMessage.createFromDownloadType(
      downloadType: downloadItem.downloadType,
      command: command,
      downloadItem: downloadItem,
      settings: _settings!,
    );
    engineChannels[uid]!.sink.add(message);
  }

  static bool checkDownloadCompletion(DownloadItemModel downloadItem) {
    final file = File(downloadItem.filePath);
    return downloadItem.status == DownloadStatus.assembleComplete ||
        (file.existsSync() && file.lengthSync() == downloadItem.fileSize);
  }

  static void start(
    DownloadItemModel downloadItem,
    DownloadSettings settings,
    DownloadType type, {
    required Function(ButtonAvailabilityMessage) onButtonAvailability,
    required Function(DownloadProgressMessage) onDownloadProgress,
  }) async {
    // if (checkDownloadCompletion(downloadItem)) {
    //   return;
    // }
    if (KasmaDownloadEngine.isRunning(downloadItem.uid) ||
        engineChannels[downloadItem.uid] != null) {
      resume(downloadItem.uid);
      return;
    }
    if (_shouldUseKasma(settings, type)) {
      _settings = settings;
      downloadItems[downloadItem.uid] = downloadItem;
      final started = KasmaDownloadEngine.start(
        downloadItem,
        settings,
        onButtonAvailability: (message) {
          buttonAvailabilities[downloadItem.uid] = message;
          onButtonAvailability(message);
        },
        onDownloadProgress: onDownloadProgress,
        onTerminated: () {
          final completer = engineTerminationCompleter.remove(downloadItem.uid);
          if (completer != null && !completer.isCompleted) completer.complete();
        },
      );
      if (started) return;
    }
    final channel = await _spawnDownloadEngineIsolate(downloadItem, type);
    _settings = settings;
    downloadItems[downloadItem.uid] = downloadItem;
    channel.stream.listen(
      (message) {
        if (message is DownloadProgressMessage) {
          onDownloadProgress(message);
        }
        if (message is ButtonAvailabilityMessage) {
          buttonAvailabilities[downloadItem.uid] = message;
          onButtonAvailability(message);
        }
        if (message is TerminatedMessage) {
          engineTerminationCompleter[downloadItem.uid]?.complete();
        }
      },
    );
    final message = DownloadIsolateMessage.createFromDownloadType(
      downloadType: type,
      command: DownloadCommand.start,
      downloadItem: downloadItem,
      settings: settings,
    );
    channel.sink.add(message);
  }

  /// The kasma engine is used for HTTP and M3U8 downloads when selected in the settings and the
  /// native library is available. Proxies are not supported by kasma yet, so downloads that
  /// require a proxy fall back to the standard engine.
  static bool _shouldUseKasma(DownloadSettings settings, DownloadType type) {
    if (settings.engineType != EngineType.kasma) {
      return false;
    }
    if (settings.clientSettings?.proxySetting?.proxyEnabled ?? false) {
      return false;
    }
    if (!KasmaDownloadEngine.isAvailable) {
      print("Kasma engine unavailable, falling back to the standard engine: "
          "${KasmaDownloadEngine.unavailableReason}");
      return false;
    }
    return true;
  }

  static Future<StreamChannel> _spawnDownloadEngineIsolate(
    DownloadItemModel downloadItem,
    DownloadType type,
  ) async {
    final rPort = ReceivePort();
    final channel = IsolateChannel.connectReceive(rPort);
    final isolate = await Isolate.spawn(
      type == DownloadType.http
          ? HttpDownloadEngine.start
          : M3U8DownloadEngine.start,
      IsolateSingleArg(rPort.sendPort, downloadItem.uid),
      errorsAreFatal: false,
    );
    engineIsolates[downloadItem.uid] = isolate;
    engineChannels[downloadItem.uid] = channel;
    return channel;
  }

  static Future<DownloadItemModel> buildDownloadItem(String downloadUrl) async {
    final port = await _spawnFileInfoRetrieverIsolate(downloadUrl);
    final fileInfo = await _retrieveFileInfo(port);
    return DownloadItemModel(
      uid: const Uuid().v4(),
      fileName: fileInfo.fileName,
      downloadUrl: downloadUrl,
      progress: 0,
      fileSize: fileInfo.contentLength,
      supportsPause: fileInfo.supportsPause,
    );
  }

  static Future<FileInfo> _retrieveFileInfo(ReceivePort receivePort) async {
    final Completer<FileInfo> completer = Completer();
    receivePort.listen((message) {
      if (message is FileInfo) {
        completer.complete(message);
      } else {
        completer.completeError(message);
      }
    });
    return completer.future;
  }

  static Future<ReceivePort> _spawnFileInfoRetrieverIsolate(String url) async {
    final ReceivePort receivePort = ReceivePort();
    fileInfoExtractorIsolate = await Isolate.spawn<IsolateSingleArg>(
      requestFileInfoIsolate,
      IsolateSingleArg(receivePort.sendPort, url),
      paused: true,
    );
    fileInfoExtractorIsolate?.addErrorListener(receivePort.sendPort);
    fileInfoExtractorIsolate
        ?.resume(fileInfoExtractorIsolate!.pauseCapability!);
    return receivePort;
  }

  static Future<FileInfo?> requestFileInfo(String url) async {
    final request = http.Request("HEAD", Uri.parse(url));
    final client = http.Client();
    var response = client.send(request);
    Completer<FileInfo?> completer = Completer();
    response.asStream().timeout(Duration(seconds: 10)).listen((response) {
      final headers = response.headers;
      var filename = _extractFilenameFromHeaders(headers);
      filename ??= extractFileNameFromUrl(url);
      if (headers["content-length"] == null) {
        throw Exception({"Could not retrieve result from the given URL"});
      }
      final contentLength = int.parse(headers["content-length"]!);
      final fileName = Uri.decodeComponent(filename);
      final supportsPause = _checkDownloadPauseSupport(headers);
      final data = FileInfo(
        supportsPause,
        fileName,
        contentLength,
      );
      completer.complete(data);
    }, onError: (e) => completer.completeError(e));
    return completer.future;
  }

  static String extractFileNameFromUrl(String url) {
    final slashIndex = url.lastIndexOf('/');
    final dotIndex = url.lastIndexOf('.');
    return (url.substring(dotIndex).contains('?'))
        ? url.substring(slashIndex + 1, url.lastIndexOf('?'))
        : url.substring(slashIndex + 1);
  }

  static bool _checkDownloadPauseSupport(Map<String, String> headers) {
    var value = headers['Accept-Ranges'] ?? headers['accept-ranges'];
    return value != null && value == 'bytes';
  }

  static String? _extractFilenameFromHeaders(Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition == null) return null;
    List<String> tokens = contentDisposition.split(";");
    String? filename;
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].contains('filename')) {
        filename = !tokens[i].contains('"')
            ? tokens[i].substring(tokens[i].indexOf("=") + 1, tokens[i].length)
            : tokens[i]
                .substring(tokens[i].indexOf("=") + 2, tokens[i].length - 1);
      }
    }
    return filename;
  }

  static Future<void> requestFileInfoIsolate(IsolateSingleArg args) async {
    final result = await requestFileInfo(args.obj);
    args.sendPort.send(result);
  }
}
