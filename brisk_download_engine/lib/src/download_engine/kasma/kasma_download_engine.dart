import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brisk_download_engine/src/download_engine/download_status.dart';
import 'package:brisk_download_engine/src/download_engine/download_type.dart';
import 'package:brisk_download_engine/src/download_engine/kasma/kasma_bindings.dart';
import 'package:brisk_download_engine/src/download_engine/message/button_availability_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/download_progress_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/segment_progress.dart';
import 'package:brisk_download_engine/src/download_engine/model/download_item_model.dart';
import 'package:brisk_download_engine/src/download_engine/setting/download_settings.dart';
import 'package:brisk_download_engine/src/download_engine/util/readability_util.dart';
import 'package:path/path.dart' as p;

/// Adapter that runs HTTP and M3U8 downloads on the native kasma engine and translates its events into
/// the same messages the standard engine emits ([DownloadProgressMessage],
/// [ButtonAvailabilityMessage]), so the rest of the app does not need to know which engine is
/// running a download.
class KasmaDownloadEngine {
  static const _pollInterval = Duration(milliseconds: 100);

  static final Map<String, _KasmaSession> _sessions = {};

  static bool get isAvailable => KasmaBindings.instance != null;

  static String? get unavailableReason {
    KasmaBindings.instance;
    return KasmaBindings.loadError;
  }

  static bool isRunning(String uid) => _sessions.containsKey(uid);

  /// Starts (or resumes) a download on the kasma engine.
  /// Returns false if the native library is not available.
  static bool start(
    DownloadItemModel downloadItem,
    DownloadSettings settings, {
    required void Function(ButtonAvailabilityMessage) onButtonAvailability,
    required void Function(DownloadProgressMessage) onDownloadProgress,
    void Function()? onTerminated,
  }) {
    final bindings = KasmaBindings.instance;
    if (bindings == null) return false;
    _globalSpeedLimit =
        settings.speedLimitBytesPerSec < 0 ? 0 : settings.speedLimitBytesPerSec;
    final existing = _sessions[downloadItem.uid];
    if (existing != null) {
      existing.resume();
      return true;
    }
    final session = _KasmaSession(
      bindings: bindings,
      downloadItem: downloadItem,
      onButtonAvailability: onButtonAvailability,
      onDownloadProgress: onDownloadProgress,
      onTerminated: onTerminated,
    );
    final handle =
        bindings.start(jsonEncode(_buildConfig(downloadItem, settings)));
    if (handle == 0) {
      session.fail(bindings.lastError() ?? "Failed to start kasma engine");
      return true;
    }
    _sessions[downloadItem.uid] = session;
    session.begin(handle);
    return true;
  }

  static void pause(String uid) => _sessions[uid]?.pause();

  static void resume(String uid) => _sessions[uid]?.resume();

  /// Speed limits set for individual downloads, in bytes per second (0 = unlimited). They take
  /// precedence over the global limit and are kept when a download is stopped and started again.
  static final Map<String, int> _speedLimitOverrides = {};

  /// The global limit ([DownloadSettings.speedLimitBytesPerSec]) in bytes per second.
  static int _globalSpeedLimit = 0;

  static int get globalSpeedLimit => _globalSpeedLimit;

  /// The speed limit currently applied to the download, in bytes per second. 0 means unlimited.
  static int speedLimitOf(String uid) =>
      _speedLimitOverrides[uid] ?? _globalSpeedLimit;

  /// Whether the download has its own speed limit instead of following the global one.
  static bool hasOwnSpeedLimit(String uid) =>
      _speedLimitOverrides.containsKey(uid);

  /// Sets the speed limit of a single download, in bytes per second (0 = unlimited).
  /// Takes effect immediately if the download is running. `null` removes the download's own
  /// limit so it follows the global limit again.
  static void setSpeedLimit(String uid, int? bytesPerSec) {
    if (bytesPerSec == null) {
      _speedLimitOverrides.remove(uid);
    } else {
      _speedLimitOverrides[uid] = bytesPerSec < 0 ? 0 : bytesPerSec;
    }
    _sessions[uid]?.setSpeedLimit(speedLimitOf(uid));
  }

