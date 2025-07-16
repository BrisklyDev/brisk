import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/client/custom_base_client.dart';
import 'package:brisk_download_engine/src/download_engine/engine/http_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/message/connection_segment_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/engine_panic_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/internal_messages.dart';
import 'package:brisk_download_engine/src/download_engine/message/log_message.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';
import 'package:brisk_download_engine/src/download_engine/util/constants.dart';
import 'package:brisk_download_engine/src/download_engine/util/file_util.dart';
import 'package:brisk_download_engine/src/download_engine/util/lang_utils.dart';
import 'package:brisk_download_engine/src/download_engine/util/temp_file_util.dart';
import 'package:brisk_download_engine/src/download_engine/util/types.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

import '../log/logger.dart';

/// The base class of Http Download connection is a client-agnostic implementation
/// that makes use of the abstract method [buildClient] to initialize the client.
/// The current implementations include [MockHttpDownloadConnection] and
/// [HttpDownloadConnection]
/// TODO print errors that are thrown in this isolate
class HttpDownloadConnection {
  Logger? logger;

  /// Buffer containing the received bytes
  List<List<int>> buffer = [];

  /// Total temp files written by this connection (includes temp files after connection reuse)
  final List<File> connectionCachedTempFiles = [];

  /// The download progress percentage for this segment
  double downloadProgress = 0;

  // The download progress in relation to the total progress
  double totalDownloadProgress = 0;

  /// The total of received bytes for this request
  int totalConnectionReceivedBytes = 0;

  int previouslyWrittenBytesLength = 0;

  /// used to differentiate between the total bytes of a request (with a certain
  /// byte range) and the total received bytes of a connection which is the
  /// accumulation of all received byte ranges
  int totalRequestReceivedBytes = 0;

  /// The total byte length of un-flushed buffer.
  /// This value reset to 0 after each flush.
  int tempReceivedBytes = 0;

  bool supportsPause = false;

  String transferRate = "";

  String overallStatus = "Stopped";

  /// Time used to calculate the elapsed milliseconds between data chunk transfers
  int _tmpTime = DateTime.now().millisecondsSinceEpoch;

  /// Buffer used to calculate transfer rate
  List<List<int>> _transferRateChunkBuffer = [];

  double bytesTransferRate = 0;

  bool paused = false;

  bool reset = false;

  bool terminatedOnCompletion = false;

  bool terminatedOnError = false;

  String connectionStatus = "";

  int totalRequestWrittenBytes = 0;

  int totalConnectionWrittenBytes = 0;

  /// calculate and update transfer rate every 0.7 seconds
  static const int _transferRateCalculationWindowMillis = 700;

  /// The client used to make http requests
  CustomBaseClient? client;

  StreamSubscription<List<int>>? downloadSub;

  /// Threshold is currently only dynamically decided (2 times the byte transfer rate per second -
  /// and less than 8 MB)
  // static const _staticFlushThreshold = 524288;
  double dynamicFlushThreshold = 52428800;

  double totalConnectionWriteProgress = 0;

  double totalRequestWriteProgress = 0;

  /// Determines if the user is permitted to hit the pause button or not.
  /// In order to prevent issues (mostly regarding [startButtonEnabled] property),
  /// the user is only permitted to hit the pause button only once before hitting
  /// the resume button.
  bool pauseButtonEnabled = true;

  DownloadItemModel downloadItem;

  /// Callback method used to update the engine on the current progress of the download
  DownloadProgressCallback? progressCallback;

  Segment segment;

  int connectionNumber;

  int previousBufferEndByte = 0;

  /// Connection retry
  int lastResponseTimeMillis = DateTime.now().millisecondsSinceEpoch;

  Timer? logFlushTimer;

  int _retryCount = 0;

  bool isWritingTempFile = false;

  ConnectionSettings settings;

  HttpDownloadConnection({
    required this.downloadItem,
    required this.segment,
    required this.connectionNumber,
    required this.settings,
  });

  /// Starts the download request.
  /// [progressCallback] is used to let the provider know that the values are
  /// changed so that it calls notify listeners which can be used to display its live progress.
  /// TODO Correct the received bytes when correcting temp bytes (never allow it to go beyond the required bytes)
  void start(
    DownloadProgressCallback progressCallback, {
    bool connectionReset = false,
    bool reuseConnection = false,
  }) {
    try {
      doStart(
        progressCallback,
        connectionReset: connectionReset,
        reuseConnection: reuseConnection,
      );
    } catch (e) {
      logger?.error("Failed to start! ${e.toString()}");
    }
  }

