import 'dart:io';

import 'package:brisk_download_engine/src/download_engine/download_status.dart';
import 'package:brisk_download_engine/src/download_engine/model/m3u8.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';
import 'package:brisk_download_engine/src/download_engine/util/m3u8_util.dart';
import 'package:brisk_download_engine/src/download_engine/util/types.dart';
import 'package:dartx/dartx_io.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

import 'http_download_connection.dart';

class M3U8DownloadConnection extends HttpDownloadConnection {
  M3U8Segment m3u8segment;
  bool clientInitialized = false;
  int flushBufferCounter = 1;
  String? refererHeader;

  M3U8DownloadConnection({
    required super.downloadItem,
    required super.segment,
    required super.connectionNumber,
    required super.settings,
    required this.m3u8segment,
    this.refererHeader,
  });

  @override
  void doStart(
    DownloadProgressCallback progressCallback, {
    bool connectionReset = false,
    bool reuseConnection = false,
  }) async {
    tempDirectory.createSync(recursive: true);
    startLogFlushTimer();
    logger?.info(
      "Starting download for m3u8 segment ${m3u8segment.sequenceNumber} with "
      "reuseConnection: $reuseConnection "
      "connectionReset: $connectionReset "
      "url: ${m3u8segment.url}",
    );
    for (final file in tempDirectory.listSync()) {
      file.deleteSync(recursive: true);
    }
    await init(connectionReset, progressCallback, reuseConnection);
    if (connectionReset) {
      resetStatus();
    }
    notifyProgress();
    final request = buildDownloadRequest(false);
    sendDownloadRequest(
      request,
      timeout: Duration(milliseconds: settings.connectionRetryTimeoutMillis),
    );
  }

  @override
  bool get isDownloadCompleted {
    final finalSegmentPath = join(
      tempDirectory.path,
      "final-segment.ts",
    );
    return File(finalSegmentPath).existsSync();
  }

  @override
  Future<void> resetConnection() async {
    logger?.info("Resetting connection....");
    reset = true;
    clearBuffer();
    await terminateConnection();
    dynamicFlushThreshold = double.infinity;
    clientInitialized = false;
    start(progressCallback!, connectionReset: true);
  }

  @override
  init(connectionReset, progressCallback, _) async {
    await terminateConnection();
    connectionStatus =
        connectionReset ? DownloadStatus.resetting : DownloadStatus.connecting;
    overallStatus = connectionStatus;
    this.progressCallback = progressCallback;
    await initClient(connectionReset);
    clientInitialized = true;
    paused = false;
    reset = false;
    terminatedOnCompletion = false;
    flushBufferCounter = 0;
    tempReceivedBytes = 0;
    clearBuffer();
  }

  @override
  http.Request buildDownloadRequest(bool _) {
    var headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko;",
      "Connection": "keep-alive",
      "Keep-Alive": "timeout=4",
    };
    if (refererHeader != null) {
      headers["referer"] = refererHeader!;
    }
    return http.Request('GET', Uri.parse(m3u8segment.url))
      ..headers.addAll(headers);
  }

  @override
  Future<void> doProcessChunk(List<int> chunk) async {
    if (chunk.isEmpty) return;
    buffer.add(chunk);
    tempReceivedBytes += chunk.length;
    updateStatus(DownloadStatus.downloading);
    lastResponseTimeMillis = _nowMillis;
    pauseButtonEnabled = downloadItem.supportsPause;
    connectionStatus = transferRate;
    calculateTransferRate(chunk);
    calculateDynamicFlushThreshold();
    if (tempReceivedBytes > dynamicFlushThreshold) {
      flushBuffer();
    }
    notifyProgress();
  }

  @override
  void flushBuffer() {
    isWritingTempFile = true;
    final bytes = writeToUin8List(buffer);
    final filePath = join(tempDirectory.path, flushBufferCounter.toString());
    File(filePath).writeAsBytesSync(mode: FileMode.writeOnly, bytes);
    logger?.info(
      "FlushBuffer for segment ${m3u8segment.sequenceNumber}::${basename(filePath)}",
    );
    clearBuffer();
    sendLogBuffer();
    flushBufferCounter++;
    isWritingTempFile = false;
  }

  @override
  void onDownloadComplete() async {
    if (paused || reset || terminatedOnError) return;
    flushBuffer();
    connectionStatus = DownloadStatus.connectionComplete;
    logger?.info("Download complete with completion signal");
    await assembleM3U8Segment();
    notifyProgress(completionSignal: true);
  }

  /// Merges all temporary files of an m3u8 segment into one file and decrypts it if required.
  /// The successful completion of this method's execution marks the segment as fully downloaded.
  /// It does so by renaming the file at the end of the operation which can be used by the engine
  /// to mark this segment as fully downloaded in order to ignore it for a resume operation.
  Future<void> assembleM3U8Segment() async {
    final tempFiles = tempDirectory.listSync().map((e) => e as File).toList()
      ..sort(
        (a, b) => basename(a.path).toInt().compareTo(basename(b.path).toInt()),
      );
    final segmentFile = File(join(tempDirectory.path, "Final_Segment.ts"));
    for (final file in tempFiles) {
      final bytes = file.readAsBytesSync();
      segmentFile.writeAsBytesSync(bytes, mode: FileMode.writeOnlyAppend);
    }
    if (m3u8segment.encryptionMethod == M3U8EncryptionMethod.aes128) {
      await decryptAes128File(
        segmentFile,
        m3u8segment.encryptionDetails!.keyBytes!,
        decryptionIV!,
        chunked: false,
      );
    }
    final newPath = join(tempDirectory.path, "final-segment.ts");
    segmentFile.renameSync(newPath);
    // tempDirectory
    //     .listSync()
    //     .map((e) => e as File)
    //     .where((f) => f.name != "final-segment.ts")
    //     .forEach((f) => f.deleteSync());
  }

  @override
  Directory get tempDirectory => Directory(
        join(
          settings.baseTempDir.path,
          downloadItem.uid.toString(),
          m3u8segment.sequenceNumber.toString(),
        ),
      );

  @override
  Future<void> pause(DownloadProgressCallback? progressCallback) async {
    clientInitialized = false;
    paused = true;
    logger?.info("Paused connection $connectionNumber");
    cancelLogFlushTimer();
    if (progressCallback != null) {
      this.progressCallback = progressCallback;
    }
    clearBuffer();
    print("Setting pause for connection $connectionNumber");
    updateStatus(DownloadStatus.paused);
    connectionStatus = DownloadStatus.paused;
    await terminateConnection();
    pauseButtonEnabled = false;
    notifyProgress();
  }

  /// Initialization vector used for decrypting AES-128 based m3u8 encryption
  IV? get decryptionIV {
    final encryptionDetails = m3u8segment.encryptionDetails!;
    if (encryptionDetails.encryptionMethod == M3U8EncryptionMethod.aes128) {
      return encryptionDetails.iv == null
          ? deriveImplicitIV(m3u8segment.sequenceNumber)
          : deriveExplicitIV(m3u8segment.encryptionDetails!.iv!);
    }
    return null;
  }

  /// Refresh segment is not supported for m3u8 download connections
  @override
  void refreshSegment(Segment segment, {bool reuseConnection = false}) {
    logger?.warn(
      "Invalid Operation! Refresh segment requested on an m3u8 download connection",
    );
  }

  int get _nowMillis => DateTime.now().millisecondsSinceEpoch;
}