  /// Changes the global speed limit, in bytes per second (0 = unlimited). Running downloads
  /// without their own limit switch to it immediately.
  static void setGlobalSpeedLimit(int bytesPerSec) {
    _globalSpeedLimit = bytesPerSec < 0 ? 0 : bytesPerSec;
    for (final entry in _sessions.entries) {
      if (!_speedLimitOverrides.containsKey(entry.key)) {
        entry.value.setSpeedLimit(_globalSpeedLimit);
      }
    }
  }

  /// Stops the download (temp files are kept) and completes once the engine has exited.
  static Future<void> terminate(String uid) {
    final session = _sessions[uid];
    if (session == null) return Future.value();
    return session.terminate();
  }

  static Map<String, dynamic> _buildConfig(
    DownloadItemModel item,
    DownloadSettings settings,
  ) {
    final hasPath = item.filePath.isNotEmpty;
    final headers = <String, String>{...item.requestHeaders};
    final referer = item.refererHeader;
    if (referer != null &&
        referer.isNotEmpty &&
        !headers.keys.any((k) => k.toLowerCase() == 'referer')) {
      headers['Referer'] = referer;
    }
    final config = <String, dynamic>{
      'url': item.downloadUrl,
      'uid': item.uid,
      'file_name': hasPath ? p.basename(item.filePath) : item.fileName,
      'save_dir':
          hasPath ? p.dirname(item.filePath) : settings.baseSaveDir.path,
      'temp_dir': settings.baseTempDir.path,
      'retry_timeout_millis': settings.connectionRetryTimeoutMillis,
      'max_retries': settings.maxConnectionRetryCount,
      'logger': settings.loggerEnabled,
      'headers': headers,
      'speed_limit':
          _speedLimitOverrides[item.uid] ?? settings.speedLimitBytesPerSec,
    };
    if (item.downloadType == DownloadType.m3u8) {
      return config
        ..['type'] = 'm3u8'
        // The playlist was already fetched (and its variant selected) when the download was added
        ..['m3u8_content'] = item.m3u8Content
        ..['connections'] = settings.totalM3u8Connections;
    }
    return config
      ..['type'] = 'http'
      ..['file_size'] = item.fileSize
      ..['supports_range'] = item.supportsPause
      ..['connections'] = item.supportsPause ? settings.totalConnections : 1;
  }

  static void _remove(String uid) => _sessions.remove(uid);
}

class _KasmaSession {
  final KasmaBindings bindings;
  final DownloadItemModel downloadItem;
  final void Function(ButtonAvailabilityMessage) onButtonAvailability;
  final void Function(DownloadProgressMessage) onDownloadProgress;
  final void Function()? onTerminated;

  int _handle = 0;
  Timer? _timer;
  bool _paused = false;

  /// Set after a pause/resume command until the engine confirms it. Both buttons are disabled
  /// in the meantime to prevent sending conflicting commands.
  bool _awaitingCommandAck = false;
  bool _finished = false;
  bool _closed = false;
  ButtonAvailability? _lastButtons;
  List<DownloadProgressMessage> _lastConnections = [];
  List<SegmentProgress> _lastSegments = [];
  final Completer<void> _terminated = Completer();

  _KasmaSession({
    required this.bindings,
    required this.downloadItem,
    required this.onButtonAvailability,
    required this.onDownloadProgress,
    this.onTerminated,
  });

  void begin(int handle) {
    _handle = handle;
    _emitStatus(DownloadStatus.connecting);
    _timer = Timer.periodic(KasmaDownloadEngine._pollInterval, (_) => _poll());
  }

  void pause() {
    if (_finished || _paused || _awaitingCommandAck) return;
    _awaitingCommandAck = true;
    _emitButtons(const ButtonAvailability(false, false));
    if (bindings.command(_handle, KasmaBindings.commandPause) != 0) {
      _awaitingCommandAck = false;
    }
  }

  void resume() {
    if (_finished || !_paused || _awaitingCommandAck) return;
    _awaitingCommandAck = true;
    _emitButtons(const ButtonAvailability(false, false));
    if (bindings.command(_handle, KasmaBindings.commandResume) != 0) {
      _awaitingCommandAck = false;
    }
  }

  void setSpeedLimit(int bytesPerSec) {
    if (_closed || _handle == 0) return;
    bindings.setSpeedLimit(_handle, bytesPerSec);
  }

  Future<void> terminate() {
    if (!_finished) {
      bindings.command(_handle, KasmaBindings.commandTerminate);
    }
    return _terminated.future;
  }