  /// TODO do not reInit client when the connection was not terminated
  /// TODO Fix: The main status shows complete then connecting then complete and so on
  void doStart(
    DownloadProgressCallback progressCallback, {
    bool connectionReset = false,
    bool reuseConnection = false,
  }) async {
    startLogFlushTimer();
    initTempFilesCache();
    logger?.info(
      "Starting download for segment $startByte - $endByte with "
      "reuseConnection: $reuseConnection "
      "connectionReset: $connectionReset",
    );
    final startNotAllowed = isStartNotAllowed(connectionReset, reuseConnection);
    if (reuseConnection) {
      resetStatus();
    }

    if (startNotAllowed) {
      logger?.info(
        "Start is not allowed for connection $connectionNumber!"
        "status: $overallStatus detailsStatus: $connectionStatus paused: $paused",
      );
      return;
    }
    if (isDownloadCompleted) {
      logger?.info("Download is already completed! skipping...");
      _setDownloadComplete();
      notifyProgress();
      return;
    }
    logger?.info("Download is incomplete. starting a new download request...");
    await init(connectionReset, progressCallback, reuseConnection);
    notifyProgress();
    final request = buildDownloadRequest(reuseConnection);
    sendDownloadRequest(request);
  }

  void resetStatus() {
    downloadProgress = 0;
    totalRequestWriteProgress = 0;
    tempReceivedBytes = 0;
    totalRequestWrittenBytes = 0;
    totalRequestReceivedBytes = 0;
    connectionStatus = DownloadStatus.connecting;
    previousBufferEndByte = 0;
  }

  init(
    bool connectionReset,
    DownloadProgressCallback progressCallback,
    bool reuseConnection,
  ) async {
    connectionStatus =
        connectionReset ? DownloadStatus.resetting : DownloadStatus.connecting;
    overallStatus = connectionStatus;
    this.progressCallback = progressCallback;
    await initClient(connectionReset);
    paused = false;
    reset = false;
    terminatedOnCompletion = false;
    terminatedOnError = false;
    totalRequestReceivedBytes = 0;
  }

  http.Request buildDownloadRequest(bool reuseConnection) {
    final request = http.Request('GET', Uri.parse(downloadItem.downloadUrl));
    logger?.info("Setting request headers...");
    _setRequestHeaders(request, reuseConnection);
    return request;
  }

  void sendDownloadRequest(http.Request request, {Duration? timeout}) {
    try {
      final response = timeout != null
          ? client?.send(request).timeout(timeout)
          : client?.send(request);
      response?.asStream().cast<http.StreamedResponse>().listen((response) {
        if (!response.statusCode.toString().startsWith("2")) {
          logger?.error("Received bad status code ${response.statusCode}");
          throw Error();
        }
        downloadSub = response.stream.listen(
          _processChunk,
          onDone: onDownloadComplete,
          onError: onError,
        );
      }).onError(onError);
    } catch (e) {
      onError(e);
      notifyProgress();
    }
  }

  void _setDownloadComplete() {
    pauseButtonEnabled = true;
    downloadProgress = 1;
    totalConnectionWriteProgress = 1;
    connectionStatus = DownloadStatus.connectionComplete;
    final totalExistingLength = getTotalWrittenBytesLength();
    totalDownloadProgress = totalExistingLength / downloadItem.fileSize;
  }

  void updateDownloadProgress() {
    downloadProgress = totalRequestReceivedBytes / segment.length;
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.fileSize;
    if (downloadProgress > 1) {
      final excessBytes = totalConnectionReceivedBytes - segment.length;
      totalDownloadProgress =
          (totalConnectionReceivedBytes - excessBytes) / downloadItem.fileSize;
    }
  }

  Future<void> resetConnection() async {
    logger?.info("Resetting connection....");
    reset = true;
    await terminateConnection();
    totalConnectionReceivedBytes =
        totalConnectionReceivedBytes - tempReceivedBytes;
    totalRequestReceivedBytes = totalRequestReceivedBytes - tempReceivedBytes;
    clearBuffer();
    dynamicFlushThreshold = double.infinity;
    start(progressCallback!, connectionReset: true);
  }

