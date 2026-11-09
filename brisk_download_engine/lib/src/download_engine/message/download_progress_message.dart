import 'package:brisk_download_engine/src/download_engine/connection/http_download_connection.dart';
import 'package:brisk_download_engine/src/download_engine/connection/m3u8_download_connection.dart';
import 'package:brisk_download_engine/src/download_engine/model/download_item_model.dart';
import 'package:brisk_download_engine/src/download_engine/model/m3u8.dart';
import 'package:brisk_download_engine/src/download_engine/message/segment_progress.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';

class DownloadProgressMessage {
  List<DownloadProgressMessage> connectionProgresses = [];

  /// Snapshot of how the file's byte range is currently split between
  /// connections, ordered by start byte. Only populated on the overall
  /// download progress message of HTTP downloads.
  List<SegmentProgress> segmentProgresses = [];
  DownloadItemModel downloadItem;
  int totalSegments;
  double downloadProgress;
  int totalReceivedBytes;

  /// Bytes received by a connection for its current [segment], counted from
  /// the segment's start byte. Only set on connection progress messages.
  int segmentReceivedBytes;
  double totalDownloadProgress;
  String transferRate;
  double bytesTransferRate;
  String status;
  String estimatedRemaining;
  int estimatedSecondsRemaining;
  bool paused;
  double integrityValidationProgress;
  double totalConnectionWriteProgress;
  double totalRequestWriteProgress;
  double assembleProgress;
  ButtonAvailability buttonAvailability;
  int connectionNumber;
  int segmentLength;
  String connectionStatus;
  String message;
  Segment? segment;
  M3U8Segment? m3u8segment;
  bool completionSignal;
  int? assembledFileSize;

  DownloadProgressMessage({
    required this.downloadItem,
    this.segment,
    this.connectionNumber = 0,
    this.downloadProgress = 0,
    this.transferRate = "",
    this.status = "",
    this.estimatedRemaining = "",
    this.estimatedSecondsRemaining = 0,
    this.paused = false,
    this.totalConnectionWriteProgress = 0,
    this.integrityValidationProgress = 0,
    this.totalRequestWriteProgress = 0,
    this.assembleProgress = 0,
    this.buttonAvailability = const ButtonAvailability(false, false),
    this.bytesTransferRate = 0,
    this.totalReceivedBytes = 0,
    this.segmentReceivedBytes = 0,
    this.totalDownloadProgress = 0,
    this.segmentLength = 0,
    this.connectionStatus = "",
    this.totalSegments = 0,
    this.message = "",
    this.completionSignal = false,
    this.assembledFileSize,
  });

  factory DownloadProgressMessage.loadFromHttpDownloadRequest(
    HttpDownloadConnection connection,
  ) {
    final downloadProgress = DownloadProgressMessage(
      downloadProgress: connection.downloadProgress,
      transferRate: connection.transferRate,
      status: connection.overallStatus,
      paused: connection.paused,
      totalConnectionWriteProgress: connection.totalConnectionWriteProgress,
      totalRequestWriteProgress: connection.totalRequestWriteProgress,
      buttonAvailability: ButtonAvailability(
        connection.pauseButtonEnabled,
        connection.isStartButtonEnabled,
      ),
      downloadItem: connection.downloadItem,
      bytesTransferRate: connection.bytesTransferRate,
      totalDownloadProgress: connection.totalDownloadProgress,
      totalReceivedBytes: connection.totalConnectionReceivedBytes,
      segmentReceivedBytes: connection.totalRequestReceivedBytes,
      connectionStatus: connection.connectionStatus,
      connectionNumber: connection.connectionNumber,
      segment: connection.segment,
    );
    if (connection is M3U8DownloadConnection) {
      downloadProgress.m3u8segment = connection.m3u8segment;
    }
    return downloadProgress;
  }
}

class ButtonAvailability {
  final bool pauseButtonEnabled;
  final bool startButtonEnabled;

  const ButtonAvailability(this.pauseButtonEnabled, this.startButtonEnabled);
}