  void _poll() {
    String? raw;
    try {
      raw = bindings.poll(_handle);
    } catch (e) {
      fail("kasma poll error: $e");
      return;
    }
    if (raw == null) return;
    final List<dynamic> events;
    try {
      events = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return;
    }
    for (final event in events.cast<Map<String, dynamic>>()) {
      _handleEvent(event);
      if (_timer == null) break;
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'info':
        final size = (event['file_size'] as num?)?.toInt() ?? 0;
        if (downloadItem.fileSize <= 0 && size > 0) {
          downloadItem.fileSize = size;
        }
        break;
      case 'progress':
        _onProgress(event);
        break;
      case 'paused':
        _paused = true;
        _awaitingCommandAck = false;
        _emitStatus(DownloadStatus.paused);
        break;
      case 'resumed':
        _paused = false;
        _awaitingCommandAck = false;
        _emitStatus(DownloadStatus.connecting);
        break;
      case 'assembling':
        _emitStatus(DownloadStatus.assembling, progress: 1);
        break;
      case 'complete':
        _onComplete(event['path'] as String?);
        break;
      case 'failed':
        _onFailure(DownloadStatus.failed, event['reason'] as String? ?? "");
        break;
      case 'network_error':
        _onFailure(
            DownloadStatus.networkError, event['reason'] as String? ?? "");
        break;
      case 'terminated':
        _paused = true;
        _emitStatus(DownloadStatus.paused);
        _close();
        break;
      case 'closed':
        if (!_finished) {
          _onFailure(
              DownloadStatus.failed, "kasma engine stopped unexpectedly");
        }
        _close();
        break;
      default:
        break;
    }
  }

  void _onProgress(Map<String, dynamic> event) {
    if (_finished) return;
    final progress = (event['progress'] as num?)?.toDouble() ?? 0;
    final speed = (event['speed'] as num?)?.toDouble() ?? 0;
    _lastConnections = _connectionProgresses(event['workers']);
    final segments = _segmentProgresses(event['segments']);
    if (segments.isNotEmpty) _lastSegments = segments;
    final message = _baseMessage(
      status: _paused ? DownloadStatus.paused : _mapStatus(event['status']),
      progress: progress,
    )
      ..bytesTransferRate = _paused ? 0 : speed
      ..transferRate = _paused || speed <= 0
          ? ""
          : convertByteTransferRateToReadableStr(speed)
      ..estimatedRemaining = _paused ? "" : (event['eta'] as String? ?? "")
      ..estimatedSecondsRemaining =
          _paused ? 0 : (event['eta_sec'] as num?)?.toInt() ?? 0
      ..totalReceivedBytes = (event['downloaded_bytes'] as num?)?.toInt() ?? 0;
    _send(message);
  }

  List<DownloadProgressMessage> _connectionProgresses(dynamic workers) {
    if (workers is! List) return [];
    return workers.cast<Map<String, dynamic>>().map((worker) {
      final start = (worker['start'] as num?)?.toInt() ?? 0;
      final end = (worker['end'] as num?)?.toInt() ?? 0;
      final received = (worker['received'] as num?)?.toInt() ?? 0;
      final speed = (worker['speed'] as num?)?.toDouble() ?? 0;
      final length = end - start + 1;
      final progress =
          length > 0 ? (received / length).clamp(0.0, 1.0).toDouble() : 0.0;
      final status = _paused
          ? DownloadStatus.paused
          : _mapWorkerStatus(worker['status'], progress);
      final transferRate = status == DownloadStatus.downloading && speed > 0
          ? convertByteTransferRateToReadableStr(speed)
          : "";
      return DownloadProgressMessage(
        downloadItem: downloadItem,
        connectionNumber: (worker['worker'] as num?)?.toInt() ?? 0,
        downloadProgress: progress,
        status: status,
        connectionStatus:
            status == DownloadStatus.downloading ? transferRate : status,
        transferRate: transferRate,
        bytesTransferRate: status == DownloadStatus.downloading ? speed : 0,
        segmentReceivedBytes: received,
        segmentLength: length,
        paused: _paused,
      );
    }).toList();
  }

  List<SegmentProgress> _segmentProgresses(dynamic segments) {
    if (segments is! List) return [];
    return segments
        .cast<Map<String, dynamic>>()
        .map(
          (segment) => SegmentProgress(
            startByte: (segment['start'] as num?)?.toInt() ?? 0,
            endByte: (segment['end'] as num?)?.toInt() ?? 0,
            connectionNumber: (segment['worker'] as num?)?.toInt() ?? 0,
            receivedBytes: (segment['received'] as num?)?.toInt() ?? 0,
            complete: segment['complete'] == true,
            active: !_paused && segment['active'] == true,
          ),
        )
        .toList();
  }