  Future<void> cancel({bool failure = false}) async {
    await terminateConnection();
    cancelLogFlushTimer();
    clearBuffer();
    final status = failure ? DownloadStatus.failed : DownloadStatus.canceled;
    updateStatus(status);
    connectionStatus = status;
    notifyProgress();
  }

  void startLogFlushTimer() {
    logFlushTimer ??= Timer.periodic(
      Duration(seconds: 4),
      (timer) => sendLogBuffer(),
    );
  }

  void cancelLogFlushTimer() {
    logFlushTimer?.cancel();
    logFlushTimer = null;
  }

  /// TODO don't create a new obj every time
  void notifyProgress({bool completionSignal = false}) {
    final data = DownloadProgressMessage.loadFromHttpDownloadRequest(this);
    data.completionSignal = completionSignal;
    progressCallback!(data);
  }

  /// Sets the request byte range header to achieve resume functionality if the
  /// parts of the file has already been written.
  /// The length of the existing file is set to the start value and the TODO FIX DOC (SEGMENTED)
  /// content-length retrieved from the HEAD Request is set to the end value.
  /// returns whether the segment download has already been finished or not.
  /// TODO move variable sets outside of this method
  void _setRequestHeaders(http.Request request, bool reuseConnection) {
    tempDirectory.createSync(recursive: true);
    final reqStartByte = reuseConnection ? this.startByte : _getNewStartByte();
    logger?.info("newStartByte: $reqStartByte oldStartByte: ${this.startByte}");
    request.headers.addAll({
      "Range": "bytes=$reqStartByte-${this.endByte}",
      // "Keep-Alive": "timeout=5, max=1",
      // TODO handle request time-out response (We should reinitialize client)
    });
    if (!downloadItem.requestHeaders.containsKeyIgnoreCase("User-Agent")) {
      request.headers.addAll(userAgentHeader);
    }
    if (downloadItem.requestHeaders.isNotEmpty) {
      request.headers.addAll(downloadItem.requestHeaders);
    }
    logger?.info("Request headers: ${request.headers}");
    totalRequestWriteProgress = downloadProgress;
    logger?.info("=========== Total connection temp files ===========");
    getConnectionTempFilesSorted().forEach(
      (f) => logger?.info(basename(f.path)),
    );
    logger?.info("===================================================");
    final totalExistingLength = getTotalWrittenBytesLength();
    totalRequestReceivedBytes = getTotalWrittenBytesLength(
      thisByteRangeOnly: true,
    );
    downloadProgress = totalRequestReceivedBytes / segment.length;
    totalConnectionReceivedBytes = totalExistingLength;
    totalConnectionWriteProgress += previousBufferEndByte;
    totalRequestWrittenBytes = totalRequestReceivedBytes;
    totalConnectionWrittenBytes = totalExistingLength;
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.fileSize;
    logger?.info(
      "totalRequestReceivedBytes: $totalRequestReceivedBytes  "
      "totalConnectionReceivedBytes: $totalConnectionReceivedBytes "
      "totalConnectionWriteProgress: $totalConnectionWriteProgress "
      "totalRequestWrittenBytes: $totalRequestWrittenBytes "
      "totalConnectionWrittenBytes: $totalConnectionWrittenBytes "
      "totalDownloadProgress: $totalDownloadProgress",
    );
    if (reqStartByte == startByte) {
      previousBufferEndByte = 0;
    } else {
      previousBufferEndByte = reqStartByte - startByte;
      if (previousBufferEndByte < 0) {
        logger?.error("Previous buffer endByte is a negative number!");
      }
    }
    notifyProgress();
  }

  int _getNewStartByte() {
    final tempFiles = getConnectionTempFilesSorted(thisByteRangeOnly: true);
    if (tempFiles.isEmpty) {
      logger?.info(
        "startByte::$startByte endBytes::$endByte ==> temp files were empty",
      );
      return startByte;
    }
    final lastFileName = basename(tempFiles.last.path);
    final newStartByte = getEndByteFromTempFileName(lastFileName) + 1;
    logger?.info(
      "GetNewStartByte:: bytesRange: $startByte-$endByte is $newStartByte. TempFiles ==> ",
    );
    for (final file in tempFiles) {
      logger?.info(basename(file.path));
    }
    return getEndByteFromTempFileName(lastFileName) + 1;
  }

  void _processChunk(List<int> chunk) async {
    try {
      await doProcessChunk(chunk);
    } catch (e) {
      if (e is http.ClientException && paused) return;
      logger?.error("process chunk error! $e");
      await terminateConnection();
      clearBuffer();
    }
  }

