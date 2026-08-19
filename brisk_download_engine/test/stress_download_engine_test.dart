import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/download_type.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _argSaveDir = String.fromEnvironment('save-dir');
const _argTempDir = String.fromEnvironment('temp-dir');
const _argUrl = String.fromEnvironment('url');
const _argUrls = String.fromEnvironment('urls');
const _argUrlsFile = String.fromEnvironment('urls-file');
const _argConnections = String.fromEnvironment('connections');
const _argM3u8Connections = String.fromEnvironment('m3u8-connections');
const _argRetryTimeoutMillis = String.fromEnvironment('retry-timeout-ms');
const _argMaxRetries = String.fromEnvironment('max-retries');
const _argProgressLogMillis = String.fromEnvironment('progress-log-ms');
const _argMaxRuns = String.fromEnvironment('max-runs');

void main() {
  test(
    'stress downloads configured URLs in a cycle',
    () async {
      final config = StressConfig.fromCommandLine(Platform.environment);
      if (config == null) {
        markTestSkipped(
          'Pass --dart-define=save-dir=..., --dart-define=temp-dir=..., '
          'and either --dart-define=urls=... or --dart-define=urls-file=... '
          'to run this stress test.',
        );
        return;
      }

      await runStressDownloadCycle(config);
    },
    timeout: Timeout.none,
  );
}

Future<void> runStressDownloadCycle(StressConfig config) async {
  config.saveDir.createSync(recursive: true);
  config.tempDir.createSync(recursive: true);

  stdout.writeln('Stress download runner started');
  stdout.writeln('URLs: ${config.urls.length}');
  stdout.writeln('Save dir: ${config.saveDir.absolute.path}');
  stdout.writeln('Temp dir: ${config.tempDir.absolute.path}');
  stdout.writeln('Connections: ${config.connections}');
  stdout.writeln(
    'Max runs: ${config.maxRuns == 0 ? 'unlimited' : config.maxRuns}',
  );
  stdout.writeln('Engine logs: ${p.join(config.tempDir.path, 'Logs')}');
  stdout.writeln('');

  var urlIndex = 0;
  var runNumber = 0;
  while (config.maxRuns == 0 || runNumber < config.maxRuns) {
    final url = config.urls[urlIndex];
    runNumber++;
    stdout.writeln(
      '[run $runNumber] Starting URL ${urlIndex + 1}/${config.urls.length}: $url',
    );

    try {
      final result = await _downloadOnce(
        url: url,
        runNumber: runNumber,
        config: config,
      );
      if (result.enginePanicked) {
        throw StressEnginePanicException(result);
      }
      if (result.success) {
        _deleteDownloadArtifacts(result);
        stdout.writeln(
          '[run $runNumber] Success. Deleted downloaded file, temp folder, '
          'and log file.',
        );
      } else {
        stdout.writeln(
          '[run $runNumber] Failed with status "${result.status}". Keeping files for inspection.',
        );
      }
    } catch (error, stackTrace) {
      if (error is StressEnginePanicException) {
        stderr.writeln(error.message);
        rethrow;
      }
      stderr.writeln('[run $runNumber] Failed before completion: $error');
      stderr.writeln(stackTrace);
    }

    urlIndex = (urlIndex + 1) % config.urls.length;
  }

  stdout.writeln('Stress download runner finished after $runNumber runs.');
}