  static String _mapWorkerStatus(dynamic status, double progress) {
    if (status == 'complete' || progress >= 1) {
      return DownloadStatus.connectionComplete;
    }
    return _mapStatus(status);
  }

  void _onComplete(String? path) {
    _finished = true;
    if (path != null && path.isNotEmpty) {
      downloadItem
        ..filePath = path
        ..fileName = p.basename(path);
    }
    final file = File(downloadItem.filePath);
    downloadItem
      ..progress = 1
      ..status = DownloadStatus.assembleComplete
      ..finishDate = DateTime.now();
    final message = _baseMessage(
      status: DownloadStatus.assembleComplete,
      progress: 1,
    )
      ..assembleProgress = 1
      ..assembledFileSize =
          file.existsSync() ? file.lengthSync() : downloadItem.fileSize
      ..buttonAvailability = const ButtonAvailability(false, false);
    _lastButtons = const ButtonAvailability(false, false);
    onButtonAvailability(ButtonAvailabilityMessage(downloadItem: downloadItem));
    _send(message, emitButtons: false);
  }

  void _onFailure(String status, String reason) {
    if (_finished) return;
    _finished = true;
    final message =
        _baseMessage(status: status, progress: downloadItem.progress)
          ..message = reason
          ..buttonAvailability = const ButtonAvailability(false, true);
    _emitButtons(const ButtonAvailability(false, true));
    _send(message, emitButtons: false);
  }

  /// Reports a failure without a running engine (e.g. the engine failed to start).
  void fail(String reason) {
    _onFailure(DownloadStatus.failed, reason);
    _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    if (_handle != 0) {
      bindings.dispose(_handle);
      _handle = 0;
    }
    KasmaDownloadEngine._remove(downloadItem.uid);
    if (!_terminated.isCompleted) _terminated.complete();
    onTerminated?.call();
  }

  void _emitStatus(String status, {double? progress}) {
    _send(_baseMessage(
        status: status, progress: progress ?? downloadItem.progress));
  }

  DownloadProgressMessage _baseMessage({
    required String status,
    required double progress,
  }) {
    downloadItem
      ..status = status
      ..progress = progress;
    return DownloadProgressMessage(
      downloadItem: downloadItem,
      downloadProgress: progress,
      totalDownloadProgress: progress,
      status: status,
      paused: _paused,
      buttonAvailability: _buttonsFor(status),
    )
      // Status-only messages keep the last known per-connection details
      ..connectionProgresses = _lastConnections
      ..segmentProgresses = _lastSegments;
  }

  ButtonAvailability _buttonsFor(String status) {
    if (_finished) return const ButtonAvailability(false, false);
    if (_awaitingCommandAck) return const ButtonAvailability(false, false);
    if (_paused) return const ButtonAvailability(false, true);
    final canPause = downloadItem.supportsPause &&
        (status == DownloadStatus.downloading ||
            status == DownloadStatus.connecting ||
            status == DownloadStatus.resetting);
    return ButtonAvailability(canPause, false);
  }

  void _send(DownloadProgressMessage message, {bool emitButtons = true}) {
    if (emitButtons) _emitButtons(message.buttonAvailability);
    onDownloadProgress(message);
  }

  void _emitButtons(ButtonAvailability buttons) {
    final last = _lastButtons;
    if (last != null &&
        last.pauseButtonEnabled == buttons.pauseButtonEnabled &&
        last.startButtonEnabled == buttons.startButtonEnabled) {
      return;
    }
    _lastButtons = buttons;
    onButtonAvailability(
      ButtonAvailabilityMessage(
        downloadItem: downloadItem,
        pauseButtonEnabled: buttons.pauseButtonEnabled,
        startButtonEnabled: buttons.startButtonEnabled,
      ),
    );
  }

  static String _mapStatus(dynamic status) {
    switch (status) {
      case 'connecting':
      case 'initial':
        return DownloadStatus.connecting;
      case 'resetting':
        return DownloadStatus.resetting;
      case 'paused':
        return DownloadStatus.paused;
      default:
        return DownloadStatus.downloading;
    }
  }
}