  /// Processes each data [chunk] in [streamedResponse].
  /// Once the [tempReceivedBytes] hits the [dynamicFlushThreshold], the buffer is
  /// flushed to the disk. This process continues until the download has been
  /// finished. The buffer will be emptied after each flush
  Future<void> doProcessChunk(List<int> chunk) async {
    if (chunk.isEmpty) return;
    updateStatus(DownloadStatus.downloading);
    lastResponseTimeMillis = _nowMillis;
    pauseButtonEnabled = downloadItem.supportsPause;
    connectionStatus = transferRate;
    calculateTransferRate(chunk);
    calculateDynamicFlushThreshold();
    buffer.add(chunk);
    _updateReceivedBytes(chunk);
    updateDownloadProgress();
    if (receivedBytesExceededEndByte) {
      await _onByteExceeded();
      return;
    }
    if (receivedBytesMatchEndByte && endByte != downloadItem.fileSize) {
      // _onByteExactMatch();
      logger?.info(
        "Received bytes match endByte! But we're doing NOTHING about it!",
      );
      // return;
    }
    if (tempReceivedBytes > dynamicFlushThreshold) {
      flushBuffer();
    }
    notifyProgress();
  }

  void _onByteExactMatch() async {
    logger?.info(
      "Received bytes match endByte! "
      "closing the connection and flushing the buffer...",
    );
    if (endByte == downloadItem.fileSize) {
      logger?.info("Connection corresponds to the last segment!");
      totalRequestReceivedBytes += 3;
      totalConnectionReceivedBytes += 3;
      totalDownloadProgress =
          totalConnectionReceivedBytes / downloadItem.fileSize;
    }
    await terminateConnection();
    flushBuffer();
    _setDownloadComplete();
    terminatedOnCompletion = true;
    notifyProgress(completionSignal: true);
  }

  Future<void> _onByteExceeded() async {
    logger?.info("Received bytes exceeded endByte");
    await terminateConnection();
    flushBuffer();
    _fixTempFiles();
    _setDownloadComplete();
    terminatedOnCompletion = true;
    notifyProgress(completionSignal: true);
  }

  /// Flushes the buffer containing the received bytes to the disk.
  /// All flush operations write temp files with their corresponding connection number
  /// and byte ranges
  /// e.g. 0#100-2500 => connectionNumber#startByte-endByte
  void flushBuffer() {
    if (buffer.isEmpty) return;
    isWritingTempFile = true;
    final bytes = writeToUin8List(buffer);
    final filePath = join(
      tempDirectory.path,
      "$connectionNumber#$tempFileStartByte-$tempFileEndByte",
    );
    previousBufferEndByte += bytes.lengthInBytes;
    final file = File(filePath)
      ..writeAsBytesSync(mode: FileMode.writeOnly, bytes);

    if (tempFileStartByte > downloadItem.fileSize) {
      logger?.error(
        "Fatal:: conn$connectionNumber::$segment "
        "byteExceed?$receivedBytesExceededEndByte "
        "TotalReqRec:$totalRequestReceivedBytes "
        "prevbufs:$previousBufferEndByte",
      );
      _sendEnginePanic();
    }
    connectionCachedTempFiles.add(file);
    logger?.info(
      newLine: false,
      "FlushBuffer for segment $startByte-$endByte ::${basename(filePath)}",
    );
    _onTempFileWriteComplete(file);
    clearBuffer();
    sendLogBuffer();
  }

  void _sendEnginePanic() {
    logger?.info("Sending engine panic to the engine");
    progressCallback!(EnginePanicMessage(downloadItem));
  }

  void _onTempFileWriteComplete(File file) {
    totalRequestWrittenBytes += file.lengthSync();
    totalConnectionWriteProgress =
        totalConnectionWrittenBytes / downloadItem.fileSize;
    totalRequestWriteProgress = totalRequestReceivedBytes / segment.length;
    if (totalRequestWriteProgress == 1) {
      connectionStatus = DownloadStatus.connectionComplete;
    }
    isWritingTempFile = false;
  }