Future<DownloadRunResult> _downloadOnce({
  required String url,
  required int runNumber,
  required StressConfig config,
}) async {
  final item = await DownloadEngine.buildDownloadItem(url);
  final fileName = _stressFileName(runNumber, item.fileName);
  item
    ..fileName = fileName
    ..filePath = p.join(config.saveDir.path, fileName)
    ..startDate = DateTime.now();

  _deleteIfExists(item.filePath);

  final completer = Completer<DownloadRunResult>();
  var lastStatus = '';
  var lastProgressLogMillis = 0;

  final settings = DownloadSettings(
    baseSaveDir: config.saveDir,
    baseTempDir: config.tempDir,
    totalConnections: item.supportsPause ? config.connections : 1,
    totalM3u8Connections: config.m3u8Connections,
    loggerEnabled: true,
    connectionRetryTimeoutMillis: config.connectionRetryTimeoutMillis,
    maxConnectionRetryCount: config.maxConnectionRetryCount,
  );

  void complete(bool success, String status) {
    if (completer.isCompleted) return;
    final tempDirectoryPath = _downloadTempDirectoryPath(config, item.uid);
    final logFilePath = _downloadLogFilePath(config, item.uid);
    final enginePanicked = _enginePanicked(logFilePath);
    _disposeDownloadState(item.uid);
    completer.complete(
      DownloadRunResult(
        success: success,
        status: status,
        filePath: item.filePath,
        tempDirectoryPath: tempDirectoryPath,
        logFilePath: logFilePath,
        url: url,
        enginePanicked: enginePanicked,
      ),
    );
  }

  DownloadEngine.start(
    item,
    settings,
    DownloadType.http,
    onButtonAvailability: (_) {},
    onDownloadProgress: (message) {
      if (message.status != lastStatus) {
        lastStatus = message.status;
        stdout.writeln('[run $runNumber] Status: ${message.status}');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastProgressLogMillis >= config.progressLogIntervalMillis) {
        lastProgressLogMillis = now;
        final progress = (message.totalDownloadProgress * 100).clamp(0, 100);
        stdout.writeln(
          '[run $runNumber] ${progress.toStringAsFixed(2)}% '
                  '${message.transferRate} ${message.estimatedRemaining}'
              .trimRight(),
        );
      }

      switch (message.status) {
        case DownloadStatus.assembleComplete:
          complete(true, message.status);
          break;
        case DownloadStatus.assembleFailed:
        case DownloadStatus.failed:
        case DownloadStatus.canceled:
        case DownloadStatus.networkError:
          complete(false, message.status);
          break;
      }
    },
  );

  return completer.future;
}

void _disposeDownloadState(String uid) {
  try {
    DownloadEngine.engineChannels.remove(uid)?.sink.close();
  } catch (_) {}
  DownloadEngine.engineIsolates.remove(uid)?.kill(priority: Isolate.immediate);
  DownloadEngine.downloadItems.remove(uid);
  DownloadEngine.buttonAvailabilities.remove(uid);
  DownloadEngine.engineTerminationCompleter.remove(uid);
}

void _deleteDownloadArtifacts(DownloadRunResult result) {
  _deleteFileIfExists(result.filePath);
  _deleteDirectoryIfExists(result.tempDirectoryPath);
  _deleteFileIfExists(result.logFilePath);
}

void _deleteIfExists(String filePath) {
  _deleteFileIfExists(filePath);
}

void _deleteFileIfExists(String filePath) {
  final file = File(filePath);
  if (file.existsSync()) {
    file.deleteSync();
  }
}

void _deleteDirectoryIfExists(String directoryPath) {
  final directory = Directory(directoryPath);
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
}

bool _enginePanicked(String logFilePath) {
  final logFile = File(logFilePath);
  if (!logFile.existsSync()) {
    return false;
  }
  final log = logFile.readAsStringSync().toLowerCase();
  return log.contains('engine panicked') ||
      log.contains('sending engine panic') ||
      log.contains('download progress exceeded 1');
}

String _downloadTempDirectoryPath(StressConfig config, String uid) {
  return p.join(config.tempDir.path, uid);
}

String _downloadLogFilePath(StressConfig config, String uid) {
  return p.join(config.tempDir.path, 'Logs', '${uid}_logs.log');
}

String _stressFileName(int runNumber, String rawFileName) {
  final fileName = rawFileName.trim().isEmpty ? 'download.bin' : rawFileName;
  final sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*\n\r]'), '_');
  return 'stress_${runNumber}_$sanitized';
}

class DownloadRunResult {
  final bool success;
  final String status;
  final String filePath;
  final String tempDirectoryPath;
  final String logFilePath;
  final String url;
  final bool enginePanicked;

  DownloadRunResult({
    required this.success,
    required this.status,
    required this.filePath,
    required this.tempDirectoryPath,
    required this.logFilePath,
    required this.url,
    required this.enginePanicked,
  });
}

class StressEnginePanicException implements Exception {
  final DownloadRunResult result;

  StressEnginePanicException(this.result);

  String get message => 'Engine panic detected after completed download. '
      'Stopping stress test for investigation.\n'
      'URL: ${result.url}\n'
      'Downloaded file: ${result.filePath}\n'
      'Temp folder: ${result.tempDirectoryPath}\n'
      'Log file: ${result.logFilePath}';