  // TODO add doc
  void _fixTempFiles() {
    logger?.info("Fixing temp files with segment $startByte-$endByte");
    final tempFiles = getConnectionTempFilesSorted(thisByteRangeOnly: true);
    logger?.info("================ Temp Files ===================");
    for (final file in tempFiles) {
      logger?.info(basename(file.path));
    }
    logger?.info("===============================================");
    List<File> tempFilesToDelete = [];
    Uint8List? newBufferToWrite;
    int? newBufferStartByte;
    for (var file in tempFiles) {
      final fileName = basename(file.path);
      final tempStartByte = getStartByteFromTempFileName(fileName);
      final tempEndByte = getEndByteFromTempFileName(fileName);
      if (endByte < tempStartByte) {
        logger?.info(
          "Temp file to delete: ${basename(file.path)} ${file.lengthSync()}",
        );
        tempFilesToDelete.add(file);
        continue;
      }

      if (endByte < tempEndByte) {
        logger?.info(
          "File to cut: ${basename(file.path)} :: ${file.lengthSync()}",
        );
        newBufferStartByte = tempStartByte;
        final bufferCutLength = endByte - tempStartByte + 1;
        newBufferToWrite = file.safeReadSync(bufferCutLength);
        tempFilesToDelete.add(file);
      }
    }

    for (final file in tempFilesToDelete) {
      totalConnectionReceivedBytes -= file.lengthSync();
      file.deleteSync();
      connectionCachedTempFiles.removeWhere((f) => f.path == file.path);
      logger?.info("Deleted file ${basename(file.path)}");
    }

    if (newBufferToWrite != null) {
      final newBufferEndByte =
          newBufferStartByte! + newBufferToWrite.lengthInBytes - 1;
      final newTempFilePath = join(
        tempDirectory.path,
        "$connectionNumber#$newBufferStartByte-$newBufferEndByte",
      );
      logger?.info("Writing file ${basename(newTempFilePath)}");
      final file = File(newTempFilePath)..writeAsBytesSync(newBufferToWrite);
      connectionCachedTempFiles.add(file);
      totalConnectionReceivedBytes += newBufferToWrite.lengthInBytes;
      totalRequestWrittenBytes = segment.length;
      logger?.info("Final file size ${file.lengthSync()}");
    }
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.fileSize;
    logger?.info("TempFiles fix complete");
  }

  /// TODO improve: we could send the newEndByte in this method instead of doing another IO in [_getNewStartByte]
  bool get isDownloadCompleted {
    final tempFiles = getConnectionTempFilesSorted(thisByteRangeOnly: true);
    if (tempFiles.isEmpty) {
      logger?.info(
        "IsDownloadComplete::$connectionNumber::S$startByte-E$endByte ==> EMPTY",
      );
      return false;
    }

    final str = StringBuffer(
      "IsDownloadComplete::$connectionNumber::S$startByte-E$endByte ==> ",
    );
    tempFiles.forEach((e) {
      str.writeln(basename(e.path));
    });
    logger?.info(str.toString());
    if (tempFiles.length == 1) {
      final file = basename(tempFiles[0].path);
      final fileEndByte = getEndByteFromTempFileName(file);
      if (endByte == downloadItem.fileSize &&
          fileEndByte == downloadItem.fileSize - 1) {
        return true;
      }
      if (endByte != fileEndByte) {
        return false;
      }
    }
    for (var i = 0; i < tempFiles.length; i++) {
      if (i == 0) continue;
      final file = tempFiles[i];
      final prevFile = tempFiles[i - 1];
      final fileStartByte = getStartByteFromTempFile(file);
      final fileEndByte = getEndByteFromTempFile(file);
      final prevFileEndByte = getEndByteFromTempFile(prevFile);
      final isLastFile = i == tempFiles.length - 1;
      if (isLastFile && fileEndByte == this.endByte - 1) {
        logger?.info("ATTENTION:: ConnNum$connectionNumber is weird");
      }
      if (fileStartByte != prevFileEndByte + 1) {
        logger?.info(
          "IsDownloadComplete::Found inconsistent ranges : ${basename(prevFile.path)} != ${basename(file.path)}",
        );
      }
      if (isLastFile) {
        if (endByte == downloadItem.fileSize &&
            fileEndByte == downloadItem.fileSize - 1) {
          return true;
        }
        if (fileEndByte != endByte) {
          return false;
        }
      }
    }
    return true;
  }

  void calculateTransferRate(List<int> chunk) {
    _transferRateChunkBuffer.add(chunk);
    final nowMillis = _nowMillis;
    if (_tmpTime + _transferRateCalculationWindowMillis > nowMillis) return;
    var timeBefore = _tmpTime;
    _tmpTime = nowMillis;
    int len = 0;
    for (var element in _transferRateChunkBuffer) {
      len += element.length;
    }
    transferRate = _getTransferRateStr(timeBefore, len);
    _transferRateChunkBuffer = [];
  }

  String _getTransferRateStr(int timeBefore, int len) {
    final elapsedSec = (_tmpTime - timeBefore) / 1000;
    if (elapsedSec <= 0) return "";
    final speedInMegaBytes = (len / 1048576) / elapsedSec;
    final speedInKiloBytes = (len / 1024) / elapsedSec;
    bytesTransferRate = len / elapsedSec;

    if (speedInMegaBytes > 1) {
      return '${speedInMegaBytes.toStringAsFixed(2)} MB/s';
    } else if (speedInKiloBytes > 1) {
      return '${speedInKiloBytes.toStringAsFixed(2)} KB/s';
    } else {
      return '${bytesTransferRate.toStringAsFixed(2)} B/s';
    }
  }

  void calculateDynamicFlushThreshold() {
    const double eightMegaBytes = 8388608;
    dynamicFlushThreshold = bytesTransferRate * 2 < eightMegaBytes
        ? bytesTransferRate * 2
        : eightMegaBytes;
    if (dynamicFlushThreshold <= 8192) {
      dynamicFlushThreshold = 64000;
    }
  }

  Future<void> pause(DownloadProgressCallback? progressCallback) async {
    if (isWritingTempFile) {
      logger?.warn("Tried to pause while writing temp files!");
    }
    paused = true;
    logger?.info("Paused connection $connectionNumber");
    cancelLogFlushTimer();
    if (progressCallback != null) {
      this.progressCallback = progressCallback;
    }
    flushBuffer();
    print("Setting pause for connection $connectionNumber");
    updateStatus(DownloadStatus.paused);
    connectionStatus = DownloadStatus.paused;
    await terminateConnection();
    pauseButtonEnabled = false;
    notifyProgress();
  }

  /// TODO handle cases where a segment is refreshed while the download has already finished!
  void refreshSegment(Segment segment, {bool reuseConnection = false}) {
    final prevEndByte = endByte;
    logger?.info(
      "Refresh requested for connection $connectionNumber with status $overallStatus $connectionStatus",
    );
    logger?.info(
      "Inside refresh segment conn num $connectionNumber :: $startByte - $endByte ",
    );
    logger?.info(
      "Inside refresh segment conn num $connectionNumber :: new ${segment.startByte} - ${segment.endByte} ",
    );
    final message = ConnectionSegmentMessage(
      downloadItem: downloadItem,
      requestedSegment: segment,
      reuseConnection: reuseConnection,
    );
    if (connectionStatus == DownloadStatus.connectionComplete) {
      message.internalMessage = messageRefreshSegmentRefused(reuseConnection);
      progressCallback!.call(message);
      logger?.info(
        "Connection :: $connectionNumber ::::: Refresh segment :::: requested : ($segment) :::: validStart "
        ": ${message.validNewStartByte} , validEnd : ${message.validNewEndByte} :: message: ${message.internalMessage}",
      );
      return;
    }
    if (startByte + totalRequestReceivedBytes >= segment.endByte) {
      message.internalMessage = InternalMessage.overlappingRefreshSegment;
      final newEndByte = _newValidRefreshSegmentEndByte;
      final validNewEndByte = prevEndByte;
      final validNewStartByte = startByte;
      if (newEndByte > 0 &&
          segment.startByte < newEndByte &&
          validNewStartByte + HttpDownloadEngine.minimumDownloadSegmentLength <
              validNewEndByte) {
        this.segment = Segment(segment.startByte, newEndByte);
        message
          ..validNewStartByte = endByte + 1
          ..validNewEndByte = prevEndByte
          ..refreshedStartByte = startByte
          ..refreshedEndByte = endByte;
      } else {
        message.internalMessage = messageRefreshSegmentRefused(reuseConnection);
      }
      progressCallback!.call(message);
      logger?.info(
        "Refresh segment:: requested : ($segment) :: validStart "
        ": ${message.validNewStartByte} , validEnd : ${message.validNewEndByte} "
        ":: message: ${message.internalMessage}",
      );
      logger?.info("Refresh Segment :: $startByte $endByte");
      return;
    }
    if (segment.startByte >= segment.endByte ||
        segment.startByte + 1 >= segment.endByte) {
      message.internalMessage = InternalMessage.refreshSegmentRefused;
      progressCallback!.call(message);
      return;
    }
    this.segment = segment;
    message
      ..internalMessage = InternalMessage.refreshSegmentSuccess
      ..refreshedStartByte = startByte
      ..refreshedEndByte = endByte;
    // TODO properly handle the status conditions
    progressCallback!.call(message);
    logger?.info(
      "Refresh segment :: requested : ($segment) :: validStart "
      ": ${message.validNewStartByte} , validEnd : ${message.validNewEndByte} "
      ":: message: ${message.internalMessage}",
    );
    logger?.info("Refresh Segment :: $startByte - $endByte");
    notifyProgress();
    return;
  }