  @override
  String toString() => message;
}

class StressConfig {
  final Directory saveDir;
  final Directory tempDir;
  final List<String> urls;
  final int connections;
  final int m3u8Connections;
  final int connectionRetryTimeoutMillis;
  final int maxConnectionRetryCount;
  final int progressLogIntervalMillis;
  final int maxRuns;

  StressConfig({
    required this.saveDir,
    required this.tempDir,
    required this.urls,
    required this.connections,
    required this.m3u8Connections,
    required this.connectionRetryTimeoutMillis,
    required this.maxConnectionRetryCount,
    required this.progressLogIntervalMillis,
    required this.maxRuns,
  });

  static StressConfig? fromCommandLine(Map<String, String> environment) {
    final saveDir = _firstNonEmpty(
      _argSaveDir,
      environment['BRISK_STRESS_SAVE_DIR'],
    );
    final tempDir = _firstNonEmpty(
      _argTempDir,
      environment['BRISK_STRESS_TEMP_DIR'],
    );
    final urls = _readUrls(environment);
    if (saveDir == null || tempDir == null || urls.isEmpty) {
      return null;
    }

    return StressConfig(
      saveDir: Directory(saveDir),
      tempDir: Directory(tempDir),
      urls: urls,
      connections: _parsePositiveInt(
        _firstNonEmpty(
            _argConnections, environment['BRISK_STRESS_CONNECTIONS']),
        defaultValue: 8,
      ),
      m3u8Connections: _parsePositiveInt(
        _firstNonEmpty(
          _argM3u8Connections,
          environment['BRISK_STRESS_M3U8_CONNECTIONS'],
        ),
        defaultValue: 8,
      ),
      connectionRetryTimeoutMillis: _parsePositiveInt(
        _firstNonEmpty(
          _argRetryTimeoutMillis,
          environment['BRISK_STRESS_RETRY_TIMEOUT_MS'],
        ),
        defaultValue: 10000,
      ),
      maxConnectionRetryCount: int.tryParse(
            _firstNonEmpty(
                    _argMaxRetries, environment['BRISK_STRESS_MAX_RETRIES']) ??
                '',
          ) ??
          -1,
      progressLogIntervalMillis: _parsePositiveInt(
        _firstNonEmpty(
          _argProgressLogMillis,
          environment['BRISK_STRESS_PROGRESS_LOG_MS'],
        ),
        defaultValue: 1000,
      ),
      maxRuns: _parseNonNegativeInt(
        _firstNonEmpty(_argMaxRuns, environment['BRISK_STRESS_MAX_RUNS']),
        defaultValue: 0,
      ),
    );
  }

  static List<String> _readUrls(Map<String, String> environment) {
    final urlsFile = _firstNonEmpty(
      _argUrlsFile,
      environment['BRISK_STRESS_URLS_FILE'],
    );
    final urls = <String>[];
    if (urlsFile != null) {
      urls.addAll(
        File(urlsFile)
            .readAsLinesSync()
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#')),
      );
    }

    final singleUrl = _firstNonEmpty(_argUrl);
    if (singleUrl != null) {
      urls.add(singleUrl);
    }

    final rawUrls = _firstNonEmpty(_argUrls, environment['BRISK_STRESS_URLS']);
    if (rawUrls != null) {
      urls.addAll(
        rawUrls
            .split(',')
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty),
      );
    }
    return urls;
  }
}

String? _firstNonEmpty(String? first, [String? second]) {
  if (first != null && first.trim().isNotEmpty) {
    return first;
  }
  if (second != null && second.trim().isNotEmpty) {
    return second;
  }
  return null;
}

int _parsePositiveInt(String? value, {required int defaultValue}) {
  final parsed = int.tryParse(value ?? '') ?? defaultValue;
  if (parsed <= 0) {
    throw ArgumentError('Expected a positive integer but got $value');
  }
  return parsed;
}

int _parseNonNegativeInt(String? value, {required int defaultValue}) {
  final parsed = int.tryParse(value ?? '') ?? defaultValue;
  if (parsed < 0) {
    throw ArgumentError('Expected a non-negative integer but got $value');
  }
  return parsed;
}