  int get _newValidRefreshSegmentEndByte {
    final splitByte =
        ((endByte - (startByte + totalRequestReceivedBytes)) / 2).floor();
    return splitByte <= 0
        ? -1
        : splitByte + startByte + totalRequestReceivedBytes;
  }

  Future<void> terminateConnection() async {
    try {
      logger?.info("Terminating connection...");
      await client?.cancelRequest();
      await downloadSub?.cancel();
      logger?.info("Connection Terminated");
    } catch (_) {}
  }

  void clearBuffer() {
    buffer.clear();
    tempReceivedBytes = 0;
  }

  /// Flushes the remaining bytes in the buffer and completes the download.
  void onDownloadComplete() {
    logger?.info("onDownloadComplete paused $paused reset $reset");
    if (paused || reset || terminatedOnCompletion || terminatedOnError) return;
    bytesTransferRate = 0;
    downloadProgress = totalRequestReceivedBytes / segment.length;
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.fileSize;
    flushBuffer();
    connectionStatus = DownloadStatus.connectionComplete;
    logger?.info("Download complete with completion signal");
    logger?.info("connection progress : $downloadProgress");
    _setDownloadComplete();
    notifyProgress(completionSignal: true);
  }

  /// Force closing the client leads to a clientException to be thrown. When that happens,
  /// the stream is completed and the [onDownloadComplete] is called. However,
  /// since sometimes, for example, when a connection is reset or paused, we don't want the
  /// [onDownloadComplete] to be called as it sends a completionSignal to the engine
  /// despite the connection not really being completed (the designated segment is not downloaded yet).
  /// Therefore, we handle the mentioned exception here in a way that [onDownloadComplete] will be called
  /// only when a download is actually completed.
  void onError(dynamic error, [dynamic s]) async {
    logger?.error("onError::: error : $error \n $s");
    clearBuffer();
    terminatedOnError = true;
    await terminateConnection();
    notifyProgress();
    if (!(error is http.ClientException &&
        (paused || terminatedOnCompletion))) {
      logger?.error("connection $connectionNumber error : $error \n $s");
      reset = true; // set to prevent sending a completion signal to the engine
    }
  }

  Uint8List writeToUin8List(List<List<int>> chunks) {
    int start = 0;
    var len = 0;
    for (final c in chunks) {
      len += c.length;
    }
    final bytes = Uint8List(len);
    for (var chunk in chunks) {
      bytes.setRange(start, start + chunk.length, chunk);
      start += chunk.length;
    }
    return bytes;
  }

  void _updateReceivedBytes(List<int> chunk) {
    totalConnectionReceivedBytes += chunk.length;
    totalRequestReceivedBytes += chunk.length;
    tempReceivedBytes += chunk.length;
  }

  void updateStatus(String status) {
    overallStatus = status;
    downloadItem.status = overallStatus;
  }

  bool isStartNotAllowed(bool connectionReset, bool connectionReuse) {
    if (startByte >= endByte ||
        startByte > downloadItem.fileSize ||
        endByte > downloadItem.fileSize) {
      logger?.warn("Invalid requested byte ranges $segment. Skipping...");
      return true;
    }
    if (connectionReuse) {
      return false;
    }
    final isAllowed = (paused && isWritingTempFile) ||
        (!paused && downloadProgress > 0) ||
        downloadItem.status == DownloadStatus.connectionComplete ||
        overallStatus == DownloadStatus.connectionComplete ||
        connectionStatus == DownloadStatus.connectionComplete;

    return isAllowed && !connectionReset;
  }

  int getTotalWrittenBytesLength({bool thisByteRangeOnly = false}) {
    if (connectionCachedTempFiles.isEmpty) {
      return 0;
    }

    final connectionFiles = getConnectionTempFilesSorted();
    if (connectionFiles.isEmpty) {
      return 0;
    }

    var fileNames = connectionFiles.map((f) => basename(f.path));
    if (thisByteRangeOnly) {
      fileNames = fileNames
          .where(
            (fileName) => fileNameToSegment(fileName).isInRangeOfOther(segment),
          )
          .toList();
    }

    if (fileNames.isEmpty) {
      return 0;
    }

    if (fileNames.length == 1) {
      return getTempFileLength(fileNames.first);
    }

    return fileNames
        .reduce((f1, f2) => addTempFilesLengthReduce(f1, f2).toString())
        .toInt();
  }

  List<File> getConnectionTempFilesSorted({bool thisByteRangeOnly = false}) {
    if (connectionCachedTempFiles.isEmpty) {
      return [];
    }
    if (!thisByteRangeOnly) {
      return connectionCachedTempFiles;
    }
    return connectionCachedTempFiles
        .where((file) => isTempFileInByteRange(file, startByte, endByte))
        .toList()
      ..sort(sortByByteRanges);
  }

  void initTempFilesCache() {
    if (connectionCachedTempFiles.isNotEmpty || !tempDirectory.existsSync()) {
      return;
    }
    connectionCachedTempFiles.addAll(
      tempDirectory
          .listSync()
          .map((f) => f as File)
          .where((file) => tempFileBelongsToConnection(file, connectionNumber))
          .toList(),
    );
  }

  /// The abstract buildClient method used for implementations of download connections.
  /// namely, [HttpDownloadConnection] and [MockHttpDownloadConnection]
  Future<CustomBaseClient> buildClient() async {
    return HttpClientBuilder.buildClient(settings.clientSettings);
  }

  Future<void> initClient(bool connectionReset) async {
    final clientType =
        settings.clientSettings?.clientType ?? ClientType.dartHttp;
    if (!connectionReset && clientType == ClientType.rHttp && client != null) {
      return;
    }
    client = await buildClient();
  }

  int get _nowMillis => DateTime.now().millisecondsSinceEpoch;

  /// e.g. 0#0-50, 0#51-150, 1#151-400 and so on...
  String get tempFileName =>
      "$connectionNumber#$tempFileStartByte-$tempFileEndByte";

  /// The end byte of the buffer with respect to the target file (The file which will be built after download completes).
  int get tempFileEndByte =>
      startByte + previousBufferEndByte + tempReceivedBytes - 1;

  /// The start byte of the buffer with respect to the target file
  int get tempFileStartByte => startByte + previousBufferEndByte;

  Directory get tempDirectory =>
      Directory(join(settings.baseTempDir.path, downloadItem.uid.toString()));

  /// Sends the log buffer to the engine to be flushed to disk
  void sendLogBuffer() {
    if (logger == null) return;
    final logMessage = LogMessage(logger!.logBuffer.toString(), downloadItem);
    progressCallback!(logMessage);
    logger!.logBuffer.clear();
  }

  void initLogger() {
    if (logger != null) return;
    logger = Logger(
      downloadUid: downloadItem.uid,
      logBaseDir: settings.baseTempDir,
      connectionNumber: connectionNumber,
    );
  }

  /// Determines if the user is permitted to hit the start (Resume) button or not
  bool get isStartButtonEnabled => paused;

  /// The endByte is non-inclusive. We therefore add 1 to prevent premature buffer flush
  bool get receivedBytesMatchEndByte =>
      startByte + totalRequestReceivedBytes + 1 == endByte;

  bool get receivedBytesExceededEndByte =>
      startByte + totalRequestReceivedBytes + 1 > endByte;

  int get startByte => segment.startByte;

  int get endByte => segment.endByte;

  bool get connectionRetryAllowed =>
      lastResponseTimeMillis + settings.connectionRetryTimeoutMillis <
          _nowMillis &&
      !isWritingTempFile &&
      overallStatus != DownloadStatus.paused &&
      overallStatus != DownloadStatus.connectionComplete &&
      connectionStatus != DownloadStatus.canceled &&
      connectionStatus != DownloadStatus.connectionComplete &&
      (_retryCount < settings.maxConnectionRetryCount ||
          settings.maxConnectionRetryCount == -1);
}
